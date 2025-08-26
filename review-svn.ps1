<# 
List all commits that need to be reviewed since the lastReviewedRev+1 up to HEAD 
for each repository defined in the JSON config file.

This script DOES NOT update the JSON file.
You have to manually adjust lastReviewedRev after your review.
#>

[CmdletBinding()]
param()

function Assert-Tool {
  param([string]$Tool)
  $null = Get-Command $Tool -ErrorAction SilentlyContinue
  if (-not $?) { throw "Tool '$Tool' not found in PATH. Please install SVN CLI or add it to PATH." }
}

# Determine config path automatically: same directory as the script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "svn-repos.json"

function Get-SvnUrl {
  param([string]$PathOrUrl)
  # If it's already a URL, return it
  if ($PathOrUrl -match '^(https?|svn(\+ssh)?):\/\/') { return $PathOrUrl }
  # Otherwise, assume it's a working copy and extract the URL
  $url = (& svn info --show-item url $PathOrUrl 2>$null).Trim()
  if (-not $url) { throw "Could not determine SVN URL for '$PathOrUrl'. Is it a valid working copy?" }
  return $url
}

function Get-SvnHeadRev {
  param([string]$PathOrUrl)
  $rev = (& svn info --show-item revision $PathOrUrl 2>$null).Trim()
  if (-not $rev) { throw "Could not retrieve HEAD revision for '$PathOrUrl'." }
  return [int]$rev
}

function Get-SvnLogXml {
  param(
    [string]$Url,
    [int]$FromRev,
    [int]$ToRev
  )
  # Use --xml for structured parsing
  $xmlText = & svn log $Url -r "$($FromRev):$($ToRev)" --xml -v 2>$null | Out-String
  if (-not $xmlText) { return $null }
  try { return [xml]$xmlText } catch { throw "Invalid XML from svn log (URL: $Url, $($FromRev):$($ToRev))." }
}

function Write-RepoHeader {
  param([string]$Name, [int]$FromRev, [int]$ToRev)
  Write-Host ""
  Write-Host ("="*80)
  Write-Host ("{0}  (revisions to review: {1} to {2})" -f $Name, $FromRev, $ToRev) -ForegroundColor Cyan
  Write-Host ("="*80)
}

try {
  Assert-Tool -Tool "svn"

  if (!(Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
  }

  $json = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
  try { $repos = $json | ConvertFrom-Json } catch { throw "Invalid JSON in $ConfigPath." }
  if ($repos -isnot [System.Collections.IEnumerable]) { $repos = @($repos) }

  $hasAnyToReview = $false

  foreach ($repo in $repos) {
    $name = $repo.name
    $path = $repo.path
    $lastReviewed = [int]$repo.lastReviewedRev

    if (-not $name -or -not $path) {
      Write-Warning "Invalid repo entry (missing name/path) -> skipped."
      continue
    }

    $url  = Get-SvnUrl -PathOrUrl $path
    $head = Get-SvnHeadRev -PathOrUrl $path

    $from = $lastReviewed + 1
    if ($from -gt $head) {
      Write-RepoHeader -Name $name -FromRev $from -ToRev $head
      Write-Host "No commits found in this range." -ForegroundColor Yellow
      continue
    }

    $logXml = Get-SvnLogXml -Url $url -FromRev $from -ToRev $head
    Write-RepoHeader -Name $name -FromRev $from -ToRev $head

    if (-not $logXml -or -not $logXml.log.logentry) {
      Write-Host "No commits found in this range." -ForegroundColor Yellow
      continue
    }

    $hasAnyToReview = $true

    foreach ($entry in $logXml.log.logentry) {
      $rev    = [int]$entry.revision
      $author = ($entry.author | Out-String).Trim()
      $date   = Get-Date $entry.date -Format "yyyy-MM-dd HH:mm:ss K"
      $msgRaw = ($entry.msg | Out-String)
      $msg    = ($msgRaw -replace "^\s+|\s+$","")

      Write-Host ("r{0} | {1} | {2}" -f $rev, $author, $date) -ForegroundColor Green

      if ($entry.paths.path) {
        foreach ($p in $entry.paths.path) {
          $act = $p.action
          $pth = ($p.'#text')
          Write-Host ("  [{0}] {1}" -f $act, $pth)
        }
      }

      if ($msg) {
        Write-Host "  --- message ---"
        $msg.Split("`n") | ForEach-Object { Write-Host ("    {0}" -f $_.TrimEnd()) }
      } else {
        Write-Host "  (no commit message)"
      }

      Write-Host ""
    }
  }

  if (-not $hasAnyToReview) {
    Write-Host ""
    Write-Host "No revisions to review across configured repositories." -ForegroundColor Green
  }

} catch {
  Write-Error $_.Exception.Message
  exit 1
}
