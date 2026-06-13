# Quick uninstall helper
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$hookEvents = @('Stop','Notification','PermissionRequest','Elicitation','TeammateIdle','PreToolUse','SubagentStop')
foreach ($evt in $hookEvents) {
    if ($settings.hooks.$evt) {
        $settings.hooks.$evt = $settings.hooks.$evt | Where-Object { $_.hooks[0].command -notlike '*dingdong*play-sound.ps1*' }
        if ($settings.hooks.$evt.Count -eq 0) { $settings.hooks.$evt = $null }
    }
}
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Host "Old hooks removed from settings.json"

$target = "$env:USERPROFILE\.claude\hooks\dingdong"
if (Test-Path $target) {
    Remove-Item $target -Recurse -Force
    Write-Host "Deleted: $target"
}
Write-Host "Uninstall complete."