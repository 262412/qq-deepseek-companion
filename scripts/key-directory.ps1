$projectParent = Split-Path -Parent $projectRoot
$legacyNapcatDirectory = Join-Path $projectParent 'napcat'

if ((Split-Path -Leaf $projectParent) -ieq 'outputs' -and
    (Test-Path -LiteralPath $legacyNapcatDirectory -PathType Container)) {
    $keyDirectory = Join-Path (Split-Path -Parent $projectParent) 'work'
} else {
    $localAppData = $env:LOCALAPPDATA
    if (-not $localAppData) {
        $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    }
    if (-not $localAppData) {
        throw 'Could not resolve the current user LocalAppData directory.'
    }
    $keyDirectory = Join-Path $localAppData 'QQDeepSeekCompanion\work'
}
