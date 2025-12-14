#Requires -Version 7.0
<#
.SYNOPSIS
    SAFEDOCS Downloader - PowerShell version for Windows
    Downloads ~8 million PDFs from Common Crawl via Digital Corpora

.DESCRIPTION
    Standalone script for downloading the SAFEDOCS corpus (CC-MAIN-2021-31-PDF-UNTRUNCATED).
    Supports multiple tier options, parallel downloads, and custom paths.

.PARAMETER Tier
    Download tier: tiny, sample, small, medium, large, xlarge, xxlarge, complete

.PARAMETER Limit
    Custom file limit (overrides tier)

.PARAMETER Path
    Custom download path (default: S:\SAFEDOCS)

.PARAMETER Parallel
    Number of parallel downloads (default: 4, recommended: 4-8)

.PARAMETER List
    Display available tiers and exit

.EXAMPLE
    .\download_safedocs.ps1 -List
    
.EXAMPLE
    .\download_safedocs.ps1 -Tier sample
    
.EXAMPLE
    .\download_safedocs.ps1 -Tier medium -Parallel 8
    
.EXAMPLE
    .\download_safedocs.ps1 -Tier complete -Path "D:\Data\SAFEDOCS"
    
.EXAMPLE
    .\download_safedocs.ps1 -Limit 50000 -Parallel 8
#>

[CmdletBinding(DefaultParameterSetName='Tier')]
param(
    [Parameter(ParameterSetName='Tier')]
    [ValidateSet('tiny','sample','small','medium','large','xlarge','xxlarge','complete')]
    [string]$Tier,
    
    [Parameter(ParameterSetName='Limit', Mandatory=$true)]
    [int]$Limit,
    
    [Parameter(ParameterSetName='Limit')]
    [Parameter(ParameterSetName='Tier')]
    [string]$Path = "S:\SAFEDOCS",
    
    [Parameter(ParameterSetName='Limit')]
    [Parameter(ParameterSetName='Tier')]
    [int]$Parallel = 4,
    
    [Parameter(ParameterSetName='List')]
    [switch]$List
)

# Configuration
$S3Bucket = 'digitalcorpora'
$S3Prefix = 'corpora/files/CC-MAIN-2021-31-PDF-UNTRUNCATED/'
$MaxRetries = 3

# Download tiers
$DownloadTiers = @{
    'tiny' = @{
        Files = 1000
        Size = '~100 MB'
        Description = 'Minimal test set'
    }
    'sample' = @{
        Files = 10000
        Size = '~1 GB'
        Description = 'Good for development/testing'
    }
    'small' = @{
        Files = 50000
        Size = '~5 GB'
        Description = 'Substantial test dataset'
    }
    'medium' = @{
        Files = 100000
        Size = '~10 GB'
        Description = 'Large representative sample'
    }
    'large' = @{
        Files = 500000
        Size = '~50 GB'
        Description = 'Large dataset'
    }
    'xlarge' = @{
        Files = 1000000
        Size = '~100 GB'
        Description = 'Million PDF sample'
    }
    'xxlarge' = @{
        Files = 2000000
        Size = '~200 GB'
        Description = 'Two million PDFs'
    }
    'complete' = @{
        Files = 8000000
        Size = '~800 GB'
        Description = 'Complete SAFEDOCS corpus (8M PDFs)'
    }
}

# Helper Functions
function Get-S3Objects {
    param(
        [string]$Bucket,
        [string]$Prefix,
        [int]$MaxFiles = $null
    )
    
    $objects = @()
    $marker = $null
    $baseUrl = "https://$Bucket.s3.amazonaws.com"
    
    Write-Host "   -> Listing files from s3://$Bucket/$Prefix"
    
    do {
        try {
            $url = "$baseUrl`?prefix=$Prefix&max-keys=1000"
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
                    
                    if ($MaxFiles -and $objects.Count -ge $MaxFiles) {
                        Write-Host "   -> Reached limit of $MaxFiles files"
                        return $objects
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
                return $false
            }
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

# Show available tiers
if ($List) {
    Write-Host "`nSAFEDOCS Download Tiers:" -ForegroundColor Cyan
    Write-Host "=" * 70
    foreach ($tierName in $DownloadTiers.Keys | Sort-Object) {
        $tierInfo = $DownloadTiers[$tierName]
        Write-Host ("{0,-12} : {1,9} files ({2,-10}) - {3}" -f `
            $tierName, $tierInfo.Files.ToString('N0'), $tierInfo.Size, $tierInfo.Description)
    }
    Write-Host "=" * 70
    Write-Host "`nSource: Common Crawl (CC-MAIN-2021-31-PDF-UNTRUNCATED)"
    Write-Host "Total: ~8 million PDFs from Common Crawl"
    exit 0
}

# Validate parameters
if (-not $Tier -and -not $Limit) {
    Write-Error "Must specify either -Tier or -Limit"
    exit 1
}

if ($Tier -and $Limit) {
    Write-Error "Cannot specify both -Tier and -Limit"
    exit 1
}

# Determine file limit
if ($Tier) {
    $FileLimit = $DownloadTiers[$Tier].Files
    $SizeEstimate = $DownloadTiers[$Tier].Size
    $Description = $DownloadTiers[$Tier].Description
}
else {
    $FileLimit = $Limit
    $SizeEstimate = "~$([math]::Round($Limit / 10000, 1)) GB"
    $Description = "Custom limit"
}

# Add SAFEDOCS subfolder unless already in path
if ($Path -notlike "*SAFEDOCS*") {
    $BaseDir = Join-Path $Path "SAFEDOCS"
}
else {
    $BaseDir = $Path
}

# Create directory
if (!(Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

# Display configuration
Write-Host "`n" ("=" * 60) -ForegroundColor Cyan
Write-Host "SAFEDOCS DOWNLOADER" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "Source:           Common Crawl (CC-MAIN-2021-31-PDF-UNTRUNCATED)"
Write-Host "Total Available:  ~8 million PDFs"
Write-Host "Download Path:    $BaseDir"
if ($Tier) {
    Write-Host "Tier:             $Tier ($Description)"
}
Write-Host "Files to Download: $($FileLimit.ToString('N0'))"
Write-Host "Estimated Size:   $SizeEstimate"
Write-Host "Parallel Workers: $Parallel"
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# Confirm large downloads
if ($FileLimit -gt 100000) {
    $response = Read-Host "This will download $($FileLimit.ToString('N0')) files (~$SizeEstimate). Continue? (yes/no)"
    if ($response -notlike 'y*') {
        Write-Host "Download cancelled."
        exit 0
    }
}

# List files from S3
Write-Host "Listing files from S3..."
$files = Get-S3Objects -Bucket $S3Bucket -Prefix $S3Prefix -MaxFiles $FileLimit

if ($files.Count -eq 0) {
    Write-Error "No files found to download"
    exit 1
}

Write-Host "Found $($files.Count.ToString('N0')) files to download`n"

# Download files with progress
$stats = @{
    Downloaded = 0
    Skipped = 0
    Failed = 0
}

$completed = 0
$total = $files.Count

Write-Host "Downloading files..." -ForegroundColor Green

# Process in batches for parallel downloads
$batchSize = $Parallel
for ($i = 0; $i -lt $total; $i += $batchSize) {
    $batch = $files[$i..[Math]::Min($i + $batchSize - 1, $total - 1)]
    
    $batch | ForEach-Object -Parallel {
        $file = $_
        $bucket = $using:S3Bucket
        $baseDir = $using:BaseDir
        $prefix = $using:S3Prefix
        $maxRetries = $using:MaxRetries
        
        # Calculate local path
        $relPath = $file.Key.Replace($prefix, '')
        $localPath = Join-Path $baseDir $relPath
        
        # Check if exists
        if (Test-Path $localPath) {
            return @{ Status = 'skipped'; Key = $file.Key }
        }
        
        # Download function (copied inside parallel block)
        function Download-File {
            param($Bucket, $Key, $LocalPath, $MaxRetries)
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
                    if ($attempt -lt $MaxRetries) {
                        Start-Sleep -Seconds 2
                    }
                }
            }
            return $false
        }
        
        $success = Download-File -Bucket $bucket -Key $file.Key -LocalPath $localPath -MaxRetries $maxRetries
        
        if ($success) {
            return @{ Status = 'downloaded'; Key = $file.Key }
        }
        else {
            return @{ Status = 'failed'; Key = $file.Key }
        }
    } -ThrottleLimit $Parallel | ForEach-Object {
        $result = $_
        
        switch ($result.Status) {
            'downloaded' { $stats.Downloaded++ }
            'skipped' { $stats.Skipped++ }
            'failed' { $stats.Failed++ }
        }
        
        $completed++
        $pct = [math]::Round(($completed / $total) * 100, 1)
        Write-Progress -Activity "Downloading SAFEDOCS" -Status "$completed / $total files ($pct%)" `
            -PercentComplete $pct -CurrentOperation "DL: $($stats.Downloaded) | Skip: $($stats.Skipped) | Fail: $($stats.Failed)"
    }
}

Write-Progress -Activity "Downloading SAFEDOCS" -Completed

# Summary
Write-Host "`n" ("=" * 60) -ForegroundColor Green
Write-Host "DOWNLOAD SUMMARY" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host "Downloaded:    $($stats.Downloaded.ToString('N0')) files"
Write-Host "Skipped:       $($stats.Skipped.ToString('N0')) files (already exist)"
Write-Host "Failed:        $($stats.Failed.ToString('N0')) files"
Write-Host "Total:         $($files.Count.ToString('N0')) files"
Write-Host "Location:      $BaseDir"
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host ""

