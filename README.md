# WallpaperSync

A small PowerShell wallpaper randomizer for Windows.

WallpaperSync picks a wallpaper from multiple folders using a two-level random selection:

1. Randomly pick one valid folder from your configured folder list.
2. Randomly pick one image from the selected folder.

After setting the wallpaper, it also asks Windows to refresh the desktop settings so the Windows accent color can update from the new wallpaper, similar to the native Windows behavior when setting an image as desktop background.

Because apparently even changing wallpaper needs a small ritual sacrifice to the Windows personalization subsystem.

## Features

- Supports multiple wallpaper folders
- Two-level random selection: folder first, image second
- Searches images recursively inside each configured folder
- Skips folders that do not exist or contain no supported images
- Avoids selecting the same image twice in a row when possible
- Converts the selected image to a cached JPG before applying it
- Does not lock the original source image file
- Sets the wallpaper using the native Windows API
- Triggers Windows setting refresh so accent color can update
- Stores cache under `%LOCALAPPDATA%\WallpaperSync`

## Requirements

- Windows 10 or Windows 11
- PowerShell 7 or Windows PowerShell 5.1
- A valid `WallpaperSync.config.json` file placed next to `WallpaperSync.ps1`

## Files

```text
WallpaperSync.ps1
WallpaperSync.config.json
```

The script expects the config file to be in the same folder as the script.

## Configuration

Create `WallpaperSync.config.json` next to `WallpaperSync.ps1`:

```json
{
  "folders": [
    "E:\\Wallpaper\\GPX2000\\OLED_OK",
    "E:\\Wallpaper\\Wallhaven\\OLED_OK",
    "E:\\Wallpaper\\Other"
  ],
  "extensions": [
    "*.jpg",
    "*.jpeg",
    "*.png",
    "*.webp",
    "*.bmp"
  ]
}
```

### How folder selection works

WallpaperSync does not put every image from every folder into one giant lottery pool.

Instead, it first picks a folder, then picks an image inside that folder. This means each configured folder gets an equal chance, regardless of how many images it contains.

For example:

```text
Folder A: 10 images
Folder B: 500 images
```

With two-level random selection, Folder A and Folder B each have a 50% chance to be picked first. This is useful when you want each wallpaper source or category to appear evenly instead of letting the largest folder dominate everything, because apparently image hoarding should not be rewarded.

## Usage

Run the script manually:

```powershell
pwsh -ExecutionPolicy Bypass -File .\WallpaperSync.ps1
```

Or with Windows PowerShell:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\WallpaperSync.ps1
```

## Execution Policy Note

If Windows blocks the script because it is not digitally signed, you can run it with:

```powershell
pwsh -ExecutionPolicy Bypass -File .\WallpaperSync.ps1
```

This bypasses the execution policy only for that process. It does not permanently change your system policy.

If the file was downloaded from the internet, you may also need:

```powershell
Unblock-File .\WallpaperSync.ps1
```

## Task Scheduler Example

You can run WallpaperSync automatically with Windows Task Scheduler.

Example action:

```text
Program/script:
pwsh.exe

Add arguments:
-ExecutionPolicy Bypass -File "E:\Wallpaper\WallpaperSync.ps1"
```

Suggested triggers:

- At log on
- On workstation unlock
- On a schedule, such as every 30 minutes or every hour

## Cache Location

WallpaperSync stores runtime files here:

```text
%LOCALAPPDATA%\WallpaperSync
```

Generated files:

```text
current_wallpaper.jpg
last.txt
```

`current_wallpaper.jpg` is the cached image applied as the active wallpaper.

`last.txt` stores the last selected source image path so the next run can avoid repeating the same image when possible.

## Wallpaper Style

The script sets the wallpaper style to fill:

```text
WallpaperStyle = 10
TileWallpaper = 0
```

This matches the common Windows desktop background behavior for filling the screen.

## Accent Color Refresh

WallpaperSync uses `SystemParametersInfo(SPI_SETDESKWALLPAPER)` to apply the wallpaper, then broadcasts a Windows settings change message.

It also briefly toggles `ColorPrevalence` and restores it, which helps trigger Windows to redraw personalization-related UI and refresh the accent color when Windows is configured to automatically pick an accent color from the background.

To use this properly, enable this in Windows:

```text
Settings → Personalization → Colors → Accent color → Automatic
```

## Notes

- The script only uses local files.
- It does not download wallpapers.
- It does not delete or modify your original wallpaper images.
- If no valid folder or image is found, the script exits without changing the wallpaper.

## License

MIT License.
