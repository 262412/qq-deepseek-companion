$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'key-directory.ps1')
$keyPath = Join-Path $keyDirectory 'deepseek-api-key.dpapi'
$openAiKeyPath = Join-Path $keyDirectory 'openai-api-key.dpapi'

if (-not $env:HTTPS_PROXY -and -not $env:https_proxy) {
    $internetSettings = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($internetSettings.ProxyEnable -eq 1 -and $internetSettings.ProxyServer) {
        $proxyEntries = @{}
        foreach ($entry in ([string]$internetSettings.ProxyServer -split ';')) {
            if ($entry -match '^\s*([^=]+)\s*=\s*(.+)\s*$') {
                $proxyEntries[$Matches[1].Trim().ToLowerInvariant()] = $Matches[2].Trim()
            } elseif ($entry.Trim()) {
                $proxyEntries['default'] = $entry.Trim()
            }
        }

        $systemProxy = $proxyEntries['https']
        if (-not $systemProxy) { $systemProxy = $proxyEntries['http'] }
        if (-not $systemProxy) { $systemProxy = $proxyEntries['default'] }
        if ($systemProxy -and $systemProxy -notmatch '^socks5?://') {
            if ($systemProxy -notmatch '^[a-z][a-z0-9+.-]*://') {
                $systemProxy = "http://$systemProxy"
            }
            $env:HTTPS_PROXY = $systemProxy
        }
    }
}

if (-not (Test-Path -LiteralPath $keyPath)) {
    throw 'API key is not saved yet. Run scripts/save-api-key.ps1 first.'
}

$encrypted = [System.IO.File]::ReadAllText($keyPath).Trim()
$secureKey = ConvertTo-SecureString -String $encrypted
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
$openAiSecureKey = $null
$openAiPointer = [IntPtr]::Zero

try {
    $env:DEEPSEEK_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if (Test-Path -LiteralPath $openAiKeyPath) {
        $encryptedOpenAiKey = [System.IO.File]::ReadAllText($openAiKeyPath).Trim()
        $openAiSecureKey = ConvertTo-SecureString -String $encryptedOpenAiKey
        $openAiPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($openAiSecureKey)
        $env:OPENAI_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($openAiPointer)
    }
    Push-Location $projectRoot
    try {
        & node --use-env-proxy .\src\server.mjs
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item Env:\DEEPSEEK_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:\OPENAI_API_KEY -ErrorAction SilentlyContinue
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secureKey.Dispose()
    if ($openAiPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($openAiPointer) }
    if ($openAiSecureKey) { $openAiSecureKey.Dispose() }
}

exit $exitCode
