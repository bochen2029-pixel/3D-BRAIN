<#
  sweep_drive.ps1 -- Session 4, Step 1b: are the new in-band points SELF-SUSTAINING,
  or are they the Poisson drive-floor wearing a better disguise?

  sweep_ei.ps1 put four points in the Fano 2-20 band. They are already distinguishable from
  the known drive-floor (floor: m_hat = 0 at every bin width, 100% of neurons silent; new
  points: m_hat 0.996 at bin 1, 0% silent, per-neuron rate on the RHO0 target). But the
  external drive is still 0.800 mV/ms and it bypasses BOTH homeostats
  (sim.cu: I = gain*g + w_ext*n_ext), so "recurrent" has not been proven, only indicated.

  This knocks the drive down (NU_EXT 100 -> 25 -> 5) at the two cleanest in-band points and
  asks whether the activity survives on recurrence alone.

  PRE-REGISTERED (locked before data):
    RECURRENT  -> activity persists as drive falls; meanA degrades gracefully; m_hat stays
                  nonzero at fine bins. The in-band regime is real and self-sustaining.
    DRIVE-FED  -> meanA collapses toward the floor and m_hat -> 0 at every bin width. The
                  in-band points were the Poisson floor and the void stands after all.
  Anything in between (survives at nu=25, dies at nu=5) is a partial: report the threshold,
  do NOT round it up to "self-sustaining".

  Adjudicate:  python C:\3D-BRAIN\tools\sweep_report.py k_t4e50_nu25 k_t4e50_nu5 k_w9e200_nu25 k_w9e200_nu5
  Usage: pwsh C:\3D-BRAIN\tools\sweep_drive.ps1
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

$common = @{ W_EXT = '80.0f'; STD_U = '0.2f'; TAU_REC_MS = '400.0f' }
$runs = @(
  # e_t4_eta50 base (Fano 2.11, m@1 0.996) with the drive pulled down
  @{ label='k_t4e50_nu25';  defs=@{ W_EXC_INIT='3.0f'; W_INH_INIT='4.0f'; W_MAX='20.0f'; ISTDP_ETA='0.05f'; NU_EXT_HZ='25.0f' } }
  @{ label='k_t4e50_nu5';   defs=@{ W_EXC_INIT='3.0f'; W_INH_INIT='4.0f'; W_MAX='20.0f'; ISTDP_ETA='0.05f'; NU_EXT_HZ='5.0f'  } }
  # e_w9_eta200 base (Fano 1.95, broader per-neuron rate distribution)
  @{ label='k_w9e200_nu25'; defs=@{ W_EXC_INIT='9.0f'; W_INH_INIT='4.0f'; W_MAX='60.0f'; ISTDP_ETA='0.2f';  NU_EXT_HZ='25.0f' } }
  @{ label='k_w9e200_nu5';  defs=@{ W_EXC_INIT='9.0f'; W_INH_INIT='4.0f'; W_MAX='60.0f'; ISTDP_ETA='0.2f';  NU_EXT_HZ='5.0f'  } }
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
Write-Host "`nsweep_drive complete. Adjudicate:"
Write-Host "  python C:\3D-BRAIN\tools\sweep_report.py k_t4e50_nu25 k_t4e50_nu5 k_w9e200_nu25 k_w9e200_nu5"
