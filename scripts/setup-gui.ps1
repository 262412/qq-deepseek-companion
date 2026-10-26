$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'key-directory.ps1')
$configPath = Join-Path $projectRoot 'config.local.json'
$keyPath = Join-Path $keyDirectory 'deepseek-api-key.dpapi'
$openAiKeyPath = Join-Path $keyDirectory 'openai-api-key.dpapi'
$hasSavedKey = Test-Path -LiteralPath $keyPath
$hasSavedOpenAiKey = Test-Path -LiteralPath $openAiKeyPath

if (-not (Test-Path -LiteralPath $configPath)) {
    [System.Windows.Forms.MessageBox]::Show('config.local.json is missing. Run npm run init first.', 'Setup error') | Out-Null
    exit 1
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$form = New-Object System.Windows.Forms.Form
$form.Text = 'QQ DeepSeek Companion Setup'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(560, 395)

$intro = New-Object System.Windows.Forms.Label
$intro.Text = 'AI 小号身份由 NapCat 扫码登录的账号决定；此处填写允许联系 AI 的 QQ 号。'
$intro.AutoSize = $true
$intro.Location = New-Object System.Drawing.Point(18, 18)
$form.Controls.Add($intro)

$keyLabel = New-Object System.Windows.Forms.Label
$keyLabel.Text = if ($hasSavedKey) { 'DeepSeek API Key（留空保留已保存的 Key）' } else { 'DeepSeek API Key' }
$keyLabel.AutoSize = $true
$keyLabel.Location = New-Object System.Drawing.Point(18, 56)
$form.Controls.Add($keyLabel)

$keyBox = New-Object System.Windows.Forms.TextBox
$keyBox.Location = New-Object System.Drawing.Point(18, 78)
$keyBox.Size = New-Object System.Drawing.Size(520, 25)
$keyBox.UseSystemPasswordChar = $true
$keyBox.MaxLength = 512
$form.Controls.Add($keyBox)

$openAiKeyLabel = New-Object System.Windows.Forms.Label
$openAiKeyLabel.Text = if ($hasSavedOpenAiKey) { 'OpenAI API Key（语音/角色照片；留空保留已保存的 Key）' } else { 'OpenAI API Key（语音/角色照片；可留空稍后配置）' }
$openAiKeyLabel.AutoSize = $true
$openAiKeyLabel.Location = New-Object System.Drawing.Point(18, 118)
$form.Controls.Add($openAiKeyLabel)

$openAiKeyBox = New-Object System.Windows.Forms.TextBox
$openAiKeyBox.Location = New-Object System.Drawing.Point(18, 140)
$openAiKeyBox.Size = New-Object System.Drawing.Size(520, 25)
$openAiKeyBox.UseSystemPasswordChar = $true
$openAiKeyBox.MaxLength = 512
$form.Controls.Add($openAiKeyBox)

$allowLabel = New-Object System.Windows.Forms.Label
$allowLabel.Text = '允许私聊的 QQ 号白名单（多个用逗号分隔）'
$allowLabel.AutoSize = $true
$allowLabel.Location = New-Object System.Drawing.Point(18, 184)
$form.Controls.Add($allowLabel)

$allowBox = New-Object System.Windows.Forms.TextBox
$allowBox.Location = New-Object System.Drawing.Point(18, 206)
$allowBox.Size = New-Object System.Drawing.Size(520, 25)
$allowBox.Text = (@($config.allowedUserIds) -join ', ')
$form.Controls.Add($allowBox)

$groupLabel = New-Object System.Windows.Forms.Label
$groupLabel.Text = '允许群聊的 QQ 群号（多个用逗号分隔；群内新消息都会触发，无需 @）'
$groupLabel.AutoSize = $true
$groupLabel.Location = New-Object System.Drawing.Point(18, 240)
$form.Controls.Add($groupLabel)

$groupBox = New-Object System.Windows.Forms.TextBox
$groupBox.Location = New-Object System.Drawing.Point(18, 262)
$groupBox.Size = New-Object System.Drawing.Size(520, 25)
$groupBox.Text = (@($config.allowedGroupIds) -join ', ')
$form.Controls.Add($groupBox)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = '群号白名单留空时不处理群聊。Key 只在本机通过 DPAPI 加密保存。'
$hint.AutoSize = $true
$hint.Location = New-Object System.Drawing.Point(18, 298)
$form.Controls.Add($hint)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = '保存本机配置'
$saveButton.Location = New-Object System.Drawing.Point(348, 345)
$saveButton.Size = New-Object System.Drawing.Size(115, 32)
$saveButton.Add_Click({
    $plainKey = $keyBox.Text
    $plainOpenAiKey = $openAiKeyBox.Text
    if (($plainKey.Length -gt 0 -and $plainKey.Length -lt 20) -or ($plainKey.Length -eq 0 -and -not $hasSavedKey)) {
        [System.Windows.Forms.MessageBox]::Show('请输入有效的 DeepSeek API Key。', '需要 API Key') | Out-Null
        $keyBox.Focus()
        return
    }
    if ($plainOpenAiKey.Length -gt 0 -and $plainOpenAiKey.Length -lt 20) {
        [System.Windows.Forms.MessageBox]::Show('OpenAI API Key 长度不足；请检查后重试。', 'Key 格式错误') | Out-Null
        $openAiKeyBox.Focus()
        return
    }

    $ids = @($allowBox.Text -split '[,;\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($ids | Where-Object { $_ -notmatch '^\d+$' }) {
        [System.Windows.Forms.MessageBox]::Show('QQ 号只能包含数字；请检查白名单输入。', '白名单格式错误') | Out-Null
        $allowBox.Focus()
        return
    }

    $groupIds = @($groupBox.Text -split '[,;\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($groupIds | Where-Object { $_ -notmatch '^\d+$' }) {
        [System.Windows.Forms.MessageBox]::Show('QQ群号只能包含数字；请检查群聊白名单输入。', '群聊白名单格式错误') | Out-Null
        $groupBox.Focus()
        return
    }

    $secureKey = $null
    $secureOpenAiKey = $null
    try {
        if ($plainKey.Length -gt 0) {
            $secureKey = New-Object System.Security.SecureString
            foreach ($character in $plainKey.ToCharArray()) { $secureKey.AppendChar($character) }
            $secureKey.MakeReadOnly()
            $encryptedKey = ConvertFrom-SecureString -SecureString $secureKey
        }
        if ($plainOpenAiKey.Length -gt 0) {
            $secureOpenAiKey = New-Object System.Security.SecureString
            foreach ($character in $plainOpenAiKey.ToCharArray()) { $secureOpenAiKey.AppendChar($character) }
            $secureOpenAiKey.MakeReadOnly()
            $encryptedOpenAiKey = ConvertFrom-SecureString -SecureString $secureOpenAiKey
        }
        $config.allowedUserIds = @($ids | Select-Object -Unique)
        if ($config.PSObject.Properties.Name -notcontains 'allowedGroupIds') {
            $config | Add-Member -MemberType NoteProperty -Name 'allowedGroupIds' -Value @()
        }
        $config.allowedGroupIds = @($groupIds | Select-Object -Unique)
        $json = ($config | ConvertTo-Json -Depth 20) + "`n"

        New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
        if ($plainKey.Length -gt 0) {
            [System.IO.File]::WriteAllText($keyPath, $encryptedKey, [System.Text.UTF8Encoding]::new($false))
        }
        if ($plainOpenAiKey.Length -gt 0) {
            [System.IO.File]::WriteAllText($openAiKeyPath, $encryptedOpenAiKey, [System.Text.UTF8Encoding]::new($false))
        }
        [System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
        $keyBox.Clear()
        $openAiKeyBox.Clear()
        if ($secureKey) { $secureKey.Dispose() }
        if ($secureOpenAiKey) { $secureOpenAiKey.Dispose() }

        [System.Windows.Forms.MessageBox]::Show("配置已保存在本机。私聊 QQ 白名单：$(@($config.allowedUserIds).Count) 个；群聊白名单：$(@($config.allowedGroupIds).Count) 个。", '保存完成') | Out-Null
        $form.Close()
    } catch {
        if ($secureKey) { $secureKey.Dispose() }
        if ($secureOpenAiKey) { $secureOpenAiKey.Dispose() }
        $errorMessage = $_.Exception.Message
        if ($plainKey.Length -gt 0) {
            $errorMessage = $errorMessage.Replace($plainKey, '[已隐藏]')
        }
        if ($plainOpenAiKey.Length -gt 0) {
            $errorMessage = $errorMessage.Replace($plainOpenAiKey, '[已隐藏]')
        }
        [System.Windows.Forms.MessageBox]::Show("保存失败；Key 不会写入日志。`n错误：$errorMessage", '保存失败') | Out-Null
    }
})
$form.Controls.Add($saveButton)
$form.AcceptButton = $saveButton

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = '取消'
$cancelButton.Location = New-Object System.Drawing.Point(475, 345)
$cancelButton.Size = New-Object System.Drawing.Size(63, 32)
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelButton)
$form.CancelButton = $cancelButton

[void]$form.ShowDialog()
