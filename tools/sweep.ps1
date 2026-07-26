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
# Bracket Q: even W_EXC=150 at NU=20 is DEAD -> recurrence CANNOT self-sustain at low
# drive (fan-out dilutes: one 150-spike spreads over 100 targets = sub-threshold each;
# reset+adaptation blocks reverberation). So the low-drive self-sustaining base STD wants
# doesn't exist here. BUT the net IS alive at NU=600-800 (modular). Test STD THERE: STD
# should INTRODUCE the quiescence/timescale-separation that regime lacks, chopping the
# drive-avalanches (tau 3.5-5.8) into critical ones. r4 = stronger STD (U=0.4).
# BREAKTHROUGH (single-spike test): root cause was DELTA synapses -> base m=0.8 (subcrit).
# Synaptic tau=5ms -> base m>>1 (40M descendants). SOC finally has its supercritical base.
# Bracket S: STD on (default) + SLOW drive (NU 5-20 -> IEI>1) + supercritical base, ctl on.
# STD should self-organize branching DOWN to m=1. Judge on CRITICAL (m_hat & tau agree).
# DIALED: first-bin sigma is a clean graded 1-D knob. W_EXC=3.0 -> sigma~2.5 (cascade ~47,
# finite, NOT saturated) = modest-supercritical base; W_EXC>=4 runs away. Bracket T: base
# W_EXC=3 + STD on + calibrated seeding (strong W_EXT so one event fires a neuron, low NU so
# seeds are rare -> IEI>1) + ctl on. STD self-organizes <D> -> 1/sigma. Judge on CRITICAL.
# Bracket T bracketed it: t3 (W_EXT40/NU50) alive + KS=0.072 clean + m_hat=0.996, tau=2.58;
# t4 (W_EXT80/NU100) tau=1.41 (in range) but only 91 aval (poor KS). Critical point is
# between -- keep t3's intermittency (1000s of avalanches, clean KS) but nudge base sigma up
# (W_EXC 3.0->3.5) at moderate drive to pull tau 2.58 -> ~1.5. Judge on CRITICAL.
# Bracket U: tau ON TARGET (1.44-1.63), m_hat~0.99, alive, crackling -- only KS (0.10-0.12)
# just over the 0.1 bar, and IEI=1 (gap-less drive blurs the fit). Bracket V slows the drive
# (lower NU) on the winning weights so gaps form (IEI>1) and the power law sharpens (KS<0.1)
# -> full CRITICAL (m_hat & tau agree, self-sustaining, clean).
# Contingency #4 IS the situation: v2 (W_EXC3.5/W_EXT45/NU35) = clean KS=0.058 + 3160 aval
# but tau=3.1 (steep) -- the modular cap (~390) limits avalanche size. Bracket W loosens
# inter-module coupling on v2's clean base so cascades escape modules -> power law extends
# -> tau drops 3.1 toward 1.5 while KS stays clean -> full CRITICAL (m_hat & tau agree).
$runs = @(
  @{ label = 'w1_wsa05'; defs = @{ W_EXC_INIT='3.5f'; W_INH_INIT='4.7f'; W_EXT='45.0f'; NU_EXT_HZ='35.0f'; W_MAX='20.0f'; W_SAME_AREA='0.5f';  W_DIFF_AREA='0.12f' } }
  @{ label = 'w2_wsa07'; defs = @{ W_EXC_INIT='3.5f'; W_INH_INIT='4.7f'; W_EXT='45.0f'; NU_EXT_HZ='35.0f'; W_MAX='20.0f'; W_SAME_AREA='0.7f';  W_DIFF_AREA='0.20f' } }
  @{ label = 'w3_wsa10'; defs = @{ W_EXC_INIT='3.5f'; W_INH_INIT='4.7f'; W_EXT='45.0f'; NU_EXT_HZ='35.0f'; W_MAX='20.0f'; W_SAME_AREA='1.0f';  W_DIFF_AREA='0.30f' } }
  @{ label = 'w4_wsa10d5'; defs = @{ W_EXC_INIT='3.5f'; W_INH_INIT='4.7f'; W_EXT='45.0f'; NU_EXT_HZ='35.0f'; W_MAX='20.0f'; W_SAME_AREA='1.0f';  W_DIFF_AREA='0.50f' } }
)

# ---- config.h defaults (for logging the full knob vector each row) ----------
$def = [ordered]@{
  W_EXC_INIT='0.5f'; W_INH_INIT='2.0f'; W_MAX='8.0f'; NU_EXT_HZ='3.0f'; W_EXT='1.2f';
  RHO0_HZ='3.0f'; ISTDP_ETA='0.005f'; GAIN_ETA='1.0e-4f'; LAMBDA_UM='150.0f'; TARGET_OUTDEG='100';
  STD_U='0.2f'; TAU_REC_MS='400.0f'
}

$exeDir = Join-Path $Root 'build\sweep'
New-Item -ItemType Directory -Force -Path $exeDir | Out-Null
$log = Join-Path $Root 'sweep_log.csv'
$cols = @('label') + @($def.Keys) + @('m_hat_MR','tau_size','KS_size','IEI','rate_hz','steps_per_s','rt_factor','aval_count','self_sus','near','powerlaw','crackle','CRITICAL')
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
  $crit = M $ana '\[(PASS|----)\]\s*>>> CRITICAL'
  $iei  = M $ana '<IEI>\s*=\s*(\d+)'

  $row = @($label) + @($vec.Values) + @($mhat,$tau,$ks,$iei,$rate,$sps,$rtf,$avc,$sus,$near,$pl,$cr,$crit)
  Add-Content -Encoding utf8 $log ($row -join ',')
  Write-Host "  -> m_hat=$mhat tau=$tau KS=$ks IEI=$iei rate=$rate Hz rt=${rtf}x aval=$avc alive=$sus crit=$crit [$near|$pl|$cr]"
}
Write-Host "`nsweep complete -> $log"
