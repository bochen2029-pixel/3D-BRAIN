<#
  sweep_isn.ps1 -- the ISN paradoxical-effect test, properly powered this time.

  FINAL_BLUEPRINT §7.4 requires "paradoxical-effect-positive" -- the defining signature of an
  inhibition-stabilized network: inject extra EXCITATORY current into the INHIBITORY population
  and their steady-state rate FALLS, because the resulting drop in E withdraws more excitation
  from I than was injected. Gate B B1-B8 does not cover it, and it is the one blueprint clause
  that can FALSIFY a claim this project has been making implicitly rather than corroborate it.

  WHY THE PREVIOUS ATTEMPT WAS INCONCLUSIVE (run/r_inj*, kept as the record): with 20 trials the
  paired SEM was +-0.3-0.6 Hz -- as large as any perturbation small enough to stay in the linear
  regime. Power scales as 1/sqrt(n), so ~10x the trials is needed. That was blocked because
  splitting E from I needed a full spike dump, and 200 trials' worth is ~40M rows.
  UNBLOCKED by the new RATEDUMP_* E/I-split activity trace: two ints per step instead of every
  spike, ~4 orders of magnitude smaller, and no brain.h change.

  Design: 200 trials, 100 ms injection every 300 ms, over 60 s of settled network (t=40-100 s).
  Each trial is compared against its OWN immediately preceding baseline (paired), so the slow
  population wandering that defeated the first attempt is differenced out.

  PRE-REGISTERED:
    ISN     -> inhibitory rate FALLS (paired mean < 0, |z| >= 2 against the INJ=0 control).
    non-ISN -> inhibitory rate RISES roughly in proportion to the injection.
    Any trial whose excitatory rate collapses below half its baseline is VOIDED, not averaged --
    a linear-response property cannot be measured in a network knocked out of its regime.
  If the control's own paired delta is not ~0, the design is broken and nothing else is readable.

  Usage: pwsh C:\3D-BRAIN\tools\sweep_isn.ps1   then   python tools\isn.py
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

# certified point; injection trials over t = 40-100 s, E/I trace over the same window
$common = @('-std=c++17','-O3','-use_fast_math','-arch=sm_89','-cudart','static',"-I$Root\include",
            '-Xcompiler=/MT,/O2,/EHsc,/openmp,/nologo',
            '-DW_EXT=80.0f','-DSTD_U=0.2f','-DTAU_REC_MS=400.0f','-DW_INH_INIT=4.0f','-DW_MAX=200.0f',
            '-DISTDP_ETA=0.2f','-DW_EXC_INIT=5.0f','-DNU_EXT_HZ=5.0f','-DGAIN_MIN=0.1f',
            '-DN_STEPS=1000000',
            '-DPARADOX_START=400000','-DPARADOX_LEN=1000','-DPARADOX_PERIOD=3000','-DPARADOX_TRIALS=200',
            '-DRATEDUMP_START=400000','-DRATEDUMP_LEN=600000')
$src = @("$Root\src\main.cu", "$Root\src\sim.cu", "$Root\src\connectome.cu")
$runs = @(
  @{ label='i_inj0';    inj='0.0f'  }   # control -- the paired-delta floor
  @{ label='i_inj0p05'; inj='0.05f' }   # ~1% of the excitatory drive onto I
  @{ label='i_inj0p15'; inj='0.15f' }   # ~3%
)

foreach ($r in $runs) {
  Write-Host "==================== $($r.label)  (PARADOX_INJ=$($r.inj)) ===================="
  $exe = "$Root\build\sweep\$($r.label).exe"
  $a = $common + @("-DPARADOX_INJ=$($r.inj)") + $src + @('-lcurand','-o',$exe)
  & nvcc @a 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "  BUILD FAILED -- skipping"; continue }
  $rundir = Join-Path $Root "run\$($r.label)"
  New-Item -ItemType Directory -Force -Path $rundir | Out-Null
  Start-Process -FilePath $exe -ArgumentList "$Seed" -WorkingDirectory $rundir -Wait -NoNewWindow `
    -RedirectStandardOutput (Join-Path $rundir 'sim.log') -RedirectStandardError (Join-Path $rundir 'sim.err')
  foreach ($line in (Select-String -Path (Join-Path $rundir 'sim.log') -Pattern '\[timing\]|\[eirate\]|\[ctrl final' -ErrorAction SilentlyContinue)) {
    Write-Host ("  " + ($line.Line -replace '\s+',' ').Trim())
  }
}
Write-Host "`nsweep_isn complete. Adjudicate:  python C:\3D-BRAIN\tools\isn.py"
