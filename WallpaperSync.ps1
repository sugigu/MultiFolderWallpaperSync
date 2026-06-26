# ==========================================
# WallpaperSync.ps1 (Fixed Syntax & Reload)
# ==========================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "WallpaperSync.config.json"

# ---------- Config ----------

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Config not found."
    exit 1
}

try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "JSON parse error."
    Write-Host $_
    exit 1
}

$Folders = $config.folders
$Extensions = $config.extensions

# ---------- Cache ----------

$CacheDir = "$env:LOCALAPPDATA\WallpaperSync"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $CacheDir | Out-Null

$CurrentImage = Join-Path $CacheDir "current_wallpaper.jpg"
$LastFile = Join-Path $CacheDir "last.txt"

# ---------- Scan (兩層式抽圖) ----------

# 1. 先篩選出真正存在且含有指定延伸檔名圖片的資料夾
$validFolders = @()
foreach ($folder in $Folders) {
    if (Test-Path $folder) {
        # 檢查該資料夾內（含子資料夾）是否有符合條件的圖片
        $hasImages = $false
        foreach ($ext in $Extensions) {
            if (Get-ChildItem -Path $folder -Filter $ext -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) {
                $hasImages = $true
                break
            }
        }
        if ($hasImages) {
            $validFolders += $folder
        }
    }
}

if ($validFolders.Count -eq 0) {
    Write-Host "No valid folders or images found."
    exit 1
}

# 2. 第一層：隨機抽選一個資料夾
$pickedFolder = Get-Random -InputObject $validFolders

# 3. 第二層：掃描該選定資料夾內的所有圖片
$images = foreach ($ext in $Extensions) {
    Get-ChildItem `
        -Path $pickedFolder `
        -Filter $ext `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue
}

# ---------- Random, avoid same image twice ----------

if (Test-Path $LastFile) {
    $last = Get-Content $LastFile -Raw
    $last = $last.Trim()
} else {
    $last = ""
}

$candidates = $images | Where-Object {
    $_.FullName -ne $last
}

if (-not $candidates) {
    $candidates = $images
}

# 抽選最終圖片
$pick = Get-Random -InputObject $candidates

Set-Content `
    -Path $LastFile `
    -Value $pick.FullName `
    -Encoding UTF8

# ---------- Convert JPG without locking source file ----------

Add-Type -AssemblyName System.Drawing

$bytes = [System.IO.File]::ReadAllBytes($pick.FullName)
$stream = New-Object System.IO.MemoryStream(,$bytes)

$image = [System.Drawing.Image]::FromStream($stream)

$image.Save(
    $CurrentImage,
    [System.Drawing.Imaging.ImageFormat]::Jpeg
)

$image.Dispose()
$stream.Dispose()

# ---------- Set Wallpaper & Update Accent Color ----------

# 防重複載入檢查：如果 Wallpaper 類別還不存在，才執行 Add-Type
if (-not ([System.Type]::GetType("Wallpaper"))) {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class Wallpaper
    {
        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern bool SystemParametersInfo(
            int uAction,
            int uParam,
            string lpvParam,
            int fuWinIni
        );

        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            uint Msg,
            IntPtr wParam,
            string lParam,
            uint fuFlags,
            uint uTimeout,
            out IntPtr lpdwResult
        );

        public static readonly IntPtr HWND_BROADCAST = (IntPtr)0xffff;
        public static readonly uint WM_SETTINGCHANGE = 0x001A;
        public static readonly uint SMTO_ABORTIFHUNG = 0x0002;
    }
"@
}

$SPI_SETDESKWALLPAPER = 20
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDCHANGE = 0x02

# 寫入桌布樣式登錄檔
Set-ItemProperty "HKCU:\Control Panel\Desktop" WallpaperStyle "10"
Set-ItemProperty "HKCU:\Control Panel\Desktop" TileWallpaper "0"

# 呼叫 SystemParametersInfo 更新桌布
[Wallpaper]::SystemParametersInfo(
    $SPI_SETDESKWALLPAPER,
    0,
    $CurrentImage,
    $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE
) | Out-Null

# 向所有頂層視窗廣播設定已變更，強制更新強調色
$result = [IntPtr]::Zero
[Wallpaper]::SendMessageTimeout(
    [Wallpaper]::HWND_BROADCAST,
    [Wallpaper]::WM_SETTINGCHANGE,
    [IntPtr]::Zero,
    "Environment",
    [Wallpaper]::SMTO_ABORTIFHUNG,
    5000,
    [ref]$result
) | Out-Null

# 額外保險：切換登錄檔開關觸發系統重繪
$ThemeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (Get-ItemProperty -Path $ThemeKey -Name "ColorPrevalence" -ErrorAction SilentlyContinue) {
    $current = (Get-ItemProperty -Path $ThemeKey -Name "ColorPrevalence").ColorPrevalence
    Set-ItemProperty -Path $ThemeKey -Name "ColorPrevalence" -Value ($current -eq 1 ? 0 : 1)
    Start-Sleep -Milliseconds 100
    Set-ItemProperty -Path $ThemeKey -Name "ColorPrevalence" -Value $current
}