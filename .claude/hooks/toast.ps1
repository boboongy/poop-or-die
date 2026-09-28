# Windows desktop pop-up (toast) for the Stop and Notification hooks. Runs in Windows PowerShell 5.1 (WinRT types).
param([string]$Title = "Claude Code: mi-godot", [string]$Message = "Done")
try {
	[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
	[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
	$t = [System.Security.SecurityElement]::Escape($Title)
	$m = [System.Security.SecurityElement]::Escape($Message)
	$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
	$xml.LoadXml("<toast><visual><binding template=`"ToastGeneric`"><text>$t</text><text>$m</text></binding></visual><audio silent=`"true`"/></toast>")
	# The PowerShell app id is registered on every Windows install, so the toast shows without registering our own app.
	$app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
	[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
} catch {}
