<#
  sweep_b8.ps1 -- the B8 robustness clause (MODULE.md §5, added 2026-07-26).

  B8: under a SUSTAINED +/-2% perturbation of the excitatory drive applied to the inhibitory
  population, the certified point must still satisfy B1-B6 at steady state. A regime that exists
  only at exactly one E/I operating point is TUNED, not stable -- and B1-B7 structurally cannot
  see the difference, because every one of them is a time-average of a single unperturbed run.

  Why the clause exists: the perturbation probe found that an injection of 2% of the excitatory
  drive onto I collapsed the excitatory population below a tenth of its baseline in 26% of trials,
  at a point that had passed all of B1-B7. The battery certified a fragile network.

  Why B8 re-applies B1-B6 rather than setting a depth-of-dip threshold: the measured dip
  distribution is CONTINUOUS (control median 0.83, inj=0.1 median 0.38, inj=0.3 median 0.015), so
  any threshold decides the verdict by where it is placed. Reusing the already-agreed clauses
  introduces no new free parameter.

  Design: the perturbation runs CONTINUOUSLY from t=10 s to the end of a 100 s run, which is
  exactly the window analyze.py analyses (it drops the first 10%). So the scorecard produced is
  the steady state OF THE PERTURBED NETWORK, after the homeostats have had ~90 s to absorb it --
  which is the fair test, since absorbing perturbations is what the five-layer stack is for.

  PRE-REGISTERED: B8 PASSES iff B1-B6 hold in BOTH directions. B7 is excluded by construction --
  the controllers are expected to move in order to absorb the perturbation.
  A pass means the certified regime is a basin, not a point. A fail means Gate B certified a tuned
  operating point, and the correct response is to report that, not to shrink the perturbation.

  Usage: pwsh C:\3D-BRAIN\tools\sweep_b8.ps1
  Then:  python tools\analyze.py run\b8_plus ; python tools\analyze.py run\b8_minus
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

# certified point. Perturbation from t=10 s to t=100 s (one 'trial' spanning the rest of the run).
# +/-0.1 against the measured excitatory drive of 5.042 mV/ms = +/-2.0%.
$common = @{ W_EXT='80.0f'; STD_U='0.2f'; TAU_REC_MS='400.0f'; W_INH_INIT='4.0f'; W_MAX='200.0f';
             ISTDP_ETA='0.2f'; W_EXC_INIT='5.0f'; NU_EXT_HZ='5.0f'; GAIN_MIN='0.1f';
             N_STEPS='1000000'; PARADOX_START='100000'; PARADOX_LEN='900000';
             PARADOX_PERIOD='900000'; PARADOX_TRIALS='1';
             DUMP_START='900000'; DUMP_LEN='80000' }
$runs = @(
  @{ label='b8_plus';  defs=@{ PARADOX_INJ='0.1f'  } }   # +2% onto the inhibitory population
  @{ label='b8_minus'; defs=@{ PARADOX_INJ='-0.1f' } }   # -2%
)

$exeDir = Join-Path $Root 'build\sweep'
New-Item -ItemType Directory -Force -Path $exeDir | Out-Null
$src = @("$Root\src\main.cu", "$Root\src\sim.cu", "$Root\src\connectome.cu")

foreach ($run in $runs) {
  $label = $run.label
  Write-Host "==================== $label  (PARADOX_INJ=$($run.defs['PARADOX_INJ'])) ===================="
  $dflags = @(); foreach ($k in $common.Keys) { $dflags += "-D$k=$($common[$k])" }
  foreach ($k in $run.defs.Keys) { $dflags += "-D$k=$($run.defs[$k])" }
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
  foreach ($line in (Select-String -Path (Join-Path $rundir 'sim.log') -Pattern '\[ctrl final|\[spikedump' -ErrorAction SilentlyContinue)) {
    Write-Host ("  " + $line.Line)
  }
  Write-Host "  done -> run\$label\"
}
Write-Host "`nsweep_b8 complete. Adjudicate:"
Write-Host "  python C:\3D-BRAIN\tools\analyze.py run\b8_plus"
Write-Host "  python C:\3D-BRAIN\tools\analyze.py run\b8_minus"
