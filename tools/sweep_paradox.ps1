<#
  sweep_paradox.ps1 -- the ISN paradoxical-effect test (FINAL_BLUEPRINT §7.4).

  The blueprint's acceptance battery demands "paradoxical-effect-positive" as the signature of
  an inhibition-stabilized network. Gate B B1-B7 does not cover it, and unlike every other clause
  it is a FALSIFICATION test rather than a corroboration: the whole session has implicitly claimed
  an ISN regime (recurrent excitation strong enough to be self-amplifying, held by inhibition),
  and this is the measurement that can say no.

  Inject extra excitatory current into the INHIBITORY population only, for 2 s, at the certified
  operating point. Spike dump spans 1 s before, the 2 s injection, and 1 s after, so the E and I
  rates can be split out at full time resolution from neurons.csv's is_inh column.

  TWO CORRECTIONS FROM A FIRST ATTEMPT (p_inj*, kept in run/ as the record):
   1. AMPLITUDE. Injecting 1.5 and 4.0 drove the excitatory population from 3.4 Hz to 0.003 Hz.
      With E silenced the network is in a different regime entirely, the inhibitory rate simply
      tracks the injected current, and the result says nothing about whether the UNPERTURBED
      network is inhibition-stabilized. The paradoxical effect is a LINEAR-RESPONSE property --
      the perturbation must be small enough to leave the operating point intact. Amplitudes are
      now 0.1/0.3/1.0 against an excitatory drive onto I of ~4.7, i.e. ~2-20%. tools/paradox.py
      voids any point whose exc rate falls below half of baseline.
   2. BASELINE. Injecting at t=20 s of a 30 s run gave a control that drifted -19% on its own,
      because the slow controller had not converged. Injection now happens at t=70 s of a 100 s
      run, past the settling shown in the certification trace.

  PRE-REGISTERED (locked before data):
    ISN     -> inhibitory rate FALLS during injection (paradoxical), E rate falls slightly too.
    non-ISN -> inhibitory rate RISES roughly in proportion to the injected current.
    Amplitude dependence should be monotonic. A sign flip across amplitudes means the network sits
    near the ISN boundary and the claim is amplitude-dependent -- report that as the partial it is
    rather than quoting whichever amplitude gives the wanted sign.
  The control (INJ=0) measures the residual drift floor any effect must clear.

  Injection window is deliberately SHORT (2 s): the paradoxical effect is a fast network effect,
  and over tens of seconds iSTDP and the gain controller re-equilibrate it away.

  Usage: pwsh C:\3D-BRAIN\tools\sweep_paradox.ps1   then   python tools\paradox.py
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

# certified operating point; 100 s run, inject at t = 70-72 s, dump t = 69-73 s
$common = @{ W_EXT='80.0f'; STD_U='0.2f'; TAU_REC_MS='400.0f'; W_INH_INIT='4.0f'; W_MAX='200.0f';
             ISTDP_ETA='0.2f'; W_EXC_INIT='5.0f'; NU_EXT_HZ='5.0f'; GAIN_MIN='0.1f';
             N_STEPS='1000000'; PARADOX_START='600000'; PARADOX_LEN='2000';
             PARADOX_PERIOD='10000'; PARADOX_TRIALS='20';
             DUMP_START='595000'; DUMP_LEN='205000' }
$runs = @(
  @{ label='r_inj0';   defs=@{ PARADOX_INJ='0.0f' } }   # control -- measures the fluctuation floor
  @{ label='r_inj0p1'; defs=@{ PARADOX_INJ='0.1f' } }
  @{ label='r_inj0p3'; defs=@{ PARADOX_INJ='0.3f' } }
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
Write-Host "`nsweep_paradox complete. Adjudicate:  python C:\3D-BRAIN\tools\paradox.py"


