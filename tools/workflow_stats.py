"""Measure whether the workflow (skill + hooks) is actually helping.

Reads this project's Claude Code transcripts and prints, per session, per era,
per feature, and per token source: owner turns, tokens (incl. cache reads),
active minutes, tool calls.

    python tools/workflow_stats.py             # per-era summary
    python tools/workflow_stats.py --sessions   # every session, oldest first
    python tools/workflow_stats.py --features   # per FEATURE, not per session
    python tools/workflow_stats.py --costs      # what fills the context window
    python tools/workflow_stats.py --costs --session 9b5f0349   # one session

"Active minutes" = wall clock minus any gap longer than 10 minutes (owner away).
"Tokens" = input + output + cache-creation + cache-read, summed per assistant
message, so it grows with context length: a long session costs far more per
message than a short one. That is the point of the short-session rule.

First measured 2026-10-06 over 53 transcripts: see the era table in HISTORY.md.
--features and --costs added 2026-10-06; both state their own limits when run.

The scan is cached (size + mtime per transcript) in the system temp dir, so the
first run takes minutes over ~290 MB and later runs are instant.
"""
import json
import os
import re
import sys
import glob
import tempfile
import datetime
import statistics

# Claude Code stores transcripts per project under ~/.claude/projects/<slug>.
SLUG = "c--Users-bobo-Documents-mi-godot"
TRANSCRIPTS = os.path.join(os.path.expanduser("~"), ".claude", "projects", SLUG)

LOCAL = datetime.timezone(datetime.timedelta(hours=8))  # the owner's clock (SGT)

# The two dates that split the project into eras, from file mtimes:
SKILL_WRITTEN = datetime.datetime(2026, 9, 20, 5, 37, tzinfo=LOCAL)   # SKILL.md
HOOKS_ADDED = datetime.datetime(2026, 9, 27, 15, 12, tzinfo=LOCAL)    # session_start.py
ERAS = ["1 before skill", "2 skill, not enforced", "3 skill + hooks"]

CACHE = os.path.join(tempfile.gettempdir(), "mi_godot_workflow_stats.json")
CACHE_VERSION = 4  # bump whenever scan() changes what it collects
# How long work still counts as being on the feature of the last file edited.
ATTRIBUTION_LAPSE = 15 * 60

EDIT_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")
# A character is about a quarter of a token for this project's text (code, prose,
# tool output). Only used where the transcript gives no token count of its own.
CHARS_PER_TOKEN = 4
# A screenshot costs about width*height/750 tokens whatever its base64 length is
# (a 2x2 contact sheet of this game's shots is roughly this); counting its
# characters instead overstates one image by about a hundred times.
IMAGE_TOKENS = 1500


def when(stamp):
    return datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone(LOCAL)


def owner_text(event):
    """The owner's own words, or None for tool results and hook injections."""
    message = event.get("message") or {}
    content = message.get("content")
    text = ""
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        for part in content:
            if not isinstance(part, dict):
                continue
            if part.get("type") == "tool_result":
                return None
            if part.get("type") == "text":
                text += part.get("text", "")
    text = text.strip()
    if not text:
        return None
    if text.startswith("<") and "command-name" not in text:
        return None  # a hook or system injection, not the owner typing
    return text


def target_of(name, inp):
    """A short label for WHAT a tool call was about, for the cost ranking."""
    if not isinstance(inp, dict):
        return name
    if name in ("Bash", "PowerShell"):
        command = (inp.get("command") or "").strip()
        # "cd <project> && timeout 60 bash tests/run.sh" is about run.sh, not cd.
        command = re.sub(r'^cd\s+("[^"]*"|\S+)\s*(&&|;)\s*', "", command)
        command = re.sub(r"^timeout\s+\d+\s*", "", command)
        words = [w for w in re.split(r"\s+", command) if not w.startswith("-")]
        head = " ".join(words[:2])[:40]
        return head or "bash"
    for key in ("file_path", "path", "notebook_path", "projectPath", "scene_path"):
        if inp.get(key):
            return os.path.basename(str(inp[key]))[:40]
    for key in ("pattern", "query", "url", "prompt", "skill"):
        if inp.get(key):
            return str(inp[key])[:40]
    return name


def family_of(path):
    """The feature a file belongs to: scripts/x.gd and tests/test_x.gd pair up."""
    stem = os.path.splitext(os.path.basename(str(path)))[0]
    stem = re.sub(r"^(test|probe|shot)_", "", stem)
    stem = re.sub(r"_(web|test)$", "", stem)
    if not stem:
        return None
    return stem


def size_of(value):
    """(characters, estimated tokens) of anything that lands in the context.

    Walks the structure so an image block is charged as IMAGE_TOKENS instead of
    a quarter of its base64 length.
    """
    chars = tokens = 0
    stack = [value]
    while stack:
        item = stack.pop()
        if isinstance(item, dict):
            source = item.get("source") if isinstance(item.get("source"), dict) else {}
            if item.get("type") == "image" or source.get("type") == "base64":
                chars += len(str(source.get("data") or ""))
                tokens += IMAGE_TOKENS
                continue
            stack.extend(item.values())
        elif isinstance(item, list):
            stack.extend(item)
        elif item is not None:
            text = item if isinstance(item, str) else str(item)
            chars += len(text)
            tokens += len(text) / CHARS_PER_TOKEN
    return chars, tokens


def chunks_of(event, kind):
    """(source, target, chars, tokens) for all this event adds to the context."""
    message = event.get("message") or {}
    content = message.get("content")
    parts = content if isinstance(content, list) else []
    if kind == "attachment":
        chars, tokens = size_of(event.get("attachment"))
        return [("attachments", str((event.get("attachment") or {}).get("type", "?")),
                 chars, tokens)]
    out = []
    if kind == "user":
        if isinstance(content, str):
            chars, tokens = size_of(content)
            out.append(("owner typing" if owner_text(event) else "hooks/system",
                        "prompt", chars, tokens))
        for part in parts:
            if not isinstance(part, dict):
                continue
            if part.get("type") == "tool_result":
                chars, tokens = size_of(part.get("content"))
                out.append(("tool_result", part.get("tool_use_id"), chars, tokens))
            elif part.get("type") == "text":
                text = part.get("text", "")
                src = "hooks/system" if text.strip().startswith("<") else "owner typing"
                chars, tokens = size_of(text)
                out.append((src, "prompt", chars, tokens))
    elif kind == "assistant":
        for part in parts:
            if not isinstance(part, dict):
                continue
            if part.get("type") == "text":
                chars, tokens = size_of(part.get("text", ""))
                out.append(("my words", "reply", chars, tokens))
            elif part.get("type") == "thinking":
                chars, tokens = size_of(part.get("thinking", ""))
                out.append(("my thinking", "thinking", chars, tokens))
            elif part.get("type") == "tool_use":
                chars, tokens = size_of(part.get("input"))
                out.append(("my tool calls",
                            target_of(part.get("name", "?"), part.get("input")),
                            chars, tokens))
    return out


def scan(path):
    """One pass over a transcript: session totals, cost sources, feature split.

    The cost part is measured, not guessed: what call N sent (input + cache
    read + cache creation) minus what call N-1 sent, minus call N-1's own
    output, is exactly how many tokens the things in between added to the
    context. Character estimates are used only to split one interval between
    the few chunks inside it.
    """
    stamps = []
    turns = assistant = tools = tokens = output = 0
    seen = set()
    seen_at = {}      # message id -> its call index
    names = {}        # tool_use_id -> "Tool target"
    pending = []      # [source, target, chars, estimate, call_index, is_mine]
    context = []      # per call: tokens sent
    outputs = []      # per call: tokens generated
    costs = {}        # "source|target" -> dict(n, chars, once, carry, biggest)
    families = {}     # feature -> dict(msgs, tokens, turns, tools, stamps, edits)
    current = None    # the feature the last edit was in
    touched = None    # when that edit happened: attribution lapses after a while
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("type")
        now = when(event["timestamp"]) if event.get("timestamp") else None
        if now:
            stamps.append(now)
        # Work drifts off a feature: without this, every message after the
        # session's last memory write was charged to "MEMORY" (198M tokens).
        if current and now and touched and (now - touched).total_seconds() > ATTRIBUTION_LAPSE:
            current = None
        message = event.get("message") or {}
        # Session totals count subagent messages too (that is what the era table
        # was first measured with); the cost ranking does not, because a subagent
        # has its own context window and its text is never re-sent in this one.
        ident = message.get("id")
        if kind == "assistant":
            # A message streamed in several events keeps ONE call index: its
            # parts are disjoint (thinking in one event, the tool call in the
            # next), so they all belong to the same call.
            index = seen_at.setdefault(ident, assistant) if ident else assistant
        else:
            index = assistant  # lands in the context of the next call
        if kind in ("user", "assistant", "attachment") and not event.get("isSidechain"):
            mine = kind == "assistant"
            for source, target, chars, cost in chunks_of(event, kind):
                pending.append([source, target, chars, cost, index, mine])
        if kind == "user" and not event.get("isMeta"):
            if owner_text(event):
                turns += 1
                if current:
                    families[current]["turns"] += 1
        elif kind == "assistant":
            calls = [p for p in (message.get("content") or [])
                     if isinstance(p, dict) and p.get("type") == "tool_use"]
            # Name every call before the dedupe: one message can be streamed in
            # several chunks, and the chunk carrying the tool_use may be a later
            # one (443 of 541 results were "unknown call" before this).
            for part in calls:
                names[part.get("id")] = (f"{part.get('name', '?')} "
                                         f"{target_of(part.get('name', '?'), part.get('input'))}")
            if ident and ident in seen:
                continue  # streamed in several chunks: count the message once
            if ident:
                seen.add(ident)
            assistant += 1
            tools += len(calls)
            for part in calls:
                if part.get("name") in EDIT_TOOLS:
                    inp = part.get("input") or {}
                    family = family_of(inp.get("file_path") or inp.get("notebook_path") or "")
                    if family:
                        current, touched = family, now
                        slot = families.setdefault(family, dict(
                            msgs=0, tokens=0, turns=0, tools=0, stamps=[], edits=[]))
                        slot["edits"].append(str(inp.get("file_path") or ""))
            usage = message.get("usage") or {}
            output += usage.get("output_tokens", 0) or 0
            cost = sum(usage.get(k, 0) or 0 for k in (
                "input_tokens", "output_tokens",
                "cache_creation_input_tokens", "cache_read_input_tokens"))
            tokens += cost
            context.append(sum(usage.get(k, 0) or 0 for k in (
                "input_tokens", "cache_creation_input_tokens",
                "cache_read_input_tokens")))
            outputs.append(usage.get("output_tokens", 0) or 0)
            if current:
                slot = families[current]
                slot["msgs"] += 1
                slot["tokens"] += cost
                slot["tools"] += len(calls)
                if event.get("timestamp"):
                    slot["stamps"].append(event["timestamp"])
    if not stamps:
        return None
    # Give each interval between two calls its MEASURED token growth, split
    # between the chunks inside it by their character estimate. What call 0
    # sent beyond its own chunks is the fixed, unseen part (system prompt,
    # tool schemas, CLAUDE.md, the loaded skills).
    groups = {}
    for chunk in pending:
        groups.setdefault((chunk[4], chunk[5]), []).append(chunk)
    drift = fixed = 0
    for index in range(len(context)):
        if index == 0:
            grew = context[0]
        else:
            grew = context[index] - context[index - 1] - outputs[index - 1]
        if grew < 0:
            drift += -grew
            grew = 0
        incoming = groups.get((index, False), [])
        estimate = sum(c[3] for c in incoming)
        if index == 0:
            # keep the estimate for the first prompt; the rest is the fixed part
            share = min(estimate, grew)
            fixed = grew - share
            grew = share
        for chunk in incoming:
            chunk.append(grew * (chunk[3] / estimate) if estimate else 0)
        mine = groups.get((index, True), [])
        estimate = sum(c[3] for c in mine)
        for chunk in mine:
            chunk.append(outputs[index] * (chunk[3] / estimate) if estimate else 0)
    for chunk in pending:
        source, target, chars, _, index, mine = chunk[:6]
        measured_cost = chunk[6] if len(chunk) > 6 else 0
        if source == "tool_result":
            target = names.get(target, "tool result (unknown call)")
        key = f"{source}|{target}"
        slot = costs.setdefault(key, dict(n=0, chars=0, once=0, carry=0, biggest=0))
        slot["n"] += 1
        slot["chars"] += chars
        slot["once"] += measured_cost
        # It is sent once when it appears and again on every later call.
        slot["carry"] += measured_cost * max(assistant - index, 1)
        slot["biggest"] = max(slot["biggest"], measured_cost)
    for family, slot in families.items():
        marks = sorted(when(s) for s in slot.pop("stamps"))
        slot["active"] = sum(gap for gap in
                             ((b - a).total_seconds() for a, b in zip(marks, marks[1:]))
                             if gap <= 600) / 60
        slot["start"] = marks[0].isoformat() if marks else None
        edits = slot.pop("edits")
        first_test = next((i for i, f in enumerate(edits) if "test" in f.lower()), None)
        first_code = next((i for i, f in enumerate(edits) if "test" not in f.lower()), None)
        slot["test_first"] = (first_test is not None and
                              (first_code is None or first_test < first_code))
        slot["files"] = len(set(edits))
    stamps.sort()
    active = sum(gap for gap in
                 ((b - a).total_seconds() for a, b in zip(stamps, stamps[1:]))
                 if gap <= 600) / 60
    return dict(sid=os.path.basename(path)[:8], start=stamps[0].isoformat(),
                active=active, turns=turns, assistant=assistant, tools=tools,
                tokens=tokens, output=output, costs=costs, families=families,
                fixed=fixed, drift=drift, calls=len(context))


def load(only=None):
    """Scan every transcript, reusing the cache for files that have not changed.

    `only` = a session-id prefix: then only that transcript is read, which is
    the fast way to try a change (the full scan is minutes on a cold cache).
    """
    if not os.path.isdir(TRANSCRIPTS):
        sys.exit(f"no transcripts at {TRANSCRIPTS}")
    cache = {}
    if os.path.exists(CACHE):
        try:
            blob = json.load(open(CACHE, encoding="utf-8"))
            if blob.get("version") == CACHE_VERSION:
                cache = blob.get("sessions", {})
        except (ValueError, OSError):
            cache = {}
    fresh, sessions = 0, []
    for path in sorted(glob.glob(os.path.join(TRANSCRIPTS, "*.jsonl"))):
        if only and not os.path.basename(path).startswith(only):
            continue
        info = os.stat(path)
        key = f"{os.path.basename(path)}|{info.st_size}|{int(info.st_mtime)}"
        if key not in cache:
            fresh += 1
            print(f"scanning {os.path.basename(path)[:8]} "
                  f"({info.st_size/1e6:.0f} MB) ...", file=sys.stderr)
            cache[key] = scan(path)
        if cache[key]:
            sessions.append(cache[key])
    if fresh:
        try:
            json.dump(dict(version=CACHE_VERSION, sessions=cache),
                      open(CACHE, "w", encoding="utf-8"))
        except OSError:
            pass
    for session in sessions:
        session["start"] = when(session["start"])
    # a real working session: it used tools and lasted a few minutes
    return sorted(sessions, key=lambda s: s["start"]), fresh


def era_of(start):
    if start < SKILL_WRITTEN:
        return ERAS[0]
    if start < HOOKS_ADDED:
        return ERAS[1]
    return ERAS[2]


def working_only(sessions):
    return [s for s in sessions if s["tools"] > 0 and s["active"] >= 3]


def print_eras(working):
    print(f"{'era':24} {'sess':>5} {'median act_m':>13} {'median turns':>13} "
          f"{'median tok_M':>13} {'tools/h':>8}")
    for era in ERAS:
        group = [s for s in working if era_of(s["start"]) == era]
        if not group:
            continue
        hours = sum(s["active"] for s in group) / 60
        print(f"{era:24} {len(group):5} "
              f"{statistics.median(s['active'] for s in group):13.0f} "
              f"{statistics.median(s['turns'] for s in group):13.0f} "
              f"{statistics.median(s['tokens'] for s in group)/1e6:13.1f} "
              f"{sum(s['tools'] for s in group)/max(hours, 1):8.1f}")
    print("\nA rule the hooks do not enforce is worth re-checking here before trusting it.")


def print_sessions(working):
    print(f"{'sid':9} {'start':12} {'act_m':>6} {'turns':>6} {'tools':>6} {'tok_M':>7}")
    for s in working:
        print(f"{s['sid']:9} {s['start'].strftime('%m-%d %H:%M'):12} {s['active']:6.0f} "
              f"{s['turns']:6} {s['tools']:6} {s['tokens']/1e6:7.2f}")
    print()


def print_features(sessions, limit=25):
    """Per feature instead of per session: a feature = one file family.

    Every file written or edited maps to a family (scripts/dance.gd and
    tests/test_dance.gd are both "dance"); each of my messages is credited to
    the family of the last file I touched. Messages before the first edit of a
    session are "unattributed" - mostly reading, planning and running tests.
    """
    totals = {}
    for session in sessions:
        for family, slot in session["families"].items():
            agg = totals.setdefault(family, dict(
                msgs=0, tokens=0, turns=0, tools=0, active=0.0, files=0,
                sessions=0, test_first=0, first=slot.get("start")))
            agg["msgs"] += slot["msgs"]
            agg["tokens"] += slot["tokens"]
            agg["turns"] += slot["turns"]
            agg["tools"] += slot["tools"]
            agg["active"] += slot["active"]
            agg["files"] = max(agg["files"], slot["files"])
            agg["sessions"] += 1
            agg["test_first"] += 1 if slot["test_first"] else 0
            if slot.get("start") and (not agg["first"] or slot["start"] < agg["first"]):
                agg["first"] = slot["start"]
    attributed = sum(a["msgs"] for a in totals.values())
    all_msgs = sum(s["assistant"] for s in sessions)
    attributed_min = sum(a["active"] for a in totals.values())
    all_min = sum(s["active"] for s in sessions)
    print(f"{len(totals)} features over {len(sessions)} transcripts; "
          f"{attributed} of {all_msgs} messages ({100*attributed/max(all_msgs,1):.0f} %) "
          f"and {attributed_min:.0f} of {all_min:.0f} active minutes attributed to a feature.")
    print("Unattributed = reading, planning, test runs before the first edit of a session.\n")
    order = sorted(totals.items(), key=lambda kv: -kv[1]["tokens"])[:limit]
    print(f"{'feature':22} {'first seen':11} {'sess':>4} {'act_m':>6} {'turns':>6} "
          f"{'tok_M':>7} {'tools':>6} {'tok/min':>8} {'test1st':>8}")
    for family, a in order:
        first = when(a["first"]).strftime("%m-%d %H:%M") if a["first"] else "-"
        per_min = a["tokens"] / max(a["active"], 1) / 1e3
        print(f"{family[:22]:22} {first:11} {a['sessions']:4} {a['active']:6.0f} "
              f"{a['turns']:6} {a['tokens']/1e6:7.1f} {a['tools']:6} "
              f"{per_min:7.0f}k {a['test_first']}/{a['sessions']:<6}")
    print("\ntest1st = sessions where a tests/ file was edited before the code file.")


def print_costs(sessions, limit=18):
    """What fills the context window, and for how long it keeps being re-sent.

    "chars" is the size of a thing once. "carry" is its size multiplied by the
    number of my later API calls in that session, because the whole
    conversation is re-sent every time: that is what the token bill measures.
    Both are estimates from characters (about 4 per token); the ratio printed
    against the transcripts' own token counts says how close the estimate is.
    """
    per_source, per_item = {}, {}
    for session in sessions:
        for key, slot in session["costs"].items():
            source, _, target = key.partition("|")
            for store, ident in ((per_source, source), (per_item, key)):
                agg = store.setdefault(ident, dict(n=0, once=0, carry=0, biggest=0))
                agg["n"] += slot["n"]
                agg["once"] += slot["once"]
                agg["carry"] += slot["carry"]
                agg["biggest"] = max(agg["biggest"], slot["biggest"])
    measured = sum(s["tokens"] for s in sessions) or 1
    calls = sum(s["calls"] for s in sessions) or 1
    # The system prompt, every tool schema (MCP servers included), CLAUDE.md
    # and the loaded skills are re-sent on every call but are not events in the
    # transcript. What the first call sent beyond its own prompt is that part.
    fixed = sum(s["fixed"] * s["calls"] for s in sessions)
    per_source["fixed: prompt+tools+skills"] = dict(n=calls, once=0, carry=fixed,
                                                    biggest=0)
    carry_total = sum(a["carry"] for a in per_source.values())
    drift = sum(s["drift"] for s in sessions)
    print(f"{len(sessions)} transcripts, {calls} API calls, "
          f"{measured/1e6:.0f}M tokens measured = {measured/calls/1e3:.0f}k per call; "
          f"accounted {100*carry_total/measured:.0f} % "
          f"(cache-boundary drift {drift/1e6:.1f}M).\n")
    print(f"{'source':31} {'calls':>7} {'own_Mtok':>9} {'carry_Mtok':>11} {'share':>6}")
    for source, a in sorted(per_source.items(), key=lambda kv: -kv[1]["carry"]):
        print(f"{source:31} {a['n']:7} {a['once']/1e6:9.1f} "
              f"{a['carry']/1e6:11.0f} {100*a['carry']/measured:5.0f} %")
    print(f"{'(the fixed part, per call)':31} {'':7} {'':9} "
          f"{fixed/calls/1e3:10.0f}k {'':6}")
    print(f"\nTop {limit} single things by carried cost "
          f"(tool name + what it was about):")
    print(f"{'what':54} {'calls':>6} {'own_Mtok':>9} {'carry_Mtok':>11} {'biggest_k':>10}")
    for key, a in sorted(per_item.items(), key=lambda kv: -kv[1]["carry"])[:limit]:
        source, _, target = key.partition("|")
        label = f"{source}: {target}"
        print(f"{label[:54]:54} {a['n']:6} {a['once']/1e6:9.1f} "
              f"{a['carry']/1e6:11.0f} {a['biggest']/1e3:10.1f}")
    repeats = sorted(((a["n"], key) for key, a in per_item.items()
                      if a["n"] >= 20 and key.startswith("tool_result")), reverse=True)[:10]
    print("\nSame call made again and again (20+ times):")
    for n, key in repeats:
        print(f"  {n:4}x  {key.partition('|')[2][:60]}")


def main():
    pick = None
    if "--session" in sys.argv:
        pick = sys.argv[sys.argv.index("--session") + 1]
    sessions, fresh = load(pick)
    if pick and not sessions:
        sys.exit(f"no transcript starting with {pick}")
    working = working_only(sessions)
    print(f"{len(working)} working sessions of {len(sessions)} transcripts"
          f"{' (rescanned ' + str(fresh) + ')' if fresh else ''}\n")
    if "--sessions" in sys.argv:
        print_sessions(working)
    if "--features" in sys.argv:
        print_features(sessions if pick else working)
        return
    if "--costs" in sys.argv:
        print_costs(sessions if pick else working)
        return
    print_eras(working)


if __name__ == "__main__":
    main()
