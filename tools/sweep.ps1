<#
  sweep.ps1 -- Gate B knob sweep harness (never tune blind).

  For each config in $runs: compile a fresh binary with nvcc + the -D knob
  overrides (config.h [KNOB] macros are #ifndef-guarded), run it, run
  tools/analyze.py, parse the scorecard, and append ONE row to sweep_log.csv:
      knob values -> m_hat, tau, KS, rate, steps/s, RT-factor, pass/fail boxes.

  Usage (from anywhere):
      pwsh C:\3D-BRAIN\tools\sweep.ps1                 # runs the built-in bracket
      pwsh C:\3D-BRAIN\tools\sweep.ps1 -Seed 7

  Edit the $runs list to define the plan. Each entry overrides ONLY the knobs
  that differ from config.h defaults; everything else stays at the canon value.
  Float knobs MUST carry the 'f' suffix (e.g. '2.0f') so device math stays fp32.
#>
param(
  [int]$Seed = 1234,
  [string]$Root = 'C:\3D-BRAIN'
)
$ErrorActionPreference = 'Continue'   # one bad sweep point must not kill the batch

# ---- import the VS Developer environment (so nvcc can find cl.exe + headers) -
# Raw nvcc (unlike CMake) does not set up the host toolchain; vcvars64.bat does.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath  = & $vswhere -latest -property installationPath
$vcvars  = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found at $vcvars" }
cmd /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
  $i = $_.IndexOf('='); if ($i -gt 0) {
    [System.Environment]::SetEnvironmentVariable($_.Substring(0,$i), $_.Substring($i+1), 'Process')
  }
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw 'cl.exe not on PATH after vcvars import' }
Write-Host "VS env imported: cl.exe = $((Get-Command cl.exe).Source)`n"

# ---- the sweep plan ---------------------------------------------------------
# Bracket J win: on the MODULAR net, tau finally RESPONDS to drive -- 2.0 (NU=300)
# -> 3.58 (NU=800) -> tonic (NU=2000), vs stuck 3.5-6 on the random net. The critical
# transition EXISTS now (structure worked). But low-drive tau~2 is too sparse (not
# alive, KS=0.33). Bracket K maps NU 400-700 finely for tau->1.5 with alive=PASS and
# KS<0.1. Controllers still OFF (isolate structure).
$runs = @(
  @{ label = 'k1_nu400'; defs = @{ NU_EXT_HZ='400.0f'; W_EXT='8.0f'; W_EXC_INIT='6.0f'; W_INH_INIT='8.0f'; W_MAX='20.0f'; ISTDP_ETA='0.0f'; GAIN_ETA='0.0f' } }
  @{ label = 'k2_nu500'; defs = @{ NU_EXT_HZ='500.0f'; W_EXT='8.0f'; W_EXC_INIT='6.0f'; W_INH_INIT='8.0f'; W_MAX='20.0f'; ISTDP_ETA='0.0f'; GAIN_ETA='0.0f' } }
  @{ label = 'k3_nu600'; defs = @{ NU_EXT_HZ='600.0f'; W_EXT='8.0f'; W_EXC_INIT='6.0f'; W_INH_INIT='8.0f'; W_MAX='20.0f'; ISTDP_ETA='0.0f'; GAIN_ETA='0.0f' } }
  @{ label = 'k4_nu700'; defs = @{ NU_EXT_HZ='700.0f'; W_EXT='8.0f'; W_EXC_INIT='6.0f'; W_INH_INIT='8.0f'; W_MAX='20.0f'; ISTDP_ETA='0.0f'; GAIN_ETA='0.0f' } }
)

# ---- config.h defaults (for logging the full knob vector each row) ----------
$def = [ordered]@{
  W_EXC_INIT='0.5f'; W_INH_INIT='2.0f'; W_MAX='8.0f'; NU_EXT_HZ='3.0f'; W_EXT='1.2f';
  RHO0_HZ='3.0f'; ISTDP_ETA='0.005f'; GAIN_ETA='1.0e-4f'; LAMBDA_UM='150.0f'; TARGET_OUTDEG='100'
}

$exeDir = Join-Path $Root 'build\sweep'
New-Item -ItemType Directory -Force -Path $exeDir | Out-Null
$log = Join-Path $Root 'sweep_log.csv'
$cols = @('label') + @($def.Keys) + @('m_hat_MR','tau_size','KS_size','rate_hz','steps_per_s','rt_factor','aval_count','self_sus','near','powerlaw','crackle')
if (-not (Test-Path $log)) { ($cols -join ',') | Set-Content -Encoding utf8 $log }

$src = @("$Root\src\main.cu", "$Root\src\sim.cu", "$Root\src\connectome.cu")
$analyze = "$Root\tools\analyze.py"

foreach ($run in $runs) {
  $label = $run.label
  Write-Host "==================== $label ===================="

  # merged knob vector (defaults + this run's overrides), for logging
  $vec = [ordered]@{}; foreach ($k in $def.Keys) { $vec[$k] = $def[$k] }
  foreach ($k in $run.defs.Keys) { $vec[$k] = $run.defs[$k] }

  # compile-time -D overrides for the changed knobs only
  $dflags = @(); foreach ($k in $run.defs.Keys) { $dflags += "-D$k=$($run.defs[$k])" }
  Write-Host ("  defs: " + (($dflags -join ' ') -replace '^$','(baseline)'))

  # ---- compile a fresh binary with nvcc ------------------------------------
  $exe = Join-Path $exeDir "$label.exe"
  $nvcc = @(
    '-std=c++17','-O3','-use_fast_math','-arch=sm_89','-cudart','static',
    "-I$Root\include",
    '-Xcompiler=/MT,/O2,/EHsc,/openmp,/nologo'
  ) + $dflags + $src + @('-lcurand','-o', $exe)
  $t0 = [System.Diagnostics.Stopwatch]::StartNew()
  & nvcc @nvcc 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "  BUILD FAILED (nvcc exit $LASTEXITCODE) -- skipping"; continue }
  Write-Host ("  built in {0:n0}s" -f $t0.Elapsed.TotalSeconds)

  # ---- run the sim ----------------------------------------------------------
  $rundir = Join-Path $Root "run\$label"
  New-Item -ItemType Directory -Force -Path $rundir | Out-Null
  Get-ChildItem $rundir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  $simLog = Join-Path $rundir 'sim.log'
  Start-Process -FilePath $exe -ArgumentList "$Seed" -WorkingDirectory $rundir -Wait -NoNewWindow `
    -RedirectStandardOutput $simLog -RedirectStandardError (Join-Path $rundir 'sim.err')

  # ---- analyze --------------------------------------------------------------
  $anaLog = Join-Path $rundir 'analyze.log'
  Start-Process -FilePath 'python' -ArgumentList "`"$analyze`"" -WorkingDirectory $rundir -Wait -NoNewWindow `
    -RedirectStandardOutput $anaLog -RedirectStandardError (Join-Path $rundir 'analyze.err')

  # ---- parse ----------------------------------------------------------------
  $sim = (Get-Content $simLog -Raw); $ana = (Get-Content $anaLog -Raw)
  function M($text,$re,$grp=1){ if ($text -match $re) { $matches[$grp] } else { 'NA' } }
  $mhat = M $ana 'm_hat\s*\(MR\)\s*=\s*(\S+)'
  $tau  = M $ana 'tau\s*\(MLE\)\s*=\s*(\S+)'
  $ks   = M $ana 'KS=(\S+)\s+\(n='
  $sps  = M $sim '\|\s*(\d+)\s*steps/s'
  $rtf  = M $sim 'real-time factor\s*([\d.]+)x'
  $avc  = M $sim '\[avalanches\]\s*count=(\d+)'
  $rate = 'NA'; $rm = [regex]::Matches($sim,'rate\s+([\d.]+)\s*Hz'); if ($rm.Count) { $rate = $rm[$rm.Count-1].Groups[1].Value }
  $sus  = M $ana '\[(PASS|----)\]\s*self-sustaining'
  $near = M $ana '\[(PASS|----)\]\s*near-critical'
  $pl   = M $ana '\[(PASS|----)\]\s*size power law'
  $cr   = M $ana '\[(PASS|----)\]\s*crackling'

  $row = @($label) + @($vec.Values) + @($mhat,$tau,$ks,$rate,$sps,$rtf,$avc,$sus,$near,$pl,$cr)
  Add-Content -Encoding utf8 $log ($row -join ',')
  Write-Host "  -> m_hat=$mhat  tau=$tau  KS=$ks  rate=$rate Hz  steps/s=$sps  rt=${rtf}x  aval=$avc  alive=$sus  [$near|$pl|$cr]"
}
Write-Host "`nsweep complete -> $log"
