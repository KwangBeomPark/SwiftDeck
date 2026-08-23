param(
    [switch]$Publish
)

# SwiftDeck build, packaging, and optional GitHub Release publishing pipeline.
# Publishing is opt-in so a local build can never modify GitHub by accident.
$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
Push-Location $repoRoot
try {
    $ahkPath = Join-Path $repoRoot "src\SwiftDeck.ahk"
    if (-not (Test-Path -LiteralPath $ahkPath)) {
        throw "Could not find src/SwiftDeck.ahk"
    }

    $ahkContent = Get-Content -LiteralPath $ahkPath -Raw
    if ($ahkContent -notmatch 'global g_appVersion\s*:=\s*"([^"]+)"') {
        throw "Could not find g_appVersion in the script."
    }
    $version = $Matches[1]
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "g_appVersion must use X.Y.Z format."
    }
    if ($ahkContent -notmatch ';@Ahk2Exe-SetVersion\s+(\d+\.\d+\.\d+\.\d+)') {
        throw "Could not find the Ahk2Exe file version directive."
    }
    $fileVersion = $Matches[1]
    if ($fileVersion -ne "$version.0") {
        throw "g_appVersion ($version) and file version ($fileVersion) do not match."
    }

    $compilerPath = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
    $baseAhk = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    $iconPath = Join-Path $repoRoot "assets\SwiftDeck.ico"
    foreach ($requiredPath in @($compilerPath, $baseAhk, $iconPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Required build dependency was not found: $requiredPath"
        }
    }

    $releaseDir = Join-Path $repoRoot "release"
    $distDir = Join-Path $repoRoot "dist"
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null

    $releaseExe = Join-Path $releaseDir "SwiftDeck.exe"
    $releaseZip = Join-Path $releaseDir "SwiftDeck.zip"
    $releaseManifest = Join-Path $releaseDir "SwiftDeck.update.ini"
    $localVersionedExe = Join-Path $distDir "SwiftDeck.v$version.exe"
    foreach ($ownedOutput in @($releaseExe, $releaseZip, $releaseManifest, $localVersionedExe)) {
        if (Test-Path -LiteralPath $ownedOutput) {
            Remove-Item -LiteralPath $ownedOutput -Force
        }
    }

    Write-Host "Building SwiftDeck v$version..."
    $compile = Start-Process -FilePath $compilerPath -ArgumentList @(
        "/in", "`"$ahkPath`"",
        "/out", "`"$releaseExe`"",
        "/icon", "`"$iconPath`"",
        "/base", "`"$baseAhk`""
    ) -Wait -PassThru
    if ($compile.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $releaseExe)) {
        throw "Ahk2Exe compilation failed with exit code $($compile.ExitCode)."
    }

    Compress-Archive -LiteralPath $releaseExe -DestinationPath $releaseZip -CompressionLevel Optimal
    Copy-Item -LiteralPath $releaseExe -Destination $localVersionedExe -Force

    $releaseHash = (Get-FileHash -LiteralPath $releaseExe -Algorithm SHA256).Hash.ToUpperInvariant()
    $releaseSize = (Get-Item -LiteralPath $releaseExe).Length
    $manifestLines = @(
        "[Release]",
        "Version=$version",
        "Asset=SwiftDeck.exe",
        "Sha256=$releaseHash",
        "Size=$releaseSize"
    )
    Set-Content -LiteralPath $releaseManifest -Value $manifestLines -Encoding utf8

    Write-Host "Build completed:"
    Get-Item -LiteralPath $releaseExe, $releaseZip, $releaseManifest, $localVersionedExe |
        Select-Object FullName, Length
    Write-Host "SHA256: $releaseHash"

    if ($Publish) {
        Write-Host "Publishing GitHub Release v$version..."
        & gh auth status | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI is not authenticated."
        }

        & gh release view "v$version" *> $null
        if ($LASTEXITCODE -eq 0) {
            throw "Release v$version already exists. Published releases are never replaced."
        }

        $gitStatus = & git status --porcelain
        if ($gitStatus) {
            throw "The Git worktree must be clean before publishing a release."
        }
        & git fetch origin main | Out-Null
        $localHead = (& git rev-parse HEAD).Trim()
        $remoteHead = (& git rev-parse origin/main).Trim()
        if ($localHead -ne $remoteHead) {
            throw "Local main and origin/main must match before publishing."
        }

        & gh release create "v$version" $releaseExe $releaseZip $releaseManifest `
            --draft --target main --title "SwiftDeck v$version" --generate-notes
        if ($LASTEXITCODE -ne 0) {
            throw "Could not create the draft GitHub Release."
        }

        & gh release edit "v$version" --draft=false --latest
        if ($LASTEXITCODE -ne 0) {
            throw "Could not publish GitHub Release v$version."
        }
        Write-Host "Published GitHub Release v$version."
    }
} finally {
    Pop-Location
}
