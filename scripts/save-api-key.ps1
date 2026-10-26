$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'key-directory.ps1')
$keyPath = Join-Path $keyDirectory 'deepseek-api-key.dpapi'

New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
$secureKey = Read-Host 'Enter DeepSeek API Key (input is hidden)' -AsSecureString
if ($secureKey.Length -lt 20) {
    $secureKey.Dispose()
    throw 'The input is too short to be a valid API key; nothing was saved.'
}

try {
    $encrypted = ConvertFrom-SecureString -SecureString $secureKey
    [System.IO.File]::WriteAllText($keyPath, $encrypted, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Key encrypted with the current Windows user DPAPI and saved.'
} finally {
    $secureKey.Dispose()
}
