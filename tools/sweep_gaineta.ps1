<#
  sweep_gaineta.ps1 -- GAIN_ETA, the last never-swept controller-authority knob.

  GAIN_ETA is 1.0e-4 in ALL 32 logged sweep rows. It sets the slow controller's integration
  rate, so it is the one remaining knob that could mean the certified point sits in a narrow
  basin rather than a regime. It also directly controls the TIMESCALE SEPARATION that MODULE.md
  §5 B7 requires: too slow and the controller never converges; too fast and it stops being the
  slow controller at all and starts competing with iSTDP instead of complementing it.

  Base = the certified point (L_wm200_100s): W_EXC 5, W_INH_INIT 4, W_MAX 200, ISTDP_ETA 0.2,
  GAIN_MIN 0.1, W_EXT 80, NU_EXT 5, STD_U 0.2, TAU_REC 400. Runs are 100 s (N_STEPS=1e6) per the
  amended §5 run-length clause, each dumping spikes over 90-98 s for the full AI battery.

  PRE-REGISTERED (locked before data):
    * 1e-5 (10x slower): expect B7 FAIL -- gain cannot traverse its range even in 100 s, so it
      sits wherever the startup transient left it. This is the control that confirms the
      timescale arithmetic (0.007/s at a 0.7 Hz error) rather than assuming it.
    * 1e-4: the control. Must reproduce L_wm200_100s (Fano ~9.4, FLAT ~0.98, gain ~0.41 @ 4.6%).
    * 5e-4 .. 1e-2 (5x-100x faster): the interesting direction. If B1-B7 hold, the point is a
      REGIME robust across >=2 orders of magnitude. If the fast end oscillates or collapses the
      timescale separation, there is an upper bound and it must be reported as one, not omitted.
  A knob that changes nothing is also a result: it would mean the slow controller's RATE is not
  what mattered -- only its RANGE (GAIN_MIN), which is what Session 4 actually found.

  Usage: pwsh C:\3D-BRAIN\tools\sweep_gaineta.ps1
  Then:  python tools\sweep_report.py gE_1e5 gE_1e4 gE_5e4 gE_2e3 gE_1e2
         python tools\airegime.py     gE_1e5 gE_1e4 gE_5e4 gE_2e3 gE_1e2
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

$common = @{ W_EXT='80.0f'; STD_U='0.2f'; TAU_REC_MS='400.0f'; W_INH_INIT='4.0f'; W_MAX='200.0f';
             ISTDP_ETA='0.2f'; W_EXC_INIT='5.0f'; NU_EXT_HZ='5.0f'; GAIN_MIN='0.1f';
             N_STEPS='1000000'; DUMP_START='900000'; DUMP_LEN='80000' }
$runs = @(
  @{ label='gE_1e5'; defs=@{ GAIN_ETA='1.0e-5f' } }
  @{ label='gE_1e4'; defs=@{ GAIN_ETA='1.0e-4f' } }   # control == L_wm200_100s
  @{ label='gE_5e4'; defs=@{ GAIN_ETA='5.0e-4f' } }
  @{ label='gE_2e3'; defs=@{ GAIN_ETA='2.0e-3f' } }
  @{ label='gE_1e2'; defs=@{ GAIN_ETA='1.0e-2f' } }
)

$exeDir = Join-Path $Root 'build\sweep'
New-Item -ItemType Directory -Force -Path $exeDir | Out-Null
$src = @("$Root\src\main.cu", "$Root\src\sim.cu", "$Root\src\connectome.cu")

foreach ($run in $runs) {
  $label = $run.label
  Write-Host "==================== $label ===================="
  $dflags = @(); foreach ($k in $common.Keys) { $dflags += "-D$k=$($common[$k])" }
  foreach ($k in $run.defs.Keys) { $dflags += "-D$k=$($run.defs[$k])" }
  Write-Host ("  GAIN_ETA=" + $run.defs['GAIN_ETA'])
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
  foreach ($line in (Select-String -Path (Join-Path $rundir 'sim.log') -Pattern '\[ctrl (mid|final)' -ErrorAction SilentlyContinue)) {
    Write-Host ("  " + $line.Line)
  }
  Write-Host "  done -> run\$label\"
}
Write-Host "`nsweep_gaineta complete. Adjudicate:"
Write-Host "  python C:\3D-BRAIN\tools\sweep_report.py gE_1e5 gE_1e4 gE_5e4 gE_2e3 gE_1e2"
Write-Host "  python C:\3D-BRAIN\tools\airegime.py     gE_1e5 gE_1e4 gE_5e4 gE_2e3 gE_1e2"
