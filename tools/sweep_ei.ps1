<#
  sweep_ei.ps1 -- Session 4, Step 1: DOES INHIBITION HAVE ANY AUTHORITY?

  Re-tests the load-bearing Session-3 E/I null (W_INH_INIT 4->10->16 => same operating
  point), which was attributed to "iSTDP slaves inhibitory weight to the rate target and
  washes out W_INH_INIT". That explanation is numerically inconsistent with the code:
  k_scatter updates an edge once per PRESYNAPTIC spike, so at the t4 corner
  (inh rate ~19 Hz over 20 s, x_trace ~0.22, alpha 0.06, eta 0.005) the total excursion is
  dw ~ 0.3 -- it cannot erase a 4->16 difference. Meanwhile W_EXC 3->9 moves meanA 236->1311
  and drive 50->150 moves Fano 1211->280, but a 4x inhibitory change moves nothing. Inertness
  that total is an anomaly, not a finding, and the desynchronizer mandate rests on it.

  This sweep raises inhibitory AUTHORITY along the two axes never varied in any of the 32
  logged sweep rows -- ISTDP_ETA (0.005 in every row) and the W_MAX ceiling -- and reads the
  new [ctrl] probe in main.cu to see what inhibition actually does.

  PRE-REGISTERED (locked before data):
    A. Controls e_t4_ctl / e_w9_ctl must reproduce x_we3 (Fano ~112) / x_we9 (Fano ~7004).
       They also regression-check the QC H1/H2 integrator fixes: a material shift means the
       old isfinite guard WAS being elided and prior results carry silent divergence.
    B. If [ctrl] shows w_inh and the inhibitory drive g_inh RISING with eta/W_MAX but Fano
       stays >100 -> inhibition has authority and cannot desynchronize. The E/I null is REAL,
       and the contract-touching desynchronizer mandate is earned.
    C. If w_inh / g_inh do NOT rise with authority -> inhibition is structurally inert
       (mechanism defect). The mandate was premature; fix the mechanism first.
    D. If Fano falls toward the 2-20 band while alive -> the void was an artifact of
       under-powered rate homeostasis, and no contract change is needed at all.

  Adjudicate:  python C:\3D-BRAIN\tools\sweep_report.py e_t4_ctl e_t4_eta50 e_t4_eta200 `
                      e_t4_wi16 e_w9_ctl e_w9_eta200 e_w9_wi16 e_w9_eta200_wi16
  Usage: pwsh C:\3D-BRAIN\tools\sweep_ei.ps1
#>
param([int]$Seed = 1234, [string]$Root = 'C:\3D-BRAIN')
$ErrorActionPreference = 'Continue'

# import VS Developer env so raw nvcc finds cl.exe + headers
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
Write-Host "VS env imported: $((Get-Command cl.exe).Source)`n"

# t4 base, unchanged from sweep_t4.ps1 so the controls are directly comparable
$common = @{ W_EXT = '80.0f'; STD_U = '0.2f'; TAU_REC_MS = '400.0f'; NU_EXT_HZ = '100.0f' }
$runs = @(
  # --- least-bursty base (t4 / x_we3, Fano ~112) ---
  @{ label = 'e_t4_ctl';         defs = @{ W_EXC_INIT='3.0f'; W_INH_INIT='4.0f';  W_MAX='20.0f'; ISTDP_ETA='0.005f' } } # == x_we3
  @{ label = 'e_t4_eta50';       defs = @{ W_EXC_INIT='3.0f'; W_INH_INIT='4.0f';  W_MAX='20.0f'; ISTDP_ETA='0.05f'  } }
  @{ label = 'e_t4_eta200';      defs = @{ W_EXC_INIT='3.0f'; W_INH_INIT='4.0f';  W_MAX='60.0f'; ISTDP_ETA='0.2f'   } }
  @{ label = 'e_t4_wi16';        defs = @{ W_EXC_INIT='3.0f'; W_INH_INIT='16.0f'; W_MAX='60.0f'; ISTDP_ETA='0.005f' } }
  # --- seizing base (x_we9, Fano ~7004) ---
  @{ label = 'e_w9_ctl';         defs = @{ W_EXC_INIT='9.0f'; W_INH_INIT='4.0f';  W_MAX='20.0f'; ISTDP_ETA='0.005f' } } # == x_we9
  @{ label = 'e_w9_eta200';      defs = @{ W_EXC_INIT='9.0f'; W_INH_INIT='4.0f';  W_MAX='60.0f'; ISTDP_ETA='0.2f'   } }
  @{ label = 'e_w9_wi16';        defs = @{ W_EXC_INIT='9.0f'; W_INH_INIT='16.0f'; W_MAX='60.0f'; ISTDP_ETA='0.005f' } }
  @{ label = 'e_w9_eta200_wi16'; defs = @{ W_EXC_INIT='9.0f'; W_INH_INIT='16.0f'; W_MAX='60.0f'; ISTDP_ETA='0.2f'   } }
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
  $nvcc = @('-std=c++17', '-O3', '-use_fast_math', '-arch=sm_89', '-cudart', 'static',
            "-I$Root\include", '-Xcompiler=/MT,/O2,/EHsc,/openmp,/nologo') + $dflags + $src + @('-lcurand', '-o', $exe)
  $t0 = [System.Diagnostics.Stopwatch]::StartNew()
  & nvcc @nvcc 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "  BUILD FAILED (nvcc exit $LASTEXITCODE) -- skipping"; continue }
  Write-Host ("  built in {0:n0}s; running..." -f $t0.Elapsed.TotalSeconds)
  $rundir = Join-Path $Root "run\$label"
  New-Item -ItemType Directory -Force -Path $rundir | Out-Null
  Get-ChildItem $rundir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath $exe -ArgumentList "$Seed" -WorkingDirectory $rundir -Wait -NoNewWindow `
    -RedirectStandardOutput (Join-Path $rundir 'sim.log') -RedirectStandardError (Join-Path $rundir 'sim.err')
  $ctrl = Select-String -Path (Join-Path $rundir 'sim.log') -Pattern '\[ctrl final' -ErrorAction SilentlyContinue
  foreach ($line in $ctrl) { Write-Host ("  " + $line.Line) }
  Write-Host "  done -> run\$label\activity.csv"
}
Write-Host "`nsweep_ei complete. Adjudicate:"
Write-Host "  python C:\3D-BRAIN\tools\sweep_report.py e_t4_ctl e_t4_eta50 e_t4_eta200 e_t4_wi16 e_w9_ctl e_w9_eta200 e_w9_wi16 e_w9_eta200_wi16"
