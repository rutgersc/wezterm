# Kill WezTerm and copy the freshly built binaries.
# Must be run from OUTSIDE WezTerm.
$dest = "$env:USERPROFILE\.cargo\bin"
$src  = "$PSScriptRoot\target\release"

$bins = @("wezterm.exe", "wezterm-gui.exe")

foreach ($bin in $bins) {
    if (-not (Test-Path "$src\$bin")) {
        Write-Error "No release build found at $src\$bin. Run 'cargo build --release' first."
        exit 1
    }
}

Write-Host "Stopping WezTerm processes..."
Get-Process -Name wezterm-gui, wezterm -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$remaining = Get-Process -Name wezterm-gui, wezterm -ErrorAction SilentlyContinue
if ($remaining) {
    Write-Error "Could not kill all WezTerm processes. Run this from outside WezTerm."
    exit 1
}

foreach ($bin in $bins) {
    Write-Host "Copying $src\$bin -> $dest\$bin"
    Copy-Item -Path "$src\$bin" -Destination "$dest\$bin" -Force
}

Write-Host "Done."
