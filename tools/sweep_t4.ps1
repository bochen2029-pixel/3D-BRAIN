<#
  sweep_t4.ps1 -- band-vs-void adjudication around t4 (web-instance two-hypothesis test).
  Builds + runs each point (nvcc -D overrides, per-point); NO analyze parse -- adjudicated after by
  tools/sweep_report.py (Fano/CV + m_hat plateau). Pre-registered hypotheses (SESSION_LOG):
    H0 (null): t4 isolated in the Fano void -> no stable asynchronous-irregular regime -> E/I mandate.
    H1: a CLUSTER of moderate-Fano (2-200) points fills in around t4 -> real under-explored band.
  t4 base = {W_EXC=3, W_INH=4, W_EXT=80, NU=100, W_MAX=20, STD_U=0.2, TAU_REC=400}.
    Axis A (recurrence, band-vs-void): W_EXC 3->9 at t4 base   (does Fano climb through a band or jump?)
    Axis C (E/I rescue, the mechanism test): W_INH up at seizing W_EXC=9  (does inhibition open a band?)
    Axis B (drive): NU 50/150 at W_EXC=4.
  Usage: pwsh C:\3D-BRAIN\tools\sweep_t4.ps1
#>
param([int]$Seed = 1234, [string]$Root = 'C:\3D-BRAIN')
$ErrorActionPreference = 'Continue'

# import VS Developer env so raw nvcc finds cl.exe + headers
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
Write-Host "VS env imported: $((Get-Command cl.exe).Source)`n"

$common = @{ W_EXT = '80.0f'; W_MAX = '20.0f'; STD_U = '0.2f'; TAU_REC_MS = '400.0f' }
$runs = @(
  @{ label = 'x_we3';       defs = @{ W_EXC_INIT = '3.0f'; W_INH_INIT = '4.0f';  NU_EXT_HZ = '100.0f' } }  # t4 replica (anchor)
  @{ label = 'x_we4';       defs = @{ W_EXC_INIT = '4.0f'; W_INH_INIT = '4.0f';  NU_EXT_HZ = '100.0f' } }
  @{ label = 'x_we5';       defs = @{ W_EXC_INIT = '5.0f'; W_INH_INIT = '4.0f';  NU_EXT_HZ = '100.0f' } }
  @{ label = 'x_we6';       defs = @{ W_EXC_INIT = '6.0f'; W_INH_INIT = '4.0f';  NU_EXT_HZ = '100.0f' } }
  @{ label = 'x_we9';       defs = @{ W_EXC_INIT = '9.0f'; W_INH_INIT = '4.0f';  NU_EXT_HZ = '100.0f' } }  # seizing anchor
  @{ label = 'x_we9_wi10';  defs = @{ W_EXC_INIT = '9.0f'; W_INH_INIT = '10.0f'; NU_EXT_HZ = '100.0f' } }  # E/I rescue
  @{ label = 'x_we9_wi16';  defs = @{ W_EXC_INIT = '9.0f'; W_INH_INIT = '16.0f'; NU_EXT_HZ = '100.0f' } }
  @{ label = 'x_we4_nu50';  defs = @{ W_EXC_INIT = '4.0f'; W_INH_INIT = '4.0f';  NU_EXT_HZ = '50.0f'  } }
  @{ label = 'x_we4_nu150'; defs = @{ W_EXC_INIT = '4.0f'; W_INH_INIT = '4.0f';  NU_EXT_HZ = '150.0f' } }
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
Write-Host "`nsweep_t4 complete. Adjudicate:  python C:\3D-BRAIN\tools\sweep_report.py"
