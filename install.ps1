
$ErrorActionPreference = "Stop"

$Repo = "madoiscool/BetterSteamTools"
$Headers = @{ "User-Agent" = "BetterSteamTools-Installer" }

Write-Host "`n=== BetterSteamTools Auto Installer ===" -ForegroundColor Cyan

# 1. Tim Steam
$Steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath

if (-not $Steam) {
    $Steam = "${env:ProgramFiles(x86)}\Steam"
}

if (-not (Test-Path "$Steam\steam.exe")) {
    $Steam = Read-Host "Nhap duong dan thu muc Steam"
}

if (-not (Test-Path "$Steam\steam.exe")) {
    throw "Khong tim thay Steam!"
}

# 2. Tu dong tat Steam truoc khi cai dat
Write-Host "`nDang kiem tra Steam..." -ForegroundColor Yellow

$SteamProcesses = @(
    "steam",
    "steamwebhelper"
)

foreach ($ProcessName in $SteamProcesses) {
    Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Stop-Process -Force
}


# 3. Lay Release moi nhat
Write-Host "`nDang kiem tra GitHub Release..." -ForegroundColor Yellow

$Release = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/$Repo/releases/latest" `
    -Headers $Headers

if (-not $Release.assets) {
    throw "Release khong co file dinh kem!"
}

Write-Host "Phien ban: $($Release.tag_name)" -ForegroundColor Green

# 4. Tim file ZIP thong minh hon
$Assets = @($Release.assets)

$Asset = $Assets |
    Where-Object {
        $_.name -match '(?i)-Release.*\.zip$'
    } |
    Select-Object -First 1

if (-not $Asset) {
    Write-Host "`nKhong tim thay ZIP Release theo ten chuan." -ForegroundColor Yellow
    Write-Host "Cac file GitHub dang cung cap:" -ForegroundColor Cyan

    $Assets | ForEach-Object {
        Write-Host " - $($_.name)"
    }

    throw "Khong tim thay goi Release ZIP phu hop!"
}

Write-Host "Da tim thay: $($Asset.name)" -ForegroundColor Green

# 5. Tai file ZIP
$Temp = Join-Path $env:TEMP "BetterSteamTools"

New-Item -ItemType Directory -Force -Path $Temp | Out-Null

$Zip = Join-Path $Temp $Asset.name

Write-Host "`nDang tai $($Asset.name)..." -ForegroundColor Yellow

Invoke-WebRequest `
    -Uri $Asset.browser_download_url `
    -OutFile $Zip

if (!(Test-Path $Zip) -or (Get-Item $Zip).Length -eq 0) {
    throw "Tai file ZIP that bai hoac file rong!"
}

Write-Host "Tai thanh cong!" -ForegroundColor Green

# 6. Kiem tra va giai nen
$Extract = Join-Path $Temp "Extracted"

if (Test-Path $Extract) {
    Remove-Item $Extract -Recurse -Force
}

Expand-Archive -Path $Zip -DestinationPath $Extract -Force

Write-Host "Giai nen thanh cong!" -ForegroundColor Green

# 7. Kiem tra DLL
$Files = @(
    "dwmapi.dll",
    "xinput1_4.dll",
    "OpenSteamTool.dll"
)

$FoundFiles = @{}

foreach ($File in $Files) {
    $Found = Get-ChildItem $Extract -Filter $File -Recurse |
        Select-Object -First 1

    if (-not $Found) {
        throw "Thieu file $File. Huy cai dat!"
    }

    $FoundFiles[$File] = $Found.FullName
}

# 8. Sao luu DLL cu
$Backup = Join-Path $Steam "BSTs-backup"

New-Item -ItemType Directory -Force -Path $Backup | Out-Null

foreach ($File in $Files) {
    $Destination = Join-Path $Steam $File

    if (Test-Path $Destination) {
        Copy-Item $Destination `
            (Join-Path $Backup $File) -Force
    }
}

# 9. Cai DLL vao Steam
foreach ($File in $Files) {
    Copy-Item $FoundFiles[$File] `
        (Join-Path $Steam $File) -Force

    Write-Host "Da cai: $File" -ForegroundColor Green
}

# 10. Tao thu muc Lua config
$Config = Join-Path $Steam "config\stplug-in"

New-Item -ItemType Directory -Force -Path $Config | Out-Null

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "CAI DAT THANH CONG!" -ForegroundColor Green
Write-Host "Version: $($Release.tag_name)"
Write-Host "Steam: $Steam"
Write-Host "Lua: $Config"
Write-Host "Backup: $Backup"
Write-Host "================================" -ForegroundColor Cyan
# 11. Tu dong khoi dong lai Steam
Write-Host "`nDang khoi dong Steam..." -ForegroundColor Yellow

Start-Process -FilePath (Join-Path $Steam "steam.exe")

Write-Host "Steam da duoc khoi dong!" -ForegroundColor Green
# 12. Tu dong dong PowerShell sau khi hoan tat
Write-Host "`nDang dong PowerShell..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
exit