$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Matlab = "D:\Program Files\MATLAB\R2020a\bin\matlab.exe"
$Python = "C:\Users\86155\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

if (-not (Test-Path -LiteralPath $Matlab)) {
  throw "MATLAB not found at $Matlab"
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
  & $Python "scripts/validate_report.py"
} finally {
  Pop-Location
}
