<#
  sweep_dump.ps1 -- Session 4, Step 2: spike dumps for the ASYNCHRONOUS-IRREGULAR battery.

  Fano and m_hat are POPULATION statistics; neither can see whether individual neurons fire
  irregularly or whether pairs are decorrelated. Those are the two defining signatures of the
  asynchronous-irregular state and the Phase-0.5 battery in CLAUDE.md (CV_ISI ~ 1, low pairwise
  correlation). This dumps every spike over a 4 s window (DUMP_LEN) so tools/airegime.py can
  measure them.

  Points:
    d_w9e200_nu100 -- the in-band winner at full drive          (Fano 2.0)
    d_w9e200_nu5   -- the same base at 1/20th drive, 99.75% recurrent (Fano 3.1)  <- the real test
    d_w9_ctl       -- the seizing control, for contrast         (Fano 7631)

  Reference values: cortex in vivo CV_ISI ~ 0.8-1.2, pairwise correlation ~ 0.01-0.1.
  Clock-like firing gives CV_ISI << 0.5; synchronized bursting gives correlation >> 0.1.

  PRE-REGISTERED: the in-band points are only asynchronous-irregular if CV_ISI lands near 1 AND
  pairwise correlation is small. High Fano-band scores with CV_ISI ~ 0.2 would mean the population
  rate is smooth because every neuron is firing like a metronome -- regular, not irregular, and NOT
  the reverberating regime. That outcome must be reported as a failure, not spun.

  Usage: pwsh C:\3D-BRAIN\tools\sweep_dump.ps1   then   python tools\airegime.py
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

# 4 s window starting at 10 s -- well past the startup transient
$common = @{ W_EXT='80.0f'; STD_U='0.2f'; TAU_REC_MS='400.0f'; DUMP_START='100000'; DUMP_LEN='40000' }
$runs = @(
  @{ label='d_w9e200_nu100'; defs=@{ W_EXC_INIT='9.0f'; W_INH_INIT='4.0f'; W_MAX='60.0f'; ISTDP_ETA='0.2f';   NU_EXT_HZ='100.0f' } }
  @{ label='d_w9e200_nu5';   defs=@{ W_EXC_INIT='9.0f'; W_INH_INIT='4.0f'; W_MAX='60.0f'; ISTDP_ETA='0.2f';   NU_EXT_HZ='5.0f'   } }
  @{ label='d_w9_ctl';       defs=@{ W_EXC_INIT='9.0f'; W_INH_INIT='4.0f'; W_MAX='20.0f'; ISTDP_ETA='0.005f'; NU_EXT_HZ='100.0f' } }
)

$exeDir = Join-Path $Root 'build\sweep'
New-Item -ItemType Directory -Force -Path $exeDir | Out-Null
$src = @("$Root\src\main.cu", "$Root\src\sim.cu", "$Root\src\connectome.cu")

foreach ($run in $runs) {
  $label = $run.label
  Write-Host "==================== $label ===================="
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
  Write-Host "  done -> run\$label\spikes_window.csv"
}
Write-Host "`nsweep_dump complete.  Measure:  python C:\3D-BRAIN\tools\airegime.py"
