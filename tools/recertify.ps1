<#
  recertify.ps1 -- re-run the full Gate B battery after the 2026-07-27 brain.h amendment.

  The amendment removed the stored per-neuron RNG state and regenerates the external-drive Philox
  stream from (seed, neuron, step). That CHANGES THE RANDOM STREAM, so every previously certified
  result is now a different realisation of the same operating point. The regime should be
  unaffected -- it held across 4 seeds and a 20x GAIN_ETA band -- but "should" is not a
  measurement, and a contract change that silently invalidated the certification would be the
  worst possible outcome to discover later.

  Runs: the certified point on 3 seeds (satisfying MODULE.md 5's >=3-seed clause) plus both B8
  perturbation directions. All 100 s (N_STEPS=1e6) per the run-length clause, all with a spike
  dump over t=90-98 s so B4/B5 are measurable.

  Usage: pwsh C:\3D-BRAIN\tools\recertify.ps1
  Then:  python tools\analyze.py run\V_s1234 ; ... (or --append to log each)
#>
param([string]$Root = 'C:\3D-BRAIN')
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

$common = @('-std=c++17','-O3','-use_fast_math','-arch=sm_89','-cudart','static',"-I$Root\include",
            '-Xcompiler=/MT,/O2,/EHsc,/openmp,/nologo',
            '-DW_EXT=80.0f','-DSTD_U=0.2f','-DTAU_REC_MS=400.0f','-DW_INH_INIT=4.0f','-DW_MAX=200.0f',
            '-DISTDP_ETA=0.2f','-DW_EXC_INIT=5.0f','-DNU_EXT_HZ=5.0f','-DGAIN_MIN=0.1f',
            '-DN_STEPS=1000000','-DDUMP_START=900000','-DDUMP_LEN=80000')
$src = @("$Root\src\main.cu", "$Root\src\sim.cu", "$Root\src\connectome.cu")

# unperturbed binary (3 seeds) + the two B8 directions
$builds = @(
  @{ exe='V_cert'; defs=@() }
  @{ exe='V_b8p';  defs=@('-DPARADOX_INJ=0.1f','-DPARADOX_START=100000','-DPARADOX_LEN=900000','-DPARADOX_PERIOD=900000','-DPARADOX_TRIALS=1') }
  @{ exe='V_b8m';  defs=@('-DPARADOX_INJ=-0.1f','-DPARADOX_START=100000','-DPARADOX_LEN=900000','-DPARADOX_PERIOD=900000','-DPARADOX_TRIALS=1') }
)
foreach ($b in $builds) {
  $a = $common + $b.defs + $src + @('-lcurand','-o',"$Root\build\sweep\$($b.exe).exe")
  & nvcc @a 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "BUILD FAILED: $($b.exe)" }
  Write-Host "built $($b.exe)"
}

$jobs = @(
  @{ label='V_s1234'; exe='V_cert'; seed=1234 }
  @{ label='V_s7';    exe='V_cert'; seed=7    }
  @{ label='V_s99';   exe='V_cert'; seed=99   }
  @{ label='V_b8p';   exe='V_b8p';  seed=1234 }
  @{ label='V_b8m';   exe='V_b8m';  seed=1234 }
)
foreach ($j in $jobs) {
  Write-Host "==================== $($j.label)  (seed $($j.seed)) ===================="
  $rundir = Join-Path $Root "run\$($j.label)"
  New-Item -ItemType Directory -Force -Path $rundir | Out-Null
  Start-Process -FilePath "$Root\build\sweep\$($j.exe).exe" -ArgumentList "$($j.seed)" `
    -WorkingDirectory $rundir -Wait -NoNewWindow `
    -RedirectStandardOutput (Join-Path $rundir 'sim.log') -RedirectStandardError (Join-Path $rundir 'sim.err')
  foreach ($line in (Select-String -Path (Join-Path $rundir 'sim.log') -Pattern '\[timing\]|\[ctrl final' -ErrorAction SilentlyContinue)) {
    Write-Host ("  " + ($line.Line -replace '\s+',' ').Trim())
  }
}
Write-Host "`nrecertify complete."
