<#
  sweep_headroom.ps1 -- Session 4, Step 4: give BOTH controllers headroom simultaneously.

  g_we5_nu5 is the best point found: Fano 3.5, m_hat FLAT(0.008) at 0.980 across bins 3-10,
  CV_ISI 0.85, pairwise r ~ 0, per-neuron Fano 1.007, 99.2% recurrent, rate 3.4 Hz against a
  3.0 Hz target. But its [ctrl] readout shows the two controllers in OPPOSITE states:
      gain  0.614, railed lo 29.4%          -> has authority (fixed by sweep_gain)
      w_inh 59.284 of cap 60.000            -> still pinned at the ceiling
  So iSTDP is saturated: the network wants more inhibition than W_MAX permits. Gate B's
  "held by >=2 controllers on separated timescales" is still only half met.

  This raises the inhibitory ceiling so iSTDP has somewhere to go, and pairs it with the
  widened gain floor. Expectation if the picture is right: w_inh settles BELOW the new cap,
  rate lands on RHO0, and both controllers sit mid-range.

  PRE-REGISTERED: success = w_inh mean comfortably under W_MAX AND gain railed_lo well under
  ~20%, while Fano stays 2-20, the m_hat plateau stays FLAT near 0.98, and the point stays
  self-sustaining. FAILURE MODES to report honestly rather than tune around:
    (a) w_inh rises to whatever cap is offered (unbounded) -> iSTDP has no equilibrium here and
        the rate target is unreachable by inhibition alone;
    (b) the extra inhibition kills the AI state (Fano -> 1, m_hat -> 0, Poisson floor).

  Usage: pwsh C:\3D-BRAIN\tools\sweep_headroom.ps1
  Then:  python tools\sweep_report.py h_wm120 h_wm120_gmin01 h_wm200_gmin01 g_we5_nu5
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

# g_we5_nu5 base: the flat-plateau, 99.2%-recurrent point
$common = @{ W_EXT='80.0f'; STD_U='0.2f'; TAU_REC_MS='400.0f'; W_INH_INIT='4.0f';
             ISTDP_ETA='0.2f'; W_EXC_INIT='5.0f'; NU_EXT_HZ='5.0f' }
$runs = @(
  @{ label='h_wm120';        defs=@{ W_MAX='120.0f' } }
  @{ label='h_wm120_gmin01'; defs=@{ W_MAX='120.0f'; GAIN_MIN='0.1f' } }
  @{ label='h_wm200_gmin01'; defs=@{ W_MAX='200.0f'; GAIN_MIN='0.1f' } }
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
Write-Host "`nsweep_headroom complete. Adjudicate:"
Write-Host "  python C:\3D-BRAIN\tools\sweep_report.py h_wm120 h_wm120_gmin01 h_wm200_gmin01 g_we5_nu5"
