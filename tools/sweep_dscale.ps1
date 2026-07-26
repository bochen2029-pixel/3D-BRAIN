<#
  sweep_dscale.ps1 -- test candidate (ii): does spike-frequency ADAPTATION desynchronize the bursts?
  D_SCALE scales the Izhikevich adaptation jump d (baseline exc d=8->2, inh d=2). D_SCALE>1 => STRONGER
  adaptation => each active neuron self-limits => should break population synchrony. Zero contract change.
    SUCCESS: as D_SCALE rises, Fano DROPS from the bursty baseline toward the 2-20 band WHILE the net
             stays self-sustaining (meanA not collapsed) -> adaptation is the desynchronizer, found cheap.
    FAIL-A:  net goes bursting -> DEAD (meanA~0) with no band in between (adaptation kills, no window).
    FAIL-B:  Fano stays high then dies (adaptation doesn't break synchrony).
  Dose-response on x_we6 (Fano 1178); + x_we3 (Fano-112 floor) & x_we9 (Fano 7004 seizer) for generality.
  Adjudicate: python tools/sweep_report.py d6_ds2 d6_ds3 d6_ds4 d6_ds6 d6_ds8 d3_ds2 d3_ds4 d9_ds4 d9_ds8 x_we3 x_we6 x_we9
  Usage: pwsh C:\3D-BRAIN\tools\sweep_dscale.ps1
#>
param([int]$Seed = 1234, [string]$Root = 'C:\3D-BRAIN')
$ErrorActionPreference = 'Continue'

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath  = & $vswhere -latest -property installationPath
$vcvars  = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found at $vcvars" }
cmd /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
  $i = $_.IndexOf('='); if ($i -gt 0) {
    [System.Environment]::SetEnvironmentVariable($_.Substring(0, $i), $_.Substring($i + 1), 'Process')
  }
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw 'cl.exe not on PATH after vcvars import' }
Write-Host "VS env imported.`n"

$common = @{ W_EXT = '80.0f'; W_MAX = '20.0f'; STD_U = '0.2f'; TAU_REC_MS = '400.0f'; NU_EXT_HZ = '100.0f'; W_INH_INIT = '4.0f' }
$runs = @(
  @{ label = 'd6_ds2'; defs = @{ W_EXC_INIT = '6.0f'; D_SCALE = '2.0f' } }
  @{ label = 'd6_ds3'; defs = @{ W_EXC_INIT = '6.0f'; D_SCALE = '3.0f' } }
  @{ label = 'd6_ds4'; defs = @{ W_EXC_INIT = '6.0f'; D_SCALE = '4.0f' } }
  @{ label = 'd6_ds6'; defs = @{ W_EXC_INIT = '6.0f'; D_SCALE = '6.0f' } }
  @{ label = 'd6_ds8'; defs = @{ W_EXC_INIT = '6.0f'; D_SCALE = '8.0f' } }
  @{ label = 'd3_ds2'; defs = @{ W_EXC_INIT = '3.0f'; D_SCALE = '2.0f' } }
  @{ label = 'd3_ds4'; defs = @{ W_EXC_INIT = '3.0f'; D_SCALE = '4.0f' } }
  @{ label = 'd9_ds4'; defs = @{ W_EXC_INIT = '9.0f'; D_SCALE = '4.0f' } }
  @{ label = 'd9_ds8'; defs = @{ W_EXC_INIT = '9.0f'; D_SCALE = '8.0f' } }
)

$exeDir = Join-Path $Root 'build\sweep'
New-Item -ItemType Directory -Force -Path $exeDir | Out-Null
$src = @("$Root\src\main.cu", "$Root\src\sim.cu", "$Root\src\connectome.cu")

foreach ($run in $runs) {
  $label = $run.label
  Write-Host "==================== $label ===================="
  $dflags = @(); foreach ($k in $common.Keys) { $dflags += "-D$k=$($common[$k])" }
  foreach ($k in $run.defs.Keys) { $dflags += "-D$k=$($run.defs[$k])" }
  Write-Host ("  " + ($dflags -join ' '))
  $exe = Join-Path $exeDir "$label.exe"
  $nvcc = @('-std=c++17', '-O3', '-use_fast_math', '-arch=sm_89', '-cudart', 'static',
            "-I$Root\include", '-Xcompiler=/MT,/O2,/EHsc,/openmp,/nologo') + $dflags + $src + @('-lcurand', '-o', $exe)
  $t0 = [System.Diagnostics.Stopwatch]::StartNew()
  & nvcc @nvcc 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "  BUILD FAILED (nvcc exit $LASTEXITCODE) -- skipping"; continue }
  Write-Host ("  built in {0:n0}s; running..." -f $t0.Elapsed.TotalSeconds)
  $rundir = Join-Path $Root "run\$label"
  New-Item -ItemType Directory -Force -Path $rundir | Out-Null
  Get-ChildItem $rundir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath $exe -ArgumentList "$Seed" -WorkingDirectory $rundir -Wait -NoNewWindow `
    -RedirectStandardOutput (Join-Path $rundir 'sim.log') -RedirectStandardError (Join-Path $rundir 'sim.err')
  Write-Host "  done -> run\$label\activity.csv"
}
Write-Host "`nsweep_dscale complete. Adjudicate:  python C:\3D-BRAIN\tools\sweep_report.py d6_ds2 d6_ds3 d6_ds4 d6_ds6 d6_ds8 d3_ds2 d3_ds4 d9_ds4 d9_ds8 x_we3 x_we6 x_we9"
