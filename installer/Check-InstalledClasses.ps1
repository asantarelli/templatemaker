<#
.SYNOPSIS
    Audit (and optionally fix) the copies of this repo's class files installed on
    Clarion's redirection path.

.DESCRIPTION
    These classes belong in ONE place: %ROOT%\Accessory\libsrc\win. Anything found
    in %ROOT%\libsrc\win (SoftVelocity's own folder) or loose in an app folder is
    misplaced and should be deleted, not maintained.

    It matters because CLARION120.RED searches "." first, then %ROOT%\libsrc\win,
    and only then %ROOT%\Accessory\libsrc\win. A misplaced older copy therefore
    WINS over the correct one, and updating the correct one fixes nothing.

    Two distinct failures come out of that:

      1. The IDE's class registry reads EVERY copy it finds and merges their
         prototypes, so a method whose signature changed gets registered twice. A
         data DLL then exports both spellings while the compiler builds only one:

             BUILD@F10AZTECCLASSsb is unresolved for export - data.exp:125,3

      2. A copy still carrying a bare !ABCIncludeFile tag keeps its class in the
         ABC category, which is link-mode in a data DLL - so that class is
         exported from the DLL whether the application uses it or not, and fails
         the link if its .clw was never compiled in.

.PARAMETER ClarionRoot
    Clarion install root. Defaults to $env:CLARION_ROOT, else C:\clarion12.

.PARAMETER AppFolder
    Optional app directory to check as well. Redirection searches "." first, so a
    copy there beats both libsrc folders.

.PARAMETER Fix
    Refresh out-of-date copies in the correct folder from this repo. Never deletes.

.PARAMETER RemoveMisplaced
    Delete copies found outside Accessory\libsrc\win. Deliberately a separate
    switch from -Fix, since it removes files from your Clarion install.

.EXAMPLE
    .\Check-InstalledClasses.ps1
    .\Check-InstalledClasses.ps1 -Fix
    .\Check-InstalledClasses.ps1 -Fix -RemoveMisplaced
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $ClarionRoot = $(if ($env:CLARION_ROOT) { $env:CLARION_ROOT } else { 'C:\clarion12' }),
    [string] $AppFolder,
    [switch] $Fix,
    [switch] $RemoveMisplaced
)

$ErrorActionPreference = 'Stop'

$templates = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates'
if (-not (Test-Path $templates)) { throw "templates folder not found at $templates" }

$canonical = Join-Path $ClarionRoot 'Accessory\libsrc\win'

# Every folder redirection will look in, in order - earlier wins.
$searched = @()
if ($AppFolder) { $searched += [pscustomobject]@{ Name = 'app folder'; Path = $AppFolder } }
$searched += [pscustomobject]@{ Name = 'libsrc\win';           Path = Join-Path $ClarionRoot 'LibSrc\win' }
$searched += [pscustomobject]@{ Name = 'Accessory\libsrc\win'; Path = $canonical }

# Class sources and their C engines - not the .tpl, .zip or docs.
# xquickfilter is a third-party template kept here local-only; not ours to touch.
$shipped = Get-ChildItem $templates -Recurse -File |
    Where-Object { $_.Extension -in '.inc', '.clw', '.c', '.h' -and $_.FullName -notmatch 'xquickfilter' } |
    Group-Object Name | ForEach-Object { $_.Group[0] }

function Get-Tag([string] $path) {
    if (-not $path.EndsWith('.inc')) { return '' }
    $first = Get-Content -LiteralPath $path -TotalCount 1
    if ($first -match '^!ABCIncludeFile') { return $first.Trim() }
    return ''
}

function Test-Same([string] $a, [string] $b) {
    if ((Get-Item -LiteralPath $a).Length -ne (Get-Item -LiteralPath $b).Length) { return $false }
    -not (Compare-Object (Get-Content -LiteralPath $a -AsByteStream) `
                         (Get-Content -LiteralPath $b -AsByteStream))
}

$rows = @()
foreach ($f in $shipped | Sort-Object Name) {
    $hits = foreach ($s in $searched) {
        $p = Join-Path $s.Path $f.Name
        if (Test-Path -LiteralPath $p) {
            [pscustomobject]@{
                Where     = $s.Name
                Path      = $p
                Correct   = ($s.Path -eq $canonical)
                UpToDate  = (Test-Same $p $f.FullName)
                Tag       = (Get-Tag $p)
            }
        }
    }
    $hits = @($hits)
    if (-not $hits) { continue }
    $rows += [pscustomobject]@{
        Name      = $f.Name
        Template  = Split-Path -Leaf $f.DirectoryName
        Source    = $f.FullName
        Hits      = $hits
        Misplaced = @($hits | Where-Object { -not $_.Correct })
        Stale     = @($hits | Where-Object { $_.Correct -and -not $_.UpToDate })
        Bare      = @($hits | Where-Object { $_.Tag -eq '!ABCIncludeFile' })
        Absent    = -not ($hits | Where-Object { $_.Correct })
    }
}

Write-Host ''
Write-Host "Clarion root      : $ClarionRoot"
Write-Host "Correct location  : $canonical"
Write-Host "Repo              : $templates"
Write-Host "Installed files   : $($rows.Count)"
Write-Host ''

$problems = @($rows | Where-Object { $_.Misplaced.Count -or $_.Stale.Count -or $_.Bare.Count -or $_.Absent })
if (-not $problems) {
    Write-Host 'Clean: every installed file is in the right folder, current, and tagged.' -ForegroundColor Green
    return
}

foreach ($r in $problems) {
    Write-Host ("{0}  ({1})" -f $r.Name, $r.Template) -ForegroundColor Yellow
    foreach ($h in $r.Hits) {
        $state = if ($h.UpToDate) { 'current' } else { 'OUT OF DATE' }
        $mark  = if ($h.Correct)  { ' ' } else { '!' }
        $tag   = if ($h.Tag) { "  $($h.Tag)" } else { '' }
        Write-Host ("  {0} {1,-22} {2,-12}{3}" -f $mark, $h.Where, $state, $tag)
    }
    if ($r.Misplaced.Count) {
        Write-Host '      ! wrong folder - delete it. It wins over the correct copy by redirection order,' -ForegroundColor Red
        Write-Host '        and the class registry merges both copies'' prototypes.' -ForegroundColor Red
    }
    if ($r.Bare.Count) {
        Write-Host '      ! bare !ABCIncludeFile - a data DLL will export this class even when unused.' -ForegroundColor Red
    }
    if ($r.Absent) {
        Write-Host '      ! not installed in the correct folder at all.' -ForegroundColor Red
    }
}

$stale     = @($rows | Where-Object { $_.Stale.Count -or $_.Absent })
$misplaced = @($rows | Where-Object { $_.Misplaced.Count })

Write-Host ''
if ($Fix) {
    foreach ($r in $stale) {
        $dest = Join-Path $canonical $r.Name
        if ($PSCmdlet.ShouldProcess($dest, 'refresh from repo')) {
            Copy-Item -LiteralPath $r.Source -Destination $dest -Force
            Write-Host ("refreshed  {0}" -f $r.Name) -ForegroundColor Green
        }
    }
} elseif ($stale) {
    Write-Host ("{0} file(s) out of date or missing in the correct folder - re-run with -Fix." -f $stale.Count)
}

if ($misplaced) {
    if ($RemoveMisplaced) {
        foreach ($r in $misplaced) {
            foreach ($h in $r.Misplaced) {
                if ($PSCmdlet.ShouldProcess($h.Path, 'delete misplaced copy')) {
                    Remove-Item -LiteralPath $h.Path -Force
                    Write-Host ("deleted    {0}  ({1})" -f $r.Name, $h.Where) -ForegroundColor Green
                }
            }
        }
    } else {
        Write-Host ''
        Write-Host ("{0} file(s) are in the wrong folder. Re-run with -RemoveMisplaced to delete them," -f $misplaced.Count)
        Write-Host 'or do it by hand:'
        foreach ($r in $misplaced) {
            foreach ($h in $r.Misplaced) { Write-Host ("    Remove-Item '{0}'" -f $h.Path) }
        }
    }
}

Write-Host ''
Write-Host 'After changing anything here, regenerate your apps. If a class you removed still'
Write-Host 'shows up in a generated .EXP, the IDE is holding a cached class registry: press'
Write-Host '"Refresh Application Builder Class Information" on the Global Properties Classes'
Write-Host 'tab, or restart the IDE.'
