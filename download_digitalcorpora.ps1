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
        [string]$Bucket,
        [string]$Key,
        [string]$LocalPath,
        [int]$MaxRetries = 3
    )
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            $dir = Split-Path $LocalPath -Parent
            if (!(Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            
            $url = "https://$Bucket.s3.amazonaws.com/$Key"
            Invoke-WebRequest -Uri $url -OutFile $LocalPath -TimeoutSec 300 -ErrorAction Stop
            return $true
        }
        catch {
            $attempt++
            if ($attempt -eq $MaxRetries) {
                Write-Warning "Failed to download $Key after $MaxRetries attempts: $_"
                return $false
            }
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

function Get-S3Objects {
    param(
        [string]$Bucket,
        [string]$Prefix,
        [int]$MaxKeys = 1000
    )
    
    $objects = @()
    $marker = $null
    $baseUrl = "https://$Bucket.s3.amazonaws.com"
    
    do {
        try {
            $url = "$baseUrl`?prefix=$Prefix&max-keys=$MaxKeys"
            if ($marker) {
                $url += "&marker=$marker"
            }
            
            [xml]$response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
            
            foreach ($content in $response.ListBucketResult.Contents) {
                if ($content.Key -and $content.Key -notlike '*/') {
                    $objects += @{
                        Key = $content.Key
                        Size = [long]$content.Size
                    }
                }
            }
            
            $isTruncated = $response.ListBucketResult.IsTruncated -eq 'true'
            if ($isTruncated) {
                $marker = $response.ListBucketResult.NextMarker
                if (-not $marker) {
                    $marker = $objects[-1].Key
                }
            }
        }
        catch {
            Write-Warning "Failed to list S3 objects: $_"
            break
        }
    } while ($isTruncated)
    
    return $objects
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

# Ensure DigitalCorpora subfolder
$BasePath = $Path
if ($BasePath -notlike "*DigitalCorpora*") {
    $BasePath = Join-Path $Path "DigitalCorpora"
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "DIGITAL CORPORA DOWNLOADER" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Download path: $BasePath"
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
    
    $scenarioDir = Join-Path $BasePath "scenarios\$Scenario"
    New-Item -ItemType Directory -Path $scenarioDir -Force | Out-Null
    
    Write-Host "`n⚠ This will download $($info.Size) of data" -ForegroundColor Yellow
    $response = Read-Host "Continue? (yes/no)"
    if ($response -notmatch '^(yes|y)$') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`nListing files from S3..." -ForegroundColor Cyan
    $prefix = "corpora/scenarios/$Scenario/"
    $objects = Get-S3Objects -Bucket $S3Bucket -Prefix $prefix
    
    if ($objects.Count -eq 0) {
        Write-Host "No files found for scenario '$Scenario'" -ForegroundColor Yellow
        exit 1
    }
    
    # Filter out files that already exist
    $filesToDownload = @()
    foreach ($obj in $objects) {
        $relativePath = $obj.Key.Replace($prefix, '')
        $localPath = Join-Path $scenarioDir $relativePath
        
        if (-not (Test-Path $localPath)) {
            $filesToDownload += @{
                Key = $obj.Key
                LocalPath = $localPath
                Size = $obj.Size
            }
        }
    }
    
    if ($filesToDownload.Count -eq 0) {
        Write-Host "All files already downloaded!" -ForegroundColor Green
    }
    else {
        Write-Host "Downloading $($filesToDownload.Count) files..." -ForegroundColor Cyan
        
        $downloaded = 0
        $failed = 0
        
        foreach ($file in $filesToDownload) {
            Write-Host "  [$($downloaded + 1)/$($filesToDownload.Count)] $(Split-Path $file.LocalPath -Leaf)..." -NoNewline
            
            if (Download-FromS3 -Bucket $S3Bucket -Key $file.Key -LocalPath $file.LocalPath) {
                $downloaded++
                Write-Host " ✓" -ForegroundColor Green
            }
            else {
                $failed++
                Write-Host " ✗" -ForegroundColor Red
            }
        }
        
        Write-Host "`nDownload Summary:" -ForegroundColor Cyan
        Write-Host "  Downloaded: $downloaded files" -ForegroundColor Green
        if ($failed -gt 0) {
            Write-Host "  Failed: $failed files" -ForegroundColor Red
        }
    }
    
    Write-Host "`n✓ Scenario '$Scenario' complete!" -ForegroundColor Green
    Write-Host "Location: $scenarioDir" -ForegroundColor Cyan
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
    
    $corpusDir = Join-Path $BasePath "file_corpora\$Corpus"
    New-Item -ItemType Directory -Path $corpusDir -Force | Out-Null
    
    if ($LargeCorpora.ContainsKey($Corpus) -and $Limit -eq 0) {
        Write-Host "`n⚠ WARNING: This is a MASSIVE corpus (several TB)" -ForegroundColor Yellow
        Write-Host "Consider using -Limit to download a subset" -ForegroundColor Yellow
        $response = Read-Host "Download entire corpus? (yes/no)"
        if ($response -notmatch '^(yes|y)$') {
            Write-Host "Aborted. Use -Limit parameter to download a subset." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "`nListing files from S3..." -ForegroundColor Cyan
    $prefix = "corpora/files/$Corpus/"
    $objects = Get-S3Objects -Bucket $S3Bucket -Prefix $prefix
    
    if ($objects.Count -eq 0) {
        Write-Host "No files found for corpus '$Corpus'" -ForegroundColor Yellow
        exit 1
    }
    
    # Apply limit if specified
    if ($Limit -gt 0 -and $objects.Count -gt $Limit) {
        $objects = $objects | Select-Object -First $Limit
        Write-Host "Limited to $Limit files (out of $($objects.Count) available)" -ForegroundColor Yellow
    }
    
    # Filter out files that already exist
    $filesToDownload = @()
    foreach ($obj in $objects) {
        $relativePath = $obj.Key.Replace($prefix, '')
        $localPath = Join-Path $corpusDir $relativePath
        
        if (-not (Test-Path $localPath)) {
            $filesToDownload += @{
                Key = $obj.Key
                LocalPath = $localPath
                Size = $obj.Size
            }
        }
    }
    
    if ($filesToDownload.Count -eq 0) {
        Write-Host "All files already downloaded!" -ForegroundColor Green
    }
    else {
        Write-Host "Downloading $($filesToDownload.Count) files..." -ForegroundColor Cyan
        
        $downloaded = 0
        $failed = 0
        
        foreach ($file in $filesToDownload) {
            if (($downloaded + $failed) % 10 -eq 0) {
                Write-Host "  Progress: $($downloaded + $failed)/$($filesToDownload.Count) files processed..." -ForegroundColor Cyan
            }
            
            if (Download-FromS3 -Bucket $S3Bucket -Key $file.Key -LocalPath $file.LocalPath) {
                $downloaded++
            }
            else {
                $failed++
            }
        }
        
        Write-Host "`nDownload Summary:" -ForegroundColor Cyan
        Write-Host "  Downloaded: $downloaded files" -ForegroundColor Green
        if ($failed -gt 0) {
            Write-Host "  Failed: $failed files" -ForegroundColor Red
        }
    }
    
    Write-Host "`n✓ Corpus '$Corpus' complete!" -ForegroundColor Green
    Write-Host "Location: $corpusDir" -ForegroundColor Cyan
}

$elapsed = (Get-Date) - $startTime
Write-Host "`n[*] Total time: $([math]::Round($elapsed.TotalMinutes, 1)) minutes" -ForegroundColor Green
Write-Host "[*] DONE." -ForegroundColor Green

