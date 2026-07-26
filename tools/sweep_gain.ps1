<#
  sweep_gain.ps1 -- Session 4, Step 3: give the SLOW controller authority back.

  The AI battery certifies e_w9_eta200 / k_w9e200_nu5 as a genuine asynchronous-irregular,
  self-sustaining point. But its [ctrl] readout still shows `gain 0.508 (railed lo 88.2%)`:
  the slow per-neuron gain controller is pinned at GAIN_MIN on ~9 of every 10 neurons. So the
  operating point is being held by iSTDP essentially alone, which does NOT satisfy Gate B's
  "held by >=2 controllers on separated timescales" (MODULE.md §5). A regime held by one
  saturated controller is a tuned point, not a self-organised one.

  Diagnosis: W_EXC=9 gives a unitary PSP of 45.5 mV against a ~20 mV rest->threshold gap --
  a single presynaptic spike is suprathreshold. The gain controller rails at 0.5 trying to
  divide that down and still cannot reach its target. Two independent fixes:
    axis A -- lower W_EXC so gain can sit mid-range (no config change),
    axis B -- widen the gain floor (GAIN_MIN, newly #ifndef-guarded in config.h; defaults unchanged).

  PRE-REGISTERED: success = a point that keeps Fano in 2-20, CV_ISI ~ 1 and pairwise r ~ 0
  while gain sits OFF both rails (railed_lo well under ~20%) -- i.e. both controllers actively
  regulating on separated timescales. If lowering W_EXC drops the network to the Poisson floor
  (m_hat -> 0 at all bins) instead, report that: the AI state would then depend on strong
  recurrence that only iSTDP can hold, and the two-controller requirement stays unmet.

  Usage: pwsh C:\3D-BRAIN\tools\sweep_gain.ps1
  Then:  python tools\sweep_report.py g_we5 g_we4 g_we3 g_we5_gmin01 g_we9_gmin01 g_we5_nu5
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
Write-Host "VS env imported`n"

$common = @{ W_EXT='80.0f'; STD_U='0.2f'; TAU_REC_MS='400.0f'; W_INH_INIT='4.0f'; W_MAX='60.0f'; ISTDP_ETA='0.2f' }
$runs = @(
  # axis A -- lower recurrent weight so the gain controller can sit mid-range
  @{ label='g_we5';        defs=@{ W_EXC_INIT='5.0f'; NU_EXT_HZ='100.0f' } }
  @{ label='g_we4';        defs=@{ W_EXC_INIT='4.0f'; NU_EXT_HZ='100.0f' } }
  @{ label='g_we3';        defs=@{ W_EXC_INIT='3.0f'; NU_EXT_HZ='100.0f' } }
  # axis B -- widen the gain floor instead
  @{ label='g_we5_gmin01'; defs=@{ W_EXC_INIT='5.0f'; NU_EXT_HZ='100.0f'; GAIN_MIN='0.1f' } }
  @{ label='g_we9_gmin01'; defs=@{ W_EXC_INIT='9.0f'; NU_EXT_HZ='100.0f'; GAIN_MIN='0.1f' } }
  # drive-independence check on the best axis-A candidate
  @{ label='g_we5_nu5';    defs=@{ W_EXC_INIT='5.0f'; NU_EXT_HZ='5.0f'   } }
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
  $nvcc = @('-std=c++17','-O3','-use_fast_math','-arch=sm_89','-cudart','static',
            "-I$Root\include",'-Xcompiler=/MT,/O2,/EHsc,/openmp,/nologo') + $dflags + $src + @('-lcurand','-o',$exe)
  & nvcc @nvcc 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "  BUILD FAILED -- skipping"; continue }
  $rundir = Join-Path $Root "run\$label"
  New-Item -ItemType Directory -Force -Path $rundir | Out-Null
  Get-ChildItem $rundir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath $exe -ArgumentList "$Seed" -WorkingDirectory $rundir -Wait -NoNewWindow `
    -RedirectStandardOutput (Join-Path $rundir 'sim.log') -RedirectStandardError (Join-Path $rundir 'sim.err')
  foreach ($line in (Select-String -Path (Join-Path $rundir 'sim.log') -Pattern '\[ctrl final' -ErrorAction SilentlyContinue)) {
    Write-Host ("  " + $line.Line)
  }
  Write-Host "  done -> run\$label\activity.csv"
}
Write-Host "`nsweep_gain complete. Adjudicate:"
Write-Host "  python C:\3D-BRAIN\tools\sweep_report.py g_we5 g_we4 g_we3 g_we5_gmin01 g_we9_gmin01 g_we5_nu5"
