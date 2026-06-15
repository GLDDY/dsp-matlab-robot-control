param(
  [string]$RepoName = "dsp-matlab-robot-control",
  [switch]$Public
)

$ErrorActionPreference = "Stop"

$Gh = "C:\Program Files\GitHub CLI\gh.exe"
if (-not (Test-Path -LiteralPath $Gh)) {
  $Gh = "gh"
}

$visibility = if ($Public) { "--public" } else { "--private" }

& $Gh auth status
if ($LASTEXITCODE -ne 0) {
  throw "GitHub CLI is not authenticated. Run: gh auth login"
}

$branch = (git branch --show-current).Trim()
if (-not $branch) {
  throw "No current git branch found."
}

$remotes = @(git remote)
if ($remotes -notcontains "origin") {
  & $Gh repo create $RepoName $visibility --source "." --remote origin --push
} else {
  git push -u origin $branch
}

& $Gh repo view --web
