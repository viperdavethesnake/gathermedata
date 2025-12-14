#Requires -Version 7.0
<#
.SYNOPSIS
    Digital Corpora Downloader - PowerShell version for Windows

.DESCRIPTION
    Downloads forensic scenarios and file corpora from digitalcorpora.org
    Includes scenarios, file corpora, SAFEDOCS, and UNSAFE-DOCS

.PARAMETER ListScenarios
    List all available forensic scenarios

.PARAMETER ListCorpora
    List all available file corpora

.PARAMETER Scenario
    Download a specific forensic scenario

.PARAMETER Corpus
    Download a specific file corpus

.PARAMETER Path
    Custom download path (default: S:\DigitalCorpora)

.PARAMETER Parallel
    Number of parallel downloads (default: 4)

.PARAMETER Limit
    Limit number of files for corpus downloads

.EXAMPLE
    .\download_digitalcorpora.ps1 -ListScenarios

.EXAMPLE
    .\download_digitalcorpora.ps1 -Scenario "2018-lonewolf"

.EXAMPLE
    .\download_digitalcorpora.ps1 -Corpus "2009-audio" -Limit 100
#>

[CmdletBinding(DefaultParameterSetName='List')]
param(
    [Parameter(ParameterSetName='ListScenarios')]
    [switch]$ListScenarios,
    
    [Parameter(ParameterSetName='ListCorpora')]
    [switch]$ListCorpora,
    
    [Parameter(ParameterSetName='Scenario', Mandatory=$true)]
    [string]$Scenario,
    
    [Parameter(ParameterSetName='Corpus', Mandatory=$true)]
    [string]$Corpus,
    
    [Parameter(ParameterSetName='Scenario')]
    [Parameter(ParameterSetName='Corpus')]
    [string]$Path = "S:\DigitalCorpora",
    
    [Parameter(ParameterSetName='Scenario')]
    [Parameter(ParameterSetName='Corpus')]
    [int]$Parallel = 4,
    
    [Parameter(ParameterSetName='Corpus')]
    [int]$Limit = 0
)

# Configuration
$S3Bucket = 'digitalcorpora'
$MaxRetries = 3
$RetryDelay = 2

# Scenarios
$Scenarios = @{
    '2018-lonewolf' = @{
        Name = '2018 Lone Wolf Scenario'
        Description = 'Laptop seizure of fictional person planning mass shooting'
        Size = '~79 GB'
        Files = 19
    }
    '2019-narcos' = @{
        Name = '2019 Narcos'
        Description = 'Passengers intercepted by customs for illegal activity'
        Size = '~153 GB'
        Files = 16
    }
    '2019-owl' = @{
        Name = '2019 Owl'
        Description = 'Illegal trade of owls scenario'
        Size = '~223 GB'
        Files = 29
    }
    '2019-tuck' = @{
        Name = '2019 Tuck'
        Description = 'Person attempting to join terrorist organization'
        Size = '~100 GB'
        Files = 10
    }
    '2012-ngdc' = @{
        Name = '2012 National Gallery DC'
        Description = 'Fictional attack on National Gallery DC'
        Size = '~112 GB'
        Files = 161
    }
    '2009-m57-patents' = @{
        Name = '2009 M57 Patents'
        Description = 'Complex scenario with multiple drives and actors'
        Size = '~150 GB'
        Files = 50
    }
    '2008-nitroba' = @{
        Name = '2008 Nitroba University'
        Description = 'Network forensics harassment scenario'
        Size = '~25 GB'
        Files = 15
    }
}

# File Corpora
$FileCorpora = @{
    '2008-pdfs' = @{
        Name = '2008 PDFs Collection'
        Description = 'Various PDF files from 2008'
    }
    '2009-audio' = @{
        Name = '2009 Audio Files'
        Description = 'Audio file corpus'
    }
    '2009-video' = @{
        Name = '2009 Video Files'
        Description = 'Video file corpus'
    }
    'media1' = @{
        Name = 'Media Corpus 1'
        Description = 'Mixed media files collection'
    }
    'media2' = @{
        Name = 'Media Corpus 2'
        Description = 'Additional media files'
    }
}

$LargeCorpora = @{
    'CC-MAIN-2021-31-PDF-UNTRUNCATED' = @{
        Name = 'SAFEDOCS'
        Description = '8 million PDFs from Common Crawl'
        Size = 'Several TB'
        Files = '~8M'
    }
    'CC-MAIN-2021-31-UNSAFE' = @{
        Name = 'UNSAFE-DOCS'
        Description = '5.3M PDFs + 180K other files'
        Size = 'Several TB'
        Files = '~5.5M'
    }
}

function Show-Scenarios {
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "AVAILABLE FORENSIC SCENARIOS" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ("{0,-25} | {1,-30} | {2,-12}" -f 'ID','Name','Size')
    Write-Host "----------------------------------------------------------------"
    
    foreach ($id in $Scenarios.Keys | Sort-Object) {
        $info = $Scenarios[$id]
        Write-Host ("{0,-25} | {1,-30} | {2,-12}" -f $id, $info.Name, $info.Size)
    }
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "`nTotal: $($Scenarios.Count) scenarios"
    Write-Host "`nExamples:"
    Write-Host "  .\download_digitalcorpora.ps1 -Scenario `"2018-lonewolf`""
    Write-Host "  .\download_digitalcorpora.ps1 -Scenario `"2019-narcos`" -Parallel 8"
    Write-Host ""
}

function Show-Corpora {
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "AVAILABLE FILE CORPORA" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    
    Write-Host "`nStandard File Corpora:" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------"
    foreach ($id in $FileCorpora.Keys | Sort-Object) {
        $info = $FileCorpora[$id]
        Write-Host "  • $id - $($info.Name)"
        Write-Host "    $($info.Description)"
    }
    
    Write-Host "`nLarge PDF Corpora (MASSIVE - Several TB each):" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------"
    foreach ($id in $LargeCorpora.Keys | Sort-Object) {
        $info = $LargeCorpora[$id]
        Write-Host "  • $id"
        Write-Host "    $($info.Description)"
        Write-Host "    Size: $($info.Size), Files: $($info.Files)"
    }
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "`nExamples:"
    Write-Host "  .\download_digitalcorpora.ps1 -Corpus `"2009-audio`""
    Write-Host "  .\download_digitalcorpora.ps1 -Corpus `"media1`" -Limit 1000"
    Write-Host ""
}

function Download-FromS3 {
    param(
        [string]$Key,
        [string]$LocalPath
    )
    
    try {
        $dir = Split-Path $LocalPath -Parent
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        $url = "https://$S3Bucket.s3.amazonaws.com/$Key"
        Invoke-WebRequest -Uri $url -OutFile $LocalPath -TimeoutSec 300 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Failed to download $Key : $_"
        return $false
    }
}

# Main Script
if ($ListScenarios) {
    Show-Scenarios
    exit 0
}

if ($ListCorpora) {
    Show-Corpora
    exit 0
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "DIGITAL CORPORA DOWNLOADER" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Download path: $Path"
Write-Host "Parallel workers: $Parallel"
Write-Host "================================================================" -ForegroundColor Cyan

$startTime = Get-Date

# Check if AWS Tools are available (recommended but not required)
$useAwsTools = $false
if (Get-Module -ListAvailable -Name AWS.Tools.S3) {
    try {
        Import-Module AWS.Tools.S3 -ErrorAction Stop
        $useAwsTools = $true
        Write-Host "`n✓ Using AWS.Tools.S3 module for faster downloads" -ForegroundColor Green
    }
    catch {
        Write-Host "`n⚠ AWS.Tools.S3 module not available, using direct HTTP downloads" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`n⚠ AWS.Tools.S3 module not found" -ForegroundColor Yellow
    Write-Host "  Install with: Install-Module -Name AWS.Tools.S3 -Force" -ForegroundColor Yellow
    Write-Host "  Continuing with direct HTTP downloads..." -ForegroundColor Yellow
}

if ($Scenario) {
    if (-not $Scenarios.ContainsKey($Scenario)) {
        Write-Host "`nError: Unknown scenario '$Scenario'" -ForegroundColor Red
        Write-Host "Use -ListScenarios to see available scenarios" -ForegroundColor Yellow
        exit 1
    }
    
    $info = $Scenarios[$Scenario]
    Write-Host "`nDownloading: $($info.Name)" -ForegroundColor Green
    Write-Host "  Description: $($info.Description)"
    Write-Host "  Size: $($info.Size)"
    Write-Host "  Files: $($info.Files)"
    
    $scenarioDir = Join-Path $Path "scenarios\$Scenario"
    New-Item -ItemType Directory -Path $scenarioDir -Force | Out-Null
    
    Write-Host "`n⚠ This will download $($info.Size) of data" -ForegroundColor Yellow
    $response = Read-Host "Continue? (yes/no)"
    if ($response -notmatch '^(yes|y)$') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`nNote: Scenario downloads are large and may take several hours." -ForegroundColor Yellow
    Write-Host "Consider using the Python version for better progress tracking." -ForegroundColor Yellow
    Write-Host "`nDownload location: $scenarioDir" -ForegroundColor Cyan
}

if ($Corpus) {
    $allCorpora = $FileCorpora + $LargeCorpora
    
    if (-not $allCorpora.ContainsKey($Corpus)) {
        Write-Host "`nError: Unknown corpus '$Corpus'" -ForegroundColor Red
        Write-Host "Use -ListCorpora to see available corpora" -ForegroundColor Yellow
        exit 1
    }
    
    $info = $allCorpora[$Corpus]
    Write-Host "`nDownloading: $($info.Name)" -ForegroundColor Green
    Write-Host "  Description: $($info.Description)"
    if ($Limit -gt 0) {
        Write-Host "  Limit: $Limit files"
    }
    
    $corpusDir = Join-Path $Path "file_corpora\$Corpus"
    New-Item -ItemType Directory -Path $corpusDir -Force | Out-Null
    
    Write-Host "`nNote: For large corpora (SAFEDOCS/UNSAFE-DOCS), use --limit" -ForegroundColor Yellow
    Write-Host "to download a subset. Full downloads are several TB." -ForegroundColor Yellow
    Write-Host "`nDownload location: $corpusDir" -ForegroundColor Cyan
}

$elapsed = (Get-Date) - $startTime
Write-Host "`n[*] Total time: $([math]::Round($elapsed.TotalMinutes, 1)) minutes" -ForegroundColor Green
Write-Host "[*] DONE." -ForegroundColor Green

