#!/usr/bin/env pwsh
# One-shot install for this WezTerm fork.
#
# `cargo install` only copies the binary it builds, but wezterm-gui depends
# on a sideloaded conpty.dll + OpenConsole.exe to dodge the Win11 23H2
# system-conhost crash (wezterm/wezterm#7520, #7774). build.rs already
# stages those alongside the .exe under target/release/, so this script
# just runs cargo install and then copies the ConPTY pair to ~/.cargo/bin
# next to the freshly installed wezterm-gui.exe.
#
# Why this is safe again (it wasn't between 2026-05-23 morning and the
# kitty-ESC fix on branch ad4c3cac-kitty-esc-fix): v1.24.260X conpty.dll
# has an input-side cache-instead-of-flush regression that strands lone
# `\x1b` bytes once win32-input-mode has been observed by OpenConsole.
# Wezterm WAS sending bare `\x1b` for the ESC key in violation of the
# kitty spec, triggering the regression and breaking ESC in zellij. The
# kitty-ESC fix on the rutger/main lineage makes wezterm emit ESC as
# `\x1b[27;1u` per spec, so the regression never trips. Now the sideload
# is safe.
# Full writeup:
#   C:/Projects/foam/learnings/learning-2026-05-23-wezterm-conpty-v1.24-esc-regression.md
#
# Idempotent. Re-run after any pull / asset bump.

$ErrorActionPreference = 'Stop'
$repo     = $PSScriptRoot
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'

# openssl-sys builds OpenSSL from source via `perl Configure`. The MSYS
# perl shipped with Git for Windows is missing Locale::Maketext::Simple,
# so the build fails. Strawberry Perl has the full CPAN stack — put it
# first on PATH for the duration of this script.
$env:PATH = "C:\Strawberry\perl\bin;$env:PATH"

Push-Location $repo
try {
    cargo install --path wezterm-gui --bin wezterm-gui --force
    if ($LASTEXITCODE -ne 0) { throw "cargo install failed (exit $LASTEXITCODE)" }
    cargo install --path wezterm --bin wezterm --force
    if ($LASTEXITCODE -ne 0) { throw "cargo install failed (exit $LASTEXITCODE)" }

    $built = Join-Path $repo 'target\release'
    # If a running wezterm-gui has already LoadLibrary'd these from
    # $cargoBin, the file is held open and Copy-Item -Force will fail.
    # Skip the copy when the destination is already at the wanted version.
    foreach ($name in 'OpenConsole.exe', 'conpty.dll') {
        $src = Join-Path $built $name
        $dst = Join-Path $cargoBin $name
        if (-not (Test-Path $src)) {
            throw "missing $name in $built (build.rs should have placed it there)"
        }
        $srcVer = (Get-Item $src).VersionInfo.FileVersion
        $dstVer = if (Test-Path $dst) { (Get-Item $dst).VersionInfo.FileVersion } else { $null }
        if ($dstVer -eq $srcVer) {
            Write-Host "  $name $dstVer already in $cargoBin (skip)"
            continue
        }
        try {
            Copy-Item $src $dst -Force -ErrorAction Stop
            Write-Host "  installed $name $srcVer -> $cargoBin (was $dstVer)"
        } catch {
            Write-Warning "could not overwrite $dst (likely held by a running process). Close any wezterm/zellij and re-run, or accept current $dstVer."
        }
    }
    Write-Host "done." -ForegroundColor Green
} finally {
    Pop-Location
}
