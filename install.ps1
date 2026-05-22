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

    $built = Join-Path $repo 'target\release'
    foreach ($name in 'OpenConsole.exe', 'conpty.dll') {
        $src = Join-Path $built $name
        if (-not (Test-Path $src)) {
            throw "missing $name in $built (build.rs should have placed it there)"
        }
        Copy-Item $src $cargoBin -Force
        $ver = (Get-Item (Join-Path $cargoBin $name)).VersionInfo.FileVersion
        Write-Host "  installed $name $ver -> $cargoBin"
    }
    Write-Host "done." -ForegroundColor Green
} finally {
    Pop-Location
}
