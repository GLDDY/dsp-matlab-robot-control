$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MatlabCandidates = @(
  "D:\Program Files\MATLAB\R2025a\bin\matlab.exe",
  "D:\Program Files\MATLAB\R2020a\bin\matlab.exe"
)
$Python = "C:\Users\86155\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

$Matlab = $MatlabCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $Matlab) {
  throw "MATLAB not found. Checked: $($MatlabCandidates -join ', ')"
}

if (-not (Test-Path -LiteralPath $Python)) {
  $Python = "python"
}

Push-Location $ProjectRoot
try {
  & $Python -c "import seaborn, pandas, matplotlib" 2>$null
  if ($LASTEXITCODE -ne 0) {
    & $Python -m pip install seaborn pandas matplotlib
  }
  & $Matlab -batch "cd('$ProjectRoot'); addpath('matlab'); run_all_simulations"
  & $Python "scripts/plot_publication_figures.py"
  & $Python "scripts/generate_report.py"
  & $Python "scripts/generate_ppt_guide.py"
  & $Python "scripts/validate_report.py"
} finally {
  Pop-Location
}
