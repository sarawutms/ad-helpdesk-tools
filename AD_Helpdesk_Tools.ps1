param(
    [string]$RunMode = "Normal",
    [string]$CredFilePath = ""
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# ตรวจสอบว่าเครื่องนี้ Join Domain หรือไม่
# ============================================================
$sysInfo = Get-CimInstance Win32_ComputerSystem
if (-not $sysInfo.PartOfDomain) {
    [System.Windows.Forms.MessageBox]::Show(
        "เครื่องคอมพิวเตอร์นี้ไม่ได้อยู่ในระบบ Domain`n`nโปรแกรมนี้จำเป็นต้องใช้งานบนเครื่องที่ Join Domain แล้วเท่านั้น", 
        "Domain Connection Required", 
        0, 
        16
    ) | Out-Null
    exit
}

# ============================================================
# [NEW] ระบบคัดลอกไฟล์เพื่อให้รันอย่างเสถียร (ป้องกัน Binary Planting โดยใช้ LocalAppData)
# ============================================================
if ($RunMode -eq "Normal") {
    $stableDir = "$env:LOCALAPPDATA\ADHelpdeskTool\Bin"
    $stableExe = Join-Path $stableDir "ADHelpdeskTool.exe"
    $myPath    = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

    if ($myPath.ToLower().EndsWith(".exe") -and ($myPath -ne $stableExe)) {
        try {
            if (-not (Test-Path $stableDir)) { New-Item -Path $stableDir -ItemType Directory -Force | Out-Null }
            Copy-Item -Path $myPath -Destination $stableExe -Force -ErrorAction Stop
            Start-Process -FilePath $stableExe
            exit
        } catch {
            # ถ้า copy ไม่ได้ ให้ทำงานต่อจาก path เดิมแทน
        }
    }
}

# ============================================================
#  ฟังก์ชันสร้างหน้าต่าง Login
# ============================================================
function Show-CustomLogin {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Authentication Required"
    $dlg.Size = New-Object System.Drawing.Size(380, 270)
    $dlg.StartPosition = "CenterScreen"
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
    $dlg.TopMost = $true

    $FontGlobal = New-Object System.Drawing.Font("Leelawadee UI", 10.5)
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Please login with Domain Admin credentials."
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $lblTitle.Font = New-Object System.Drawing.Font("Leelawadee UI", 10.5, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(37, 99, 235)

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Username:"
    $lblUser.Location = New-Object System.Drawing.Point(20, 60)
    $lblUser.AutoSize = $true
    $lblUser.Font = $FontGlobal

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Location = New-Object System.Drawing.Point(100, 58)
    $txtUser.Size = New-Object System.Drawing.Size(240, 26)
    $txtUser.Font = $FontGlobal

    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = "Password:"
    $lblPass.Location = New-Object System.Drawing.Point(20, 100)
    $lblPass.AutoSize = $true
    $lblPass.Font = $FontGlobal

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location = New-Object System.Drawing.Point(100, 98)
    $txtPass.Size = New-Object System.Drawing.Size(240, 26)
    $txtPass.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
    $txtPass.UseSystemPasswordChar = $true

    $chkRemember = New-Object System.Windows.Forms.CheckBox
    $chkRemember.Text = "Remember me for 1 day"
    $chkRemember.Location = New-Object System.Drawing.Point(100, 130)
    $chkRemember.AutoSize = $true
    $chkRemember.Font = New-Object System.Drawing.Font("Leelawadee UI", 9.5)
    $chkRemember.ForeColor = [System.Drawing.Color]::FromArgb(107, 114, 128)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "Login"
    $btnOk.Location = New-Object System.Drawing.Point(100, 165)
    $btnOk.Size = New-Object System.Drawing.Size(115, 34)
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.FlatStyle = "Flat"
    $btnOk.FlatAppearance.BorderSize = 0
    $btnOk.Font = New-Object System.Drawing.Font("Leelawadee UI", 10, [System.Drawing.FontStyle]::Bold)
    
    $btnOk.Add_Click({
        if ([string]::IsNullOrWhiteSpace($txtUser.Text) -or [string]::IsNullOrWhiteSpace($txtPass.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter both Username and Password to proceed.", "Incomplete Information", 0, 48) | Out-Null
            return 
        }
        $dlg.DialogResult = "OK" 
        $dlg.Close()
    })

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(225, 165)
    $btnCancel.Size = New-Object System.Drawing.Size(115, 34)
    $btnCancel.DialogResult = "Cancel"
    $btnCancel.BackColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.Font = $FontGlobal

    $dlg.Controls.AddRange(@($lblTitle, $lblUser, $txtUser, $lblPass, $txtPass, $chkRemember, $btnOk, $btnCancel))
    $dlg.AcceptButton = $btnOk
    $dlg.CancelButton = $btnCancel

    $dlg.ShowDialog() | Out-Null
    
    if ($dlg.DialogResult -eq "OK") {
        $inputUser = $txtUser.Text.Trim()
        
        # [SECURITY FIX] นำ Hardcoded Domain ออก และใช้ Domain ของเครื่องแทน
        if ($inputUser -notmatch "\\" -and $inputUser -notmatch "@") {
            $currentDomain = $env:USERDOMAIN
            $inputUser = "$currentDomain\$inputUser"
        }
        
        $secStr = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($inputUser, $secStr)
        return @{ Credential = $credential; Remember = $chkRemember.Checked }
    }
    return $null
}

# ============================================================
#  กระบวนการขอสิทธิ์ Admin
# ============================================================
if ($RunMode -ne "AdminSession") {

    $mutex = New-Object System.Threading.Mutex($false, "Local\ADHelpdeskTool_SingleInstance")
    try {
        $mutexAcquired = $mutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $mutexAcquired = $true
    }
    if (-not $mutexAcquired) {
        [System.Windows.Forms.MessageBox]::Show("โปรแกรม AD Helpdesk Tool เปิดอยู่แล้ว`n`nกรุณาใช้งานที่หน้าต่างเดิมก่อน", "AD Helpdesk Tool", 0, 48) | Out-Null
        exit
    }

    # [SECURITY FIX] ย้ายการเก็บไฟล์รหัสผ่านไปที่ LocalAppData เพื่อป้องกันข้อมูลรั่วไหล
    $credDir = "$env:LOCALAPPDATA\ADHelpdeskTool\Cache"
    if (-not (Test-Path $credDir)) { New-Item -Path $credDir -ItemType Directory -Force | Out-Null }
    $credFile = "$credDir\AdminCred.xml"

    $scriptPath = if ($PSCommandPath) {
        $PSCommandPath
    } else {
        [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }

    $loadedFromCache = $false
    if (Test-Path $credFile) {
        $fileInfo = Get-Item $credFile
        if ($fileInfo.LastWriteTime.Date -eq (Get-Date).Date) {
            $loadedFromCache = $true
        } else {
            Remove-Item $credFile -Force -ErrorAction SilentlyContinue
        }
    }

    while ($true) {
        $cred = $null
        $shouldRemember = $false

        if ($loadedFromCache) {
            try {
                $cred = Import-Clixml -Path $credFile -ErrorAction Stop
            } catch {
                $loadedFromCache = $false
            }
        }

        if (-not $cred) {
            $loginData = Show-CustomLogin
            if (-not $loginData) { exit } 
            $cred = $loginData.Credential
            $shouldRemember = $loginData.Remember
        }

        try {
            # [UPDATED] เพิ่ม WorkingDirectory ตามที่ระบุ
            $workingDir = Split-Path $scriptPath -Parent
            if ($scriptPath.ToLower().EndsWith(".exe")) {
                Start-Process -FilePath $scriptPath -ArgumentList "-RunMode AdminSession -CredFilePath `"$credFile`"" -Credential $cred -WorkingDirectory $workingDir -WindowStyle Hidden -ErrorAction Stop
            } else {
                $argList = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -RunMode AdminSession -CredFilePath `"$credFile`""
                Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Credential $cred -WorkingDirectory $workingDir -ErrorAction Stop
            }
            
            if ($shouldRemember -and -not (Test-Path $credFile)) {
                $cred | Export-Clixml -Path $credFile -Force
            }
            exit 
            
        } catch {
            if (Test-Path $credFile) { Remove-Item $credFile -Force -ErrorAction SilentlyContinue }
            [System.Windows.Forms.MessageBox]::Show("Username or Password incorrect.`n`nPlease try again.", "Authentication Failed", 0, 16) | Out-Null
            $loadedFromCache = $false 
            continue 
        }
    }
}

# ============================================================
# เริ่มต้นโปรแกรมหลัก (Main Program)
# ============================================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module -Name ActiveDirectory)) {
    [System.Windows.Forms.MessageBox]::Show("ไม่พบ Active Directory PowerShell Module (RSAT) บนเครื่องนี้`n`nกรุณาติดตั้ง 'RSAT: Active Directory Domain Services and Lightweight Directory Tools' ก่อนใช้งานโปรแกรมนี้", "Missing Requirement", 0, 16) | Out-Null
    exit
}

# ---- [SECURITY FIX] สุ่มรหัสผ่านชั่วคราวด้วย Cryptographic Random ----
function New-RandomPassword {
    $upperSet   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lowerSet   = 'abcdefghijkmnpqrstuvwxyz'
    $digitSet   = '23456789'
    $specialSet = '!@#$%^&*'
    $allSet     = $upperSet + $lowerSet + $digitSet + $specialSet

    # ใช้ RandomNumberGenerator เพื่อความปลอดภัยระดับที่ Source Code Scanner ยอมรับ
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 1

    function Get-SecureRandom($max) {
        do { $rng.GetBytes($bytes) } while ($bytes[0] -ge 255 - (255 % $max))
        return $bytes[0] % $max
    }

    $required = @(
        $upperSet[ (Get-SecureRandom $upperSet.Length) ],
        $lowerSet[ (Get-SecureRandom $lowerSet.Length) ],
        $digitSet[ (Get-SecureRandom $digitSet.Length) ],
        $specialSet[ (Get-SecureRandom $specialSet.Length) ]
    )
    
    $rest = 1..8 | ForEach-Object { $allSet[ (Get-SecureRandom $allSet.Length) ] }
    
    # Shuffle array
    $combined = $required + $rest
    for ($i = $combined.Length - 1; $i -gt 0; $i--) {
        $j = Get-SecureRandom ($i + 1)
        $temp = $combined[$i]; $combined[$i] = $combined[$j]; $combined[$j] = $temp
    }
    
    return -join $combined
}

# ---- โทนสีและฟอนต์ ----
$ColorBg         = [System.Drawing.Color]::FromArgb(245, 246, 248)
$ColorPanel      = [System.Drawing.Color]::White
$ColorAccent     = [System.Drawing.Color]::FromArgb(37, 99, 235)
$ColorSuccess    = [System.Drawing.Color]::FromArgb(22, 163, 74)
$ColorDanger     = [System.Drawing.Color]::FromArgb(220, 38, 38)
$ColorText       = [System.Drawing.Color]::FromArgb(31, 41, 55)
$ColorMuted      = [System.Drawing.Color]::FromArgb(107, 114, 128)
$ColorBorder     = [System.Drawing.Color]::FromArgb(229, 231, 235)
$ColorLightGreen = [System.Drawing.Color]::FromArgb(187, 247, 208)
$ColorLightGray  = [System.Drawing.Color]::FromArgb(107, 114, 128)
$ColorLight      = [System.Drawing.Color]::FromArgb(209, 213, 219)

$FontGlobal     = New-Object System.Drawing.Font("Leelawadee UI", 10.5)
$FontTitle      = New-Object System.Drawing.Font("Leelawadee UI", 12, [System.Drawing.FontStyle]::Bold)
$FontInput      = New-Object System.Drawing.Font("Leelawadee UI", 11)
$FontButton     = New-Object System.Drawing.Font("Leelawadee UI", 10.5, [System.Drawing.FontStyle]::Bold)
$FontSmCap      = New-Object System.Drawing.Font("Leelawadee UI", 9, [System.Drawing.FontStyle]::Bold)
$FontResult     = New-Object System.Drawing.Font("Leelawadee UI", 11)
$FontCompResult = New-Object System.Drawing.Font("Consolas", 11)

# ---- ตัวแปร Global ----
$script:ActiveTargetUser = $null  
$script:DnsServers = @()
try {
    $script:DnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
        Select-Object -ExpandProperty ServerAddresses |
        Where-Object { $_ } | Select-Object -Unique -First 2
} catch { }

# ---- หน้าต่างโปรแกรมหลัก ----
$form = New-Object System.Windows.Forms.Form
$form.Text          = "AD Helpdesk Tool"
$form.Size          = New-Object System.Drawing.Size(620, 560)
$form.MinimumSize   = New-Object System.Drawing.Size(560, 500)
$form.StartPosition = "CenterScreen"
$form.Font          = $FontGlobal
$form.BackColor     = $ColorBg
$form.ForeColor     = $ColorText

try {
    $currentProcess = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($currentProcess)
} catch { }

# ---- Status bar ----
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.SizingGrip = $false
$statusStrip.BackColor  = $ColorBg
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text      = "Ready"
$statusLabel.Font      = New-Object System.Drawing.Font("Leelawadee UI", 11)
$statusLabel.ForeColor = $ColorText
$statusLabel.Spring    = $true
$statusLabel.TextAlign = "MiddleLeft"
$statusStrip.Items.Add($statusLabel) | Out-Null

$lblCredit = New-Object System.Windows.Forms.ToolStripStatusLabel
$lblCredit.Text      = "(c) $(Get-Date -Format 'yyyy') Helpdesk Tools."
$lblCredit.Font      = New-Object System.Drawing.Font("Leelawadee UI", 9)
$lblCredit.ForeColor = $ColorMuted
$lblCredit.TextAlign = "MiddleRight"
$statusStrip.Items.Add($lblCredit) | Out-Null

function Set-Status($msg, $color = $ColorText) {
    $statusLabel.Text      = $msg
    $statusLabel.ForeColor = $color
}

function LogMsg($m, $level = "INFO") {
    $stamp  = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($level) { "ERROR" { "[!] " } "SUCCESS" { "[OK] " } default { "[i] " } }
    $txtLogs.AppendText("$stamp $prefix$m`r`n")
    $txtLogs.SelectionStart = $txtLogs.Text.Length
    $txtLogs.ScrollToCaret()
}

function Resolve-ViaNslookup($Name, $Server) {
    try {
        $output = & nslookup $Name $Server 2>&1
        $lines  = $output -split "`r?`n"
        $nameIdx = ($lines | Select-String -Pattern "^Name:" | Select-Object -First 1).LineNumber
        if (-not $nameIdx) { return $null }
        $afterName = $lines[$nameIdx..($lines.Count - 1)]
        $addrLine  = $afterName | Where-Object { $_ -match "^Address(es)?:\s*([\d\.]+)" } | Select-Object -First 1
        if ($addrLine -and $addrLine -match "([\d]{1,3}(\.[\d]{1,3}){3})") { return $matches[1] }
        return $null
    } catch { return $null }
}

# ============================================================
#  UI Components Helpers
# ============================================================
function New-StyledButton($Text, $BackColor, $ForeColor = [System.Drawing.Color]::White, $Height = 36) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $Text
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $BackColor
    $b.ForeColor = $ForeColor
    $b.Font      = $FontButton
    $b.Height    = $Height
    $b.TextAlign = "MiddleCenter"
    $b.Cursor    = "Hand"
    $b.Margin    = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
    $b.Tag       = $BackColor
    $b.Add_MouseEnter({ $this.BackColor = [System.Windows.Forms.ControlPaint]::Dark($this.Tag, 0.08) })
    $b.Add_MouseLeave({ $this.BackColor = $this.Tag })
    return $b
}

function New-Card($titleText) {
    $card = New-Object System.Windows.Forms.Panel
    $card.BackColor = $ColorPanel
    $card.Dock      = "Fill"
    $card.Padding   = New-Object System.Windows.Forms.Padding(15)

    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Dock = "Fill"
    
    $divider = New-Object System.Windows.Forms.Label
    $divider.Height = 1
    $divider.BackColor = $ColorBorder
    $divider.Dock = "Top"
    
    $spacer = New-Object System.Windows.Forms.Panel
    $spacer.Height = 10
    $spacer.Dock = "Top"

    $title = New-Object System.Windows.Forms.Label
    $title.Text      = $titleText
    $title.Font      = $FontTitle
    $title.ForeColor = $ColorAccent
    $title.Dock      = "Top"
    $title.Height    = 28

    $card.Controls.Add($contentPanel)
    $card.Controls.Add($spacer)
    $card.Controls.Add($divider)
    $card.Controls.Add($title)
    
    return @{ Card = $card; Body = $contentPanel }
}

function New-SectionLabel($text, $color = $null) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $text
    $l.Font      = $FontSmCap
    $l.ForeColor = if ($color) { $color } else { $ColorMuted }
    $l.AutoSize  = $true
    $l.Margin    = New-Object System.Windows.Forms.Padding(0, 15, 0, 5)
    return $l
}

function Confirm-Action($message, $title = "Confirm Action") {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = $title; $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedDialog"; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $dlg.BackColor = $ColorPanel
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $message; $lbl.Font = $FontInput; $lbl.ForeColor = $ColorText
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $m = [System.Windows.Forms.TextRenderer]::MeasureText($message, $FontInput, (New-Object System.Drawing.Size(400,0)), [System.Windows.Forms.TextFormatFlags]::WordBreak)
    $lbl.Size = New-Object System.Drawing.Size(400, ($m.Height + 8))
    $y = $lbl.Bottom + 20
    
    $bY = New-StyledButton "Yes" $ColorAccent
    $bY.Size = New-Object System.Drawing.Size(100,36); $bY.Location = New-Object System.Drawing.Point(20,$y); $bY.DialogResult = "Yes"
    
    $bN = New-Object System.Windows.Forms.Button; $bN.Text = "No"; $bN.Font = $FontInput; $bN.FlatStyle = "Flat"
    $bN.Size = New-Object System.Drawing.Size(100,36); $bN.Location = New-Object System.Drawing.Point(130,$y); $bN.DialogResult = "No"
    
    $dlg.Controls.AddRange(@($lbl,$bY,$bN)); $dlg.AcceptButton = $bY; $dlg.CancelButton = $bN
    $dlg.ClientSize = New-Object System.Drawing.Size(440, ($bY.Bottom + 20))
    return ($dlg.ShowDialog() -eq "Yes")
}

function Show-PasswordDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Set New Password"; $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedDialog"; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $dlg.BackColor = $ColorPanel; $dlg.ClientSize = New-Object System.Drawing.Size(320, 200)
    
    $lbl = New-Object System.Windows.Forms.Label; $lbl.Text = "Enter new password:"; $lbl.Font = $FontGlobal
    $lbl.Location = New-Object System.Drawing.Point(20,20); $lbl.AutoSize = $true
    
    $txt = New-Object System.Windows.Forms.TextBox; $txt.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
    $txt.Location = New-Object System.Drawing.Point(20,45); $txt.Size = New-Object System.Drawing.Size(272,26); $txt.UseSystemPasswordChar = $true
    
    $chk = New-Object System.Windows.Forms.CheckBox; $chk.Text = "Show password"; $chk.Font = $FontGlobal
    $chk.Location = New-Object System.Drawing.Point(20,75); $chk.AutoSize = $true
    $chk.Add_CheckedChanged({ $txt.UseSystemPasswordChar = -not $chk.Checked })
    
    $hint = New-Object System.Windows.Forms.Label; $hint.Text = "Minimum 8 characters recommended."
    $hint.Font = New-Object System.Drawing.Font("Leelawadee UI", 9); $hint.ForeColor = $ColorMuted
    $hint.Location = New-Object System.Drawing.Point(20,100); $hint.AutoSize = $true
    
    $bOk = New-StyledButton "Set Password" $ColorAccent ([System.Drawing.Color]::White) 34
    $bOk.Size = New-Object System.Drawing.Size(126,34); $bOk.Location = New-Object System.Drawing.Point(20,135); $bOk.DialogResult = "OK"
    
    $bCx = New-Object System.Windows.Forms.Button; $bCx.Text = "Cancel"; $bCx.Font = $FontGlobal; $bCx.FlatStyle = "Flat"
    $bCx.Size = New-Object System.Drawing.Size(126,34); $bCx.Location = New-Object System.Drawing.Point(166,135); $bCx.DialogResult = "Cancel"
    
    $dlg.Controls.AddRange(@($lbl,$txt,$chk,$hint,$bOk,$bCx)); $dlg.AcceptButton = $bOk; $dlg.CancelButton = $bCx
    
    if ($dlg.ShowDialog() -eq "OK" -and $txt.Text) { return $txt.Text }
    return $null
}

# ============================================================
#  UI: Search Bar & Logout
# ============================================================
$pnlSearch = New-Object System.Windows.Forms.Panel
$pnlSearch.Dock = "Top"
$pnlSearch.Height = 60
$pnlSearch.BackColor = $ColorBg
$pnlSearch.Padding = New-Object System.Windows.Forms.Padding(15, 14, 15, 14)

$innerSearch = New-Object System.Windows.Forms.TableLayoutPanel
$innerSearch.Dock = "Fill"
$innerSearch.ColumnCount = 3
$innerSearch.RowCount = 1

$innerSearch.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32))) | Out-Null
$innerSearch.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$innerSearch.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90))) | Out-Null 
$innerSearch.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90))) | Out-Null 

$wrapSearch = New-Object System.Windows.Forms.Panel
$wrapSearch.Dock = "Fill"
$wrapSearch.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
$wrapSearch.BackColor = $ColorPanel
$wrapSearch.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)

$bottomLine = New-Object System.Windows.Forms.Label
$bottomLine.Dock = "Bottom"
$bottomLine.Height = 1
$bottomLine.BackColor = $ColorBorder

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Font = $FontInput
$txtSearch.Dock = "Fill"
$txtSearch.BorderStyle = "None"
$txtSearch.BackColor = $ColorPanel
$txtSearch.Text = "Enter Username or Computer Name..."
$txtSearch.ForeColor = $ColorMuted

$txtSearch.Add_GotFocus({
    $bottomLine.Height = 2
    $bottomLine.BackColor = $ColorAccent
    if ($this.Text -eq "Enter Username or Computer Name...") {
        $this.Text = ""; $this.ForeColor = $ColorText
    }
})

$txtSearch.Add_LostFocus({
    $bottomLine.Height = 1
    $bottomLine.BackColor = $ColorBorder
    if ([string]::IsNullOrWhiteSpace($this.Text)) {
        $this.Text = "Enter Username or Computer Name..."; $this.ForeColor = $ColorMuted
    }
})

$wrapSearch.Controls.Add($bottomLine)
$wrapSearch.Controls.Add($txtSearch)

$btnSearch = New-StyledButton "Search" $ColorAccent ([System.Drawing.Color]::White) 25 
$btnSearch.Dock = "Fill"
$btnSearch.Margin = New-Object System.Windows.Forms.Padding(0)

# ---- ปุ่ม Logout ----
$btnLogout = New-Object System.Windows.Forms.Label
$btnLogout.Text = "Logout"
$btnLogout.Font = New-Object System.Drawing.Font("Leelawadee UI", 9.5, [System.Drawing.FontStyle]::Underline)
$btnLogout.ForeColor = $ColorDanger
$btnLogout.Cursor = "Hand"
$btnLogout.TextAlign = "MiddleCenter"
$btnLogout.Dock = "Fill"
$btnLogout.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)

$btnLogout.Add_MouseEnter({ $this.ForeColor = [System.Drawing.Color]::FromArgb(153, 27, 27) })
$btnLogout.Add_MouseLeave({ $this.ForeColor = $ColorDanger })

$btnLogout.Add_Click({
    if (Confirm-Action "Are you sure you want to logout?`nThis will close the application." "Confirm Logout") {
        
        # [UPDATED] อัปเดต Path การลบ Cache ตามที่มีการย้ายที่เก็บไฟล์ใหม่
        $credFile = if ($CredFilePath) { $CredFilePath } else { "$env:LOCALAPPDATA\ADHelpdeskTool\Cache\AdminCred.xml" }
        if (Test-Path $credFile) { 
            Remove-Item -Path $credFile -Force -ErrorAction SilentlyContinue
        }
        
        # Cleanup legacy paths if they exist
        $legacyPaths = @("$env:PUBLIC\ADHelpdesk_AdminCred.xml", "$env:TEMP\ADHelpdesk_AdminCred.xml")
        foreach ($p in $legacyPaths) {
            if (Test-Path $p) { Remove-Item -Path $p -Force -ErrorAction SilentlyContinue }
        }
        
        $form.Close()
        [System.Environment]::Exit(0)
    }
})

$innerSearch.Controls.Add($wrapSearch, 0, 0)
$innerSearch.Controls.Add($btnSearch, 1, 0)
$innerSearch.Controls.Add($btnLogout, 2, 0)
$pnlSearch.Controls.Add($innerSearch)
$form.Controls.Add($pnlSearch)

# ============================================================
#  Tabs System
# ============================================================
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Fill"
$tabs.Font = $FontGlobal
$tabs.Padding = New-Object System.Drawing.Point(10, 6)

$tabUser     = New-Object System.Windows.Forms.TabPage; $tabUser.Text     = "User Profile"
$tabAccount  = New-Object System.Windows.Forms.TabPage; $tabAccount.Text  = "Account Management"
$tabComputer = New-Object System.Windows.Forms.TabPage; $tabComputer.Text = "Computer Info"
$tabLogs     = New-Object System.Windows.Forms.TabPage; $tabLogs.Text     = "Activity Log"

foreach ($t in @($tabUser, $tabAccount, $tabComputer, $tabLogs)) { $t.BackColor = $ColorBg }
$tabs.TabPages.AddRange(@($tabUser, $tabAccount, $tabComputer, $tabLogs))
$form.Controls.Add($tabs)
$form.Controls.Add($statusStrip)

$pnlSearch.SendToBack()
$tabs.BringToFront()

# ============================================================
#  Tab 1: User Profile
# ============================================================
$pnlResults = New-Object System.Windows.Forms.TableLayoutPanel
$pnlResults.Dock = "Fill"
$pnlResults.Padding = New-Object System.Windows.Forms.Padding(18, 12, 18, 18)
$pnlResults.ColumnCount = 2
$pnlResults.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 65))) | Out-Null
$pnlResults.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 35))) | Out-Null

$uiCardInfo = New-Card "Profile Details"
$uiCardInfo.Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
$txtInfo = New-Object System.Windows.Forms.RichTextBox
$txtInfo.Multiline = $true; $txtInfo.ReadOnly = $true; $txtInfo.BorderStyle = "None"
$txtInfo.WordWrap = $false; $txtInfo.ScrollBars = "Horizontal"
$txtInfo.Dock = "Fill"; $txtInfo.Font = $FontResult; $txtInfo.BackColor = $ColorPanel
$uiCardInfo.Body.Controls.Add($txtInfo)

$uiCardGroups = New-Card "Group Membership"
$uiCardGroups.Card.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
$txtGroups = New-Object System.Windows.Forms.RichTextBox
$txtGroups.Multiline = $true; $txtGroups.ReadOnly = $true; $txtGroups.BorderStyle = "None"
$txtGroups.Dock = "Fill"; $txtGroups.ScrollBars = "Horizontal"; $txtGroups.Font = $FontResult; $txtGroups.BackColor = $ColorPanel; $txtGroups.WordWrap = $false
$uiCardGroups.Body.Controls.Add($txtGroups)

$pnlResults.Controls.Add($uiCardInfo.Card, 0, 0)
$pnlResults.Controls.Add($uiCardGroups.Card, 1, 0)
$tabUser.Controls.Add($pnlResults)

# ============================================================
#  Tab 2: Account Management
# ============================================================
$lblTarget = New-Object System.Windows.Forms.Label
$lblTarget.Text = "Target: No User Selected"
$lblTarget.Dock = "Top"
$lblTarget.Height = 55
$lblTarget.TextAlign = "BottomCenter"
$lblTarget.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 5)
$lblTarget.Font = New-Object System.Drawing.Font("Leelawadee UI", 10.5, [System.Drawing.FontStyle]::Bold)
$lblTarget.ForeColor = $ColorMuted
$tabAccount.Controls.Add($lblTarget)

$flowAccount = New-Object System.Windows.Forms.FlowLayoutPanel
$flowAccount.Dock = "Fill"; $flowAccount.FlowDirection = "TopDown"; $flowAccount.WrapContents = $false
$tabAccount.Controls.Add($flowAccount)

$BW = 300   
$btnResetCustom  = New-StyledButton "Reset Password (Custom)"      $ColorAccent; $btnResetCustom.Width = $BW
$btnResetDefault = New-StyledButton "Reset Password (Random Temp)"   $ColorLightGray; $btnResetDefault.Width = $BW
$btnAddAdmin     = New-StyledButton "Add to Local_Admin Group"     $ColorLightGray ([System.Drawing.Color]::FromArgb(31,41,55)); $btnAddAdmin.Width = $BW

$flowAccount.Controls.AddRange(@(
    (New-SectionLabel "PASSWORD"),
    $btnResetCustom, 
    $btnResetDefault,
    (New-SectionLabel "PRIVILEGED ACCESS - use with caution" $ColorDanger), 
    $btnAddAdmin
))
$flowAccount.BringToFront()

function Update-AccountCentering {
    $left = [Math]::Max(10, [int](($flowAccount.ClientSize.Width - $BW) / 2))
    $flowAccount.Padding = New-Object System.Windows.Forms.Padding($left, 10, 10, 20)
}
$flowAccount.Add_SizeChanged({ Update-AccountCentering })

# ============================================================
#  Tab 3: Computer Info
# ============================================================
$pnlComp = New-Object System.Windows.Forms.TableLayoutPanel
$pnlComp.Dock = "Fill"
$pnlComp.Padding = New-Object System.Windows.Forms.Padding(15)
$pnlComp.ColumnCount = 2    
$pnlComp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 65))) | Out-Null
$pnlComp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 35))) | Out-Null

$uiCardComp = New-Card "Computer Details"
$uiCardComp.Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
$txtCompInfo = New-Object System.Windows.Forms.RichTextBox
$txtCompInfo.Multiline = $true; $txtCompInfo.ReadOnly = $true; $txtCompInfo.BorderStyle = "None"
$txtCompInfo.WordWrap = $false
$txtCompInfo.ScrollBars = "Both"
$txtCompInfo.Dock = "Fill"; $txtCompInfo.Font = $FontCompResult; $txtCompInfo.BackColor = $ColorPanel
$uiCardComp.Body.Controls.Add($txtCompInfo)

$uiCardCompUsers = New-Card "Local User Profiles"
$uiCardCompUsers.Card.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
$txtCompUsers = New-Object System.Windows.Forms.RichTextBox
$txtCompUsers.Multiline = $true; $txtCompUsers.ReadOnly = $true; $txtCompUsers.BorderStyle = "None"
$txtCompUsers.ScrollBars = "Both"
$txtCompUsers.WordWrap = $false
$txtCompUsers.Dock = "Fill"; $txtCompUsers.Font = $FontResult; $txtCompUsers.BackColor = $ColorPanel
$uiCardCompUsers.Body.Controls.Add($txtCompUsers)

$pnlComp.Controls.Add($uiCardComp.Card, 0, 0)
$pnlComp.Controls.Add($uiCardCompUsers.Card, 1, 0)
$tabComputer.Controls.Add($pnlComp)

# ============================================================
#  Tab 4: Logs
# ============================================================
$pnlLogs = New-Object System.Windows.Forms.TableLayoutPanel
$pnlLogs.Dock = "Fill"; $pnlLogs.Padding = New-Object System.Windows.Forms.Padding(15)
$pnlLogs.ColumnCount = 1; $pnlLogs.RowCount = 2
$pnlLogs.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40))) | Out-Null
$pnlLogs.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$tabLogs.Controls.Add($pnlLogs)

$btnClearLogs = New-StyledButton "Clear Log" $ColorMuted ([System.Drawing.Color]::White) 30
$btnClearLogs.Width = 100; $btnClearLogs.Anchor = "Left"
$btnClearLogs.Margin = New-Object System.Windows.Forms.Padding(0,0,0,10)

$txtLogs = New-Object System.Windows.Forms.TextBox
$txtLogs.Dock = "Fill"; $txtLogs.Multiline = $true; $txtLogs.ScrollBars = "None"; $txtLogs.WordWrap = $false
$txtLogs.ReadOnly = $true; $txtLogs.Font = New-Object System.Drawing.Font("Consolas", 10)
$txtLogs.BackColor = [System.Drawing.Color]::FromArgb(28,28,28)
$txtLogs.ForeColor = [System.Drawing.Color]::FromArgb(212,212,212)
$txtLogs.BorderStyle = "None"

$pnlLogs.Controls.Add($btnClearLogs, 0, 0)
$pnlLogs.Controls.Add($txtLogs, 0, 1)
$btnClearLogs.Add_Click({ $txtLogs.Clear() })

# ============================================================
#  LOGIC: Unified Search
# ============================================================
$script:userIsLocalAdmin = $false

function Update-AdminButton($isMember) {
    $script:userIsLocalAdmin = $isMember
    if ($isMember) {
        $btnAddAdmin.Text = "Remove from Local_Admin Group"
        $btnAddAdmin.BackColor = $ColorLight; $btnAddAdmin.Tag = $ColorLight
        $btnAddAdmin.ForeColor = [System.Drawing.Color]::White
    } else {
        $btnAddAdmin.Text = "Add to Local_Admin Group"
        $btnAddAdmin.BackColor = $ColorLightGreen; $btnAddAdmin.Tag = $ColorLightGreen
        $btnAddAdmin.ForeColor = [System.Drawing.Color]::FromArgb(31,41,55)
    }
}

function Do-UnifiedSearch {
    $term = $txtSearch.Text.Trim()
    if (-not $term -or $term -eq "Enter Username or Computer Name...") {
        Set-Status "Please enter a name to search." $ColorDanger
        $txtSearch.Focus(); return
    }

    $btnSearch.Enabled = $false
    Set-Status "Searching for '$term'..." $ColorAccent

    $userFound = $false
    $compFound = $false
    $adUser    = $null
    $comp      = $null

    try {
        $adUser = Get-ADUser -Filter "SamAccountName -eq '$term' -or DisplayName -like '*$term*' -or Name -like '*$term*' -or GivenName -like '*$term*' -or Surname -like '*$term*'" `
            -Properties DisplayName,GivenName,Surname,Department,Title,Enabled,LockedOut,MemberOf `
            -ErrorAction Stop | Select-Object -First 1

        if (-not $adUser) { throw "User not found" }
        $userFound = $true

        $script:ActiveTargetUser = $adUser.SamAccountName
        $lblTarget.Text = "Target User: $($adUser.SamAccountName)"

        $thaiName = "$($adUser.GivenName) $($adUser.Surname)".Trim()
        if ($thaiName -and ($thaiName -ne $adUser.SamAccountName)) {
            $lblTarget.Text += " ($thaiName)"
        }
        $lblTarget.ForeColor = $ColorSuccess

        if ($adUser.LockedOut) {
            $userStatus = "Locked Out"
        } elseif ($adUser.Enabled) {
            $userStatus = "Enabled"
        } else {
            $userStatus = "Disabled"
        }

$txtInfo.Text = @"
Name:      $($adUser.GivenName) $($adUser.Surname)
Display:   $($adUser.DisplayName)
Title:     $($adUser.Title)
Dept:      $($adUser.Department)
Status:    $userStatus
"@
        $groups = @()
        if ($adUser.MemberOf) {
            $groups = $adUser.MemberOf | ForEach-Object { ($_ -split ',')[0].Replace('CN=','') } | Sort-Object
            $txtGroups.Text = $groups -join "`r`n"
        } else { $txtGroups.Text = "(no groups)" }

        Update-AdminButton ($groups -contains "Local_Admin")
    } catch { }

    try {
        $comp = Get-ADComputer -Identity $term -Properties Name,OperatingSystem,OperatingSystemVersion,IPv4Address,LastLogonDate,Description,whenCreated,Enabled -ErrorAction Stop

        $compFound = $true

        if (-not $userFound) {
            $script:ActiveTargetUser = $null
            $lblTarget.Text = "Target: No User Selected"
            $lblTarget.ForeColor = $ColorMuted
        }

        $liveIP = ""; $ping = "Offline"
        $dnsLines = @()

        if ($script:DnsServers.Count -gt 0) {
            foreach ($srv in $script:DnsServers) {
                $dnsLines += "  - $srv"
                if (-not $liveIP) {
                    $resolvedIp = Resolve-ViaNslookup -Name $term -Server $srv
                    if ($resolvedIp) { $liveIP = $resolvedIp }
                }
            }
        } else {
            $dnsLines += "  - (default resolver)"
            try {
                $dns = [System.Net.Dns]::GetHostAddresses($term) | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1
                if ($dns) { $liveIP = $dns.IPAddressToString }
            } catch {}
        }

        if ($liveIP) {
            try {
                $r = (New-Object System.Net.NetworkInformation.Ping).Send($liveIP, 1000)
                if ($r.Status -eq "Success") { $ping = "Online ($([int]$r.RoundtripTime) ms)" }
            } catch {}
        }
        
        $dnsBlockLines = @()
        for ($i = 0; $i -lt $dnsLines.Count; $i++) {
            $prefix = if ($i -eq 0) { "DNS:".PadRight(13) } else { "".PadRight(13) }
            $dnsBlockLines += "$prefix$($dnsLines[$i].TrimStart())"
        }
        $dnsBlock = if ($dnsBlockLines.Count -gt 0) { $dnsBlockLines -join "`r`n" } else { "DNS:".PadRight(13) + "-" }
        $ip = if ($liveIP) { $liveIP } elseif ($comp.IPv4Address) { "$($comp.IPv4Address) (AD)" } else { "-" }
        
        if (-not $comp.Enabled) {
            $adStatus = "Disabled (Officially Disabled in AD)"
        } elseif ($comp.LastLogonDate) {
            $daysInactive = ((Get-Date) - $comp.LastLogonDate).Days
            if ($daysInactive -gt 30) {
                $adStatus = "Inactive ($daysInactive days) - Possibly Unjoined"
            } else {
                $adStatus = "Active (Joined)"
            }
        } else {
            $adStatus = "Active (But NEVER logged on)"
        }
        
        $joinDate = if ($comp.whenCreated) { $comp.whenCreated.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
        $lastLogon = if ($comp.LastLogonDate) { $comp.LastLogonDate.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }

$txtCompInfo.Text = @"
Name:        $($comp.Name)
OS:          $($comp.OperatingSystem)
Version:     $($comp.OperatingSystemVersion)
IP Address:  $ip
$dnsBlock
AD Status:   $adStatus
Join Date:   $joinDate
Last Logon:  $lastLogon
Description: $($comp.Description)
"@
        if ($liveIP) {
            LogMsg "DNS resolved '$term' to $liveIP" "SUCCESS"
        } else {
            LogMsg "DNS lookup failed for '$term' on all configured server(s)" "ERROR"
        }
        
        if ($ping -like "Online*") {
            $excludedProfiles = @('Public', 'Default', 'Default User', 'All Users')
            try {
                $profileFolders = Get-ChildItem -Path "\\$term\C$\Users" -Directory -ErrorAction Stop |
                    Where-Object { $excludedProfiles -notcontains $_.Name -and $_.Attributes -notmatch "ReparsePoint" } |
                    Select-Object -ExpandProperty Name | Sort-Object
                
                if ($profileFolders) {
                    $txtCompUsers.Text = $profileFolders -join "`r`n"
                    LogMsg "Found $($profileFolders.Count) user profile(s) on $term" "SUCCESS"
                } else {
                    $txtCompUsers.Text = "(no local user profiles found)"
                }
            } catch {
                $txtCompUsers.Text = "Unable to read user profiles.`r`n(Access denied or C`$ not shared)"
                LogMsg "Failed to read Users folder on $term`: $_" "ERROR"
            }
        } else {
            $txtCompUsers.Text = "Skipped - computer appears offline."
        }
    } catch { }

    if ($userFound -and $compFound) {
        $tabs.SelectedTab = $tabUser
        Set-Status "Found both User and Computer named '$term'." $ColorSuccess
        LogMsg "Found both User ($($adUser.SamAccountName)) and Computer ($term) with matching name" "SUCCESS"
    } elseif ($userFound) {
        $txtCompInfo.Text = ""; $txtCompUsers.Text = ""
        $tabs.SelectedTab = $tabUser
        Set-Status "Found User: $($adUser.DisplayName)" $ColorSuccess
        LogMsg "Found User: $($adUser.SamAccountName)" "SUCCESS"
    } elseif ($compFound) {
        $txtInfo.Text = ""; $txtGroups.Text = ""
        $tabs.SelectedTab = $tabComputer
        Set-Status "Found Computer: '$term'" $ColorSuccess
        LogMsg "Found Computer: $term" "SUCCESS"
    } else {
        $txtInfo.Text = ""; $txtGroups.Text = ""; $txtCompInfo.Text = ""; $txtCompUsers.Text = ""
        $script:ActiveTargetUser = $null
        $lblTarget.Text = "Target: No User Selected"
        $lblTarget.ForeColor = $ColorMuted
        $tabs.SelectedTab = $tabUser
        Set-Status "'$term' not found in Active Directory." $ColorDanger
        LogMsg "Object not found: $term" "ERROR"
    }

    $btnSearch.Enabled = $true
}

$btnSearch.Add_Click({ Do-UnifiedSearch })
$txtSearch.Add_KeyDown({ if ($_.KeyCode -eq "Enter") { Do-UnifiedSearch; $_.SuppressKeyPress = $true } })

# ============================================================
#  Account Action Events
# ============================================================
function Verify-Target {
    if (-not $script:ActiveTargetUser) {
        $msg = New-Object System.Windows.Forms.Form
        $msg.Text = "No User Selected"; $msg.StartPosition = "CenterParent"
        $msg.BackColor = $ColorPanel; $msg.ClientSize = New-Object System.Drawing.Size(300, 120)
        $msg.FormBorderStyle = "FixedDialog"; $msg.MaximizeBox = $false; $msg.MinimizeBox = $false
        
        $lbl = New-Object System.Windows.Forms.Label; $lbl.Text = "Please search and select a User first."
        $lbl.Location = New-Object System.Drawing.Point(20, 20); $lbl.AutoSize = $true; $lbl.Font = $FontInput
        
        $btn = New-StyledButton "OK" $ColorAccent; $btn.Size = New-Object System.Drawing.Size(100, 36)
        $btn.Location = New-Object System.Drawing.Point(100, 60); $btn.DialogResult = "OK"
        
        $msg.Controls.AddRange(@($lbl, $btn)); $msg.AcceptButton = $btn
        $msg.ShowDialog() | Out-Null
        return $false
    }
    return $true
}

$btnResetDefault.Add_Click({
    if (-not (Verify-Target)) { return }
    $u = $script:ActiveTargetUser
    if (-not (Confirm-Action "Reset password for '$u' to a new random temporary password?`r`nUser must change at next logon.")) { return }

    $newPass = New-RandomPassword
    try {
        Set-ADAccountPassword -Identity $u -NewPassword (ConvertTo-SecureString $newPass -AsPlainText -Force) -Reset -ErrorAction Stop
        Set-ADUser -Identity $u -ChangePasswordAtLogon $true -ErrorAction SilentlyContinue
        Set-Status "Password reset for $u." $ColorSuccess; LogMsg "Temp reset: $u" "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show("New temporary password for '$u':`n`n$newPass`n`n(User must change it at next logon. Please share this securely and do not store it in plain text.)", "Password Reset Successful", 0, 64) | Out-Null
    } catch { Set-Status "Failed to reset $u." $ColorDanger; LogMsg "Temp reset fail $u`: $_" "ERROR" }
})

$btnResetCustom.Add_Click({
    if (-not (Verify-Target)) { return }
    $u = $script:ActiveTargetUser
    $p = Show-PasswordDialog; if (-not $p) { return }
    if ($p.Length -lt 8) { 
        [System.Windows.Forms.MessageBox]::Show("Password must be at least 8 characters.", "Weak Password", 0, 48) | Out-Null
        return 
    }
    
    try {
        Set-ADAccountPassword -Identity $u -NewPassword (ConvertTo-SecureString $p -AsPlainText -Force) -Reset -ErrorAction Stop
        Set-Status "Password set for $u." $ColorSuccess; LogMsg "Custom reset: $u" "SUCCESS"
    } catch { Set-Status "Failed to reset $u." $ColorDanger; LogMsg "Custom reset fail $u`: $_" "ERROR" }
})

$btnAddAdmin.Add_Click({
    if (-not (Verify-Target)) { return }
    $u = $script:ActiveTargetUser
    
    if ($script:userIsLocalAdmin) {
        if (-not (Confirm-Action "Remove '$u' from Local_Admin?`r`nThis will revoke privileged access.")) { return }
        try {
            Remove-ADGroupMember -Identity "Local_Admin" -Members $u -Confirm:$false -ErrorAction Stop
            Update-AdminButton $false; Set-Status "$u removed from Local_Admin." $ColorSuccess; LogMsg "Removed $u from Local_Admin." "SUCCESS"
        } catch { Set-Status "Failed to remove $u." $ColorDanger; LogMsg "Remove admin fail $u`: $_" "ERROR" }
    } else {
        if (-not (Confirm-Action "Grant '$u' Local_Admin?`r`nThis is a sensitive permission change.")) { return }
        try {
            Add-ADGroupMember -Identity "Local_Admin" -Members $u -ErrorAction Stop
            Update-AdminButton $true; Set-Status "$u added to Local_Admin." $ColorSuccess; LogMsg "Added $u to Local_Admin." "SUCCESS"
        } catch { Set-Status "Failed to add $u." $ColorDanger; LogMsg "Add admin fail $u`: $_" "ERROR" }
    }
})

$form.Add_Shown({
    Update-AccountCentering
    $txtSearch.Focus()
    if ($script:DnsServers.Count -gt 0) {
        LogMsg "Detected DNS server(s): $($script:DnsServers -join ', ')" "INFO"
    } else {
        LogMsg "No DNS server detected on this machine." "ERROR"
    }
})

[void]$form.ShowDialog()