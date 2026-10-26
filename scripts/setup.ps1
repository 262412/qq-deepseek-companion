$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'QQ DeepSeek Companion Setup'

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'key-directory.ps1')
$configPath = Join-Path $projectRoot 'config.local.json'
$keyPath = Join-Path $keyDirectory 'deepseek-api-key.dpapi'

if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'config.local.json is missing. Run npm run init first.'
}

Write-Host 'The API key is entered as a hidden secure prompt and is never displayed.'
$secureKey = Read-Host 'DeepSeek API Key' -AsSecureString
try {
    if ($secureKey.Length -lt 20) {
        throw 'The API key input is too short; nothing was saved.'
    }

    $allowedInput = Read-Host 'Allowed sender QQ IDs, comma-separated (blank denies everyone)'
    $allowedIds = @($allowedInput -split '[,;\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($allowedIds | Where-Object { $_ -notmatch '^\d+$' }) {
        throw 'QQ IDs must contain digits only; nothing was saved.'
    }

    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $config.allowedUserIds = @($allowedIds | Select-Object -Unique)
    $encryptedKey = ConvertFrom-SecureString -SecureString $secureKey

    New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
    [System.IO.File]::WriteAllText($keyPath, $encryptedKey, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($configPath, (($config | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))

    Write-Host 'API key encrypted with the current Windows user DPAPI and saved.'
    Write-Host "Saved $(@($config.allowedUserIds).Count) allowed QQ ID(s)."
    if (@($config.allowedUserIds).Count -eq 0) {
        Write-Host 'The whitelist is empty, so all private messages will be rejected.'
    }
} finally {
    $secureKey.Dispose()
}
