#Requires -Version 7.0
<#
.SYNOPSIS
    GovDocs1 Downloader - PowerShell version for Windows
    Downloads ~986,000 real government files from Digital Corpora

.DESCRIPTION
    Standalone script for downloading the GovDocs1 corpus with multiple tier options.
    Supports parallel downloads, resume capability, and custom paths.

.PARAMETER Tier
    Download tier: tiny, sample, small, medium, large, xlarge, complete

.PARAMETER Threads
    Custom number of threads to download

.PARAMETER Start
    Starting thread number (for resume or custom ranges)

.PARAMETER Path
    Custom download path (default: S:\GovDocs1)

.PARAMETER Parallel
    Number of parallel downloads (default: 4)

.PARAMETER List
    Display available tiers and exit

.EXAMPLE
    .\download_govdocs.ps1 -List
    
.EXAMPLE
    .\download_govdocs.ps1 -Tier sample
    
.EXAMPLE
    .\download_govdocs.ps1 -Tier complete -Path "D:\Data\GovDocs1"
    
.EXAMPLE
    .\download_govdocs.ps1 -Threads 100 -Start 50 -Parallel 8
#>

[CmdletBinding(DefaultParameterSetName='Tier')]
param(
    [Parameter(ParameterSetName='Tier')]
    [ValidateSet('tiny','sample','small','medium','large','xlarge','complete')]
    [string]$Tier,
    
    [Parameter(ParameterSetName='Custom', Mandatory=$true)]
    [int]$Threads,
    
    [Parameter(ParameterSetName='Custom')]
    [Parameter(ParameterSetName='Tier')]
    [int]$Start = 0,
    
    [Parameter(ParameterSetName='Custom')]
    [Parameter(ParameterSetName='Tier')]
    [string]$Path = "S:\GovDocs1",
    
    [Parameter(ParameterSetName='Custom')]
    [Parameter(ParameterSetName='Tier')]
    [int]$Parallel = 4,
    
    [Parameter(ParameterSetName='List')]
    [switch]$List
)

# Configuration
$BaseUrl = "https://downloads.digitalcorpora.org/corpora/files/govdocs1/zipfiles/"
$MaxRetries = 3
$RetryDelay = 2

# Download tiers
$DownloadTiers = @{
    'tiny' = @{
        Threads = 1
        Files = '~1,000'
        Size = '~540 MB'
        Description = 'Minimal test set'
    }
    'sample' = @{
        Threads = 10
        Files = '~10,000'
        Size = '~5.4 GB'
        Description = 'Good for development/testing'
    }
    'small' = @{
        Threads = 50
        Files = '~50,000'
        Size = '~27 GB'
        Description = 'Substantial test dataset'
    }
    'medium' = @{
        Threads = 100
        Files = '~100,000'
        Size = '~54 GB'
        Description = 'Large representative sample'
    }
    'large' = @{
        Threads = 250
        Files = '~250,000'
        Size = '~135 GB'
        Description = 'Quarter of full dataset'
    }
    'xlarge' = @{
        Threads = 500
        Files = '~500,000'
        Size = '~270 GB'
        Description = 'Half of full dataset'
    }
    'complete' = @{
        Threads = 1000
        Files = '~986,000'
        Size = '~540 GB'
        Description = 'Complete GovDocs1 corpus'
    }
}

function Show-Tiers {
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "GOVDOCS1 DOWNLOAD TIERS" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ("{0,-10} | {1,-8} | {2,-12} | {3,-12} | {4}" -f 'Tier','Threads','Files','Size','Description')
    Write-Host ("----------------------------------------------------------------")
    
    foreach ($tier in $DownloadTiers.Keys | Sort-Object) {
        $info = $DownloadTiers[$tier]
        Write-Host ("{0,-10} | {1,-8} | {2,-12} | {3,-12} | {4}" -f `
            $tier, $info.Threads, $info.Files, $info.Size, $info.Description)
    }
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "`nExamples:"
    Write-Host "  .\download_govdocs.ps1 -Tier sample"
    Write-Host "  .\download_govdocs.ps1 -Tier complete"
    Write-Host "  .\download_govdocs.ps1 -Threads 100 -Start 50 -Parallel 8"
    Write-Host ""
}

function Download-Thread {
    param(
        [int]$ThreadNum,
        [string]$BaseDir
    )
    
    $threadId = "{0:D3}.zip" -f $ThreadNum
    $url = $BaseUrl + $threadId
    $threadDir = Join-Path $BaseDir ("{0:D3}" -f $ThreadNum)
    
    # Check if already downloaded
    if (Test-Path $threadDir) {
        $fileCount = (Get-ChildItem $threadDir -File -ErrorAction SilentlyContinue).Count
        if ($fileCount -gt 0) {
            return @{
                Status = 'skipped'
                Thread = $ThreadNum
                Files = $fileCount
            }
        }
    }
    
    # Download with retry logic
    $attempt = 0
    $success = $false
    
    while (-not $success -and $attempt -lt $MaxRetries) {
        try {
            $attempt++
            
            # Download ZIP to temp file
            $tempZip = [System.IO.Path]::GetTempFileName()
            Invoke-WebRequest -Uri $url -OutFile $tempZip -TimeoutSec 120 -ErrorAction Stop
            
            # Extract
            New-Item -ItemType Directory -Path $threadDir -Force | Out-Null
            Expand-Archive -Path $tempZip -DestinationPath $threadDir -Force
            
            $fileCount = (Get-ChildItem $threadDir -File).Count
            Remove-Item $tempZip -Force
            
            return @{
                Status = 'success'
                Thread = $ThreadNum
                Files = $fileCount
            }
            
        } catch {
            if ($attempt -eq $MaxRetries) {
                if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
                return @{
                    Status = 'failed'
                    Thread = $ThreadNum
                    Files = 0
                    Error = $_.Exception.Message
                }
            }
            Start-Sleep -Seconds $RetryDelay
        }
    }
}

# Main Script
if ($List) {
    Show-Tiers
    exit 0
}

# Determine number of threads
if ($Tier) {
    $NumThreads = $DownloadTiers[$Tier].Threads
    $tierInfo = $DownloadTiers[$Tier]
    
    Write-Host "`nSelected Tier: $($Tier.ToUpper())" -ForegroundColor Green
    Write-Host "  Threads: $NumThreads"
    Write-Host "  Files: $($tierInfo.Files)"
    Write-Host "  Size: $($tierInfo.Size)"
    Write-Host "  $($tierInfo.Description)"
} else {
    $NumThreads = $Threads
    Write-Host "`nCustom Download: $NumThreads threads" -ForegroundColor Green
}

# Validate thread range
if ($Start -lt 0 -or $Start -ge 1000) {
    Write-Host "Error: -Start must be between 0 and 999 (got $Start)" -ForegroundColor Red
    exit 1
}

if (($Start + $NumThreads) -gt 1000) {
    $adjusted = 1000 - $Start
    Write-Host "Warning: Adjusting threads from $NumThreads to $adjusted (max available)" -ForegroundColor Yellow
    $NumThreads = $adjusted
}

# Add GovDocs1 subfolder unless already in path
if ($Path -notlike "*GovDocs1*") {
    $BasePath = Join-Path $Path "GovDocs1"
} else {
    $BasePath = $Path
}

# Display summary
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "GOVDOCS1 DOWNLOADER" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Download path:   $BasePath"
Write-Host "Thread range:    $("{0:D3}" -f $Start) to $("{0:D3}" -f ($Start + $NumThreads - 1))"
Write-Host "Parallel jobs:   $Parallel"
Write-Host "================================================================" -ForegroundColor Cyan

# Confirm for large downloads
if ($NumThreads -ge 250) {
    $sizeGB = [math]::Round($NumThreads * 0.54, 0)
    Write-Host "`n⚠️  WARNING: This will download approximately $sizeGB GB" -ForegroundColor Yellow
    $response = Read-Host "Continue? (yes/no)"
    if ($response -notmatch '^(yes|y)$') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Create base directory
if (-not (Test-Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
}

Write-Host "`nDownloading GovDocs1 Corpus" -ForegroundColor Green
Write-Host "  Threads: $Start to $($Start + $NumThreads - 1)"
Write-Host "  Target: $BasePath"
Write-Host ""

$startTime = Get-Date
$successful = 0
$failed = 0
$skipped = 0

# Create thread range
$threadRange = $Start..($Start + $NumThreads - 1)

# Download using parallel jobs
$results = $threadRange | ForEach-Object -Parallel {
    $BaseUrl = $using:BaseUrl
    $MaxRetries = $using:MaxRetries
    $RetryDelay = $using:RetryDelay
    $BaseDir = $using:BasePath
    $ThreadNum = $_
    
    $threadId = "{0:D3}.zip" -f $ThreadNum
    $url = $BaseUrl + $threadId
    $threadDir = Join-Path $BaseDir ("{0:D3}" -f $ThreadNum)
    
    # Check if already downloaded
    if (Test-Path $threadDir) {
        $fileCount = (Get-ChildItem $threadDir -File -ErrorAction SilentlyContinue).Count
        if ($fileCount -gt 0) {
            return @{
                Status = 'skipped'
                Thread = $ThreadNum
                Files = $fileCount
            }
        }
    }
    
    # Download with retry logic
    $attempt = 0
    $success = $false
    
    while (-not $success -and $attempt -lt $MaxRetries) {
        try {
            $attempt++
            
            # Download ZIP to temp file
            $tempZip = [System.IO.Path]::GetTempFileName()
            Invoke-WebRequest -Uri $url -OutFile $tempZip -TimeoutSec 120 -ErrorAction Stop
            
            # Extract
            New-Item -ItemType Directory -Path $threadDir -Force | Out-Null
            Expand-Archive -Path $tempZip -DestinationPath $threadDir -Force
            
            $fileCount = (Get-ChildItem $threadDir -File).Count
            Remove-Item $tempZip -Force
            
            return @{
                Status = 'success'
                Thread = $ThreadNum
                Files = $fileCount
            }
            
        } catch {
            if ($attempt -eq $MaxRetries) {
                if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
                return @{
                    Status = 'failed'
                    Thread = $ThreadNum
                    Files = 0
                    Error = $_.Exception.Message
                }
            }
            Start-Sleep -Seconds $RetryDelay
        }
    }
} -ThrottleLimit $Parallel

# Process results
foreach ($result in $results) {
    switch ($result.Status) {
        'success' {
            Write-Host ("   ✓ Thread {0:D3}: {1} files extracted" -f $result.Thread, $result.Files) -ForegroundColor Green
            $successful++
        }
        'skipped' {
            $skipped++
        }
        'failed' {
            Write-Host ("   ✗ Thread {0:D3}: Failed" -f $result.Thread) -ForegroundColor Red
            $failed++
        }
    }
}

# Calculate statistics
$totalFiles = 0
$totalSize = 0

Get-ChildItem -Path $BasePath -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $totalFiles++
    $totalSize += $_.Length
}

$sizeGB = [math]::Round($totalSize / 1GB, 2)
$elapsed = (Get-Date) - $startTime

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "DOWNLOAD SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Successful:  $successful threads"
Write-Host "Failed:      $failed threads"
Write-Host "Skipped:     $skipped threads (already downloaded)"
Write-Host "Total:       $($successful + $skipped) threads"
Write-Host "Location:    $BasePath"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "`nActual Data:"
Write-Host "  Files: $($totalFiles.ToString('N0'))"
Write-Host "  Size:  $sizeGB GB"
Write-Host "`n[*] Total time: $([math]::Round($elapsed.TotalMinutes, 1)) minutes"
Write-Host "[*] DONE." -ForegroundColor Green

