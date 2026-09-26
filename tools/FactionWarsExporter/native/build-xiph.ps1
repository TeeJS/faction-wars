# Builds fwxiph.dll: libogg 1.3.6, libvorbis 1.3.7 and libtheora 1.2.0 (their
# encoders), from the unmodified sources vendored in xiph\ (fetched from
# downloads.xiph.org on 2026-09-26, each .tar.gz checked against Xiph's own
# SHA256SUMS), with the Microsoft C compiler of any installed Visual Studio or
# Build Tools. The movies export (Movies.cs) needs it; build.ps1 runs this,
# signs the DLL and builds it into the exe.
#
#   .\tools\FactionWarsExporter\native\build-xiph.ps1          -> native\bin\fwxiph.dll
#
# The CRT is linked in (/MT), so the DLL needs no Visual C++ runtime installed.
# The session's environment is restored afterwards.

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$src = Join-Path $here 'xiph'
$out = Join-Path $here 'bin'
$obj = Join-Path $here 'obj'

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw 'No Visual Studio installer found: install the Visual Studio Build Tools with "Desktop development with C++".' }
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'No Visual Studio with the C++ x64 tools found: add "Desktop development with C++" to the Build Tools.' }

$saved = @{}
Get-ChildItem env: | ForEach-Object { $saved[$_.Name] = $_.Value }
try {
    $env:PATH = "$(Split-Path $vswhere);$env:PATH"   # the dev shell looks for vswhere itself
    & (Join-Path $vs 'Common7\Tools\Launch-VsDevShell.ps1') -Arch amd64 -HostArch amd64 -SkipAutomaticLocation | Out-Null
    Remove-Item -Recurse -Force $obj -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $out, "$obj\ogg", "$obj\vorbis", "$obj\theora" | Out-Null

    $inc = @('/I', "$src\libogg\include", '/I', "$src\libvorbis\include", '/I', "$src\libvorbis\lib", '/I', "$src\libtheora\include")
    $flags = @('/nologo', '/c', '/O2', '/MT', '/W1', '/Brepro', '/D_CRT_SECURE_NO_WARNINGS') + $inc
    $sets = @(
        @('ogg', (Get-ChildItem "$src\libogg\src\*.c")),
        @('vorbis', (Get-ChildItem "$src\libvorbis\lib\*.c")),
        @('theora', (Get-ChildItem "$src\libtheora\lib\*.c"))
    )
    foreach ($s in $sets) {
        $files = $s[1] | ForEach-Object { $_.FullName }
        & cl.exe @flags "/Fo$obj\$($s[0])\" @files | Where-Object { $_ -and $_ -notmatch '^(\S+\.c|Compiling\.\.\.|Generating Code\.\.\.)$' }
        if ($LASTEXITCODE -ne 0) { throw "Compiling $($s[0]) failed." }
    }
    $objs = Get-ChildItem "$obj\*\*.obj" | ForEach-Object { $_.FullName }
    & link.exe /nologo /DLL /Brepro /OPT:REF "/DEF:$here\fwxiph.def" "/OUT:$out\fwxiph.dll" @objs | Where-Object { $_ -and $_ -notmatch 'Creating library' }
    if ($LASTEXITCODE -ne 0) { throw 'Linking fwxiph.dll failed.' }
    Remove-Item "$out\fwxiph.lib", "$out\fwxiph.exp" -ErrorAction SilentlyContinue
}
finally {
    Get-ChildItem env: | Where-Object { -not $saved.ContainsKey($_.Name) } | ForEach-Object { Remove-Item "env:$($_.Name)" }
    foreach ($k in $saved.Keys) { Set-Item "env:$k" $saved[$k] }
}
$dll = Get-Item "$out\fwxiph.dll"
Write-Host ("fwxiph.dll: {0:N0} bytes, SHA-256 {1}" -f $dll.Length, (Get-FileHash $dll -Algorithm SHA256).Hash)
