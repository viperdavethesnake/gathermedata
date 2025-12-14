#Requires -Version 7.0
<#
.SYNOPSIS
    Enterprise Data Sources Downloader - PowerShell Version
.DESCRIPTION
    Downloads data from multiple public sources for NAS testing:
    - Amazon warehouse images
    - SEC financial statements
    - Federal Register documents
    - Federal contracts (USASpending.gov)
    
    For specialized downloads:
    - GovDocs1: use download_govdocs.ps1 (7 tiers)
    - SAFEDOCS: use download_safedocs.ps1 (8M PDFs)
    - UNSAFE-DOCS: use download_unsafedocs.ps1 (5.3M+ files)
    - Forensic scenarios: use download_digitalcorpora_scenarios.ps1
    
    Requires PowerShell 7.0 or later (latest: 7.5.4).
.PARAMETER Mode
    Download mode: 'sample' (small batch) or 'all' (large batch)
.PARAMETER Path
    Download path (default: S:\Shared)
.EXAMPLE
    .\download_enterprise_sources.ps1 -Mode sample
.EXAMPLE
    .\download_enterprise_sources.ps1 -Mode all -Path "D:\TestData"
#>

param(
    [Parameter()]
    [ValidateSet('sample', 'all')]
    [string]$Mode = 'sample',
    
    [Parameter()]
    [string]$Path = "S:\Shared"
)

# --- CONFIGURATION ---
# Add EnterpriseData subfolder unless already in path
if ($Path -notlike "*EnterpriseData*" -and $Path -notlike "*Shared*" -and $Path -notlike "*nexus*") {
    $BaseDir = Join-Path $Path "EnterpriseData"
} else {
    $BaseDir = $Path
}

$Dirs = @{
    FINANCE = Join-Path $BaseDir "1_Federal_Contracts_USASpending"
    WAREHOUSE_IMG = Join-Path $BaseDir "2_Warehouse_Images_Amazon"
    WAREHOUSE_LOGS = Join-Path $BaseDir "3_Financial_Statements_SEC"
    REGULATORY = Join-Path $BaseDir "4_Regulatory_Docs_FederalRegister"
}

$MaxRetries = 3
$RetryDelay = 2

# Create directories
foreach ($dir in $Dirs.Values) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# --- HELPER FUNCTIONS ---
function Invoke-RetryDownload {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @(),
        [int]$MaxAttempts = $MaxRetries,
        [int]$Delay = $RetryDelay
    )
    
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        try {
            if ($ArgumentList.Count -gt 0) {
                return & $ScriptBlock @ArgumentList
            } else {
                return & $ScriptBlock
            }
        }
        catch {
            if ($i -eq ($MaxAttempts - 1)) {
                Write-Warning "Failed after $MaxAttempts attempts: $_"
                return $null
            }
            Write-Warning "Attempt $($i + 1) failed: $_. Retrying..."
            Start-Sleep -Seconds $Delay
        }
    }
}

# --- 1. FEDERAL CONTRACTS (USASpending.gov) ---
function Get-FederalContracts {
    param(
        [string]$Mode,
        [hashtable]$Dirs,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 2
    )
    
    Write-Host "`n[1/4] Starting Federal Contract Data (USASpending.gov)..."
    Write-Host "   -> Downloading structured financial records (JSON format)"
    
    $apiUrl = "https://api.usaspending.gov/api/v2/search/spending_by_award/"
    $limit = if ($Mode -eq 'sample') { 50 } else { 500 }
    
    $downloaded = 0
    $page = 1
    
    while ($downloaded -lt $limit) {
        $body = @{
            filters = @{
                award_type_codes = @("A", "B", "C", "D")
                time_period = @(
                    @{
                        start_date = "2023-01-01"
                        end_date = "2023-12-31"
                    }
                )
            }
            fields = @(
                "Award ID", "Recipient Name", "Start Date", "End Date",
                "Award Amount", "Total Outlays", "Description",
                "Awarding Agency", "Awarding Sub Agency", "Contract Award Type"
            )
            limit = [Math]::Min(100, $limit - $downloaded)
            page = $page
        }
        
        $response = Invoke-RetryDownload -ScriptBlock {
            param($body, $apiUrl)
            $jsonBody = $body | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Uri $apiUrl -Method Post -Body $jsonBody -ContentType "application/json" -TimeoutSec 30
        } -ArgumentList $body, $apiUrl -MaxAttempts $MaxRetries -Delay $RetryDelay
        
        if (-not $response -or -not $response.results) { break }
        
        foreach ($contract in $response.results) {
            if ($downloaded -ge $limit) { break }
            
            $awardId = if ($contract.'Award ID') { $contract.'Award ID' } else { "contract_$downloaded" }
            $awardId = ($awardId -replace '[^a-zA-Z0-9_-]', '')
            if ($awardId.Length -gt 50) {
                $awardId = $awardId.Substring(0, 50)
            }
            if ([string]::IsNullOrWhiteSpace($awardId)) {
                $awardId = "contract_$downloaded"
            }
            
            $filePath = Join-Path $Dirs.FINANCE "$awardId.json"
            
            if (-not (Test-Path $filePath)) {
                try {
                    $contract | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -ErrorAction Stop
                    $downloaded++
                }
                catch {
                    Write-Warning "Failed to save contract $awardId : $_"
                }
            } else {
                $downloaded++
            }
        }
        
        $page++
        
        # Safety check to avoid infinite loop
        if ($page -gt 100) { break }
    }
    
    Write-Host "   -> Downloaded $downloaded contract records"
}

# --- 3. WAREHOUSE IMAGES (Amazon) ---
function Get-AmazonImages {
    param(
        [string]$Mode,
        [hashtable]$Dirs
    )
    
    Write-Host "`n[3/5] Starting Amazon Bin Image Download..."
    Write-Host "   -> Amazon Bin Images: 536,434 JPG images available"
    
    # Sample: 50 images, All: 50,000 images (subset of 536K available)
    $targetCount = if ($Mode -eq 'sample') { 50 } else { 50000 }
    
    try {
        $bucket = 'aft-vbi-pds'
        $prefix = 'bin-images/'
        $downloaded = 0
        $baseUrl = "https://$bucket.s3.amazonaws.com"
        
        Write-Host "   -> Listing images from S3 bucket..."
        
        # List objects using HTTP (no AWS module needed)
        try {
            [xml]$response = Invoke-RestMethod -Uri "$baseUrl`?prefix=$prefix&max-keys=$targetCount" -Method Get -TimeoutSec 30
        }
        catch {
            Write-Warning "Failed to list S3 objects: $_"
            Write-Host "   -> Note: AWS.Tools.S3 module is installed but anonymous access failed"
            Write-Host "   -> Use Python version for reliable S3 access"
            return
        }
        
        $imageKeys = @()
        foreach ($content in $response.ListBucketResult.Contents) {
            if ($content.Key -match '\.jpg$') {
                $imageKeys += $content.Key
                if ($imageKeys.Count -ge $targetCount) { break }
            }
        }
        
        Write-Host "   -> Found $($imageKeys.Count) images to download"
        
        foreach ($key in $imageKeys) {
            $fileName = Split-Path $key -Leaf
            $localPath = Join-Path $Dirs.WAREHOUSE_IMG $fileName
            
            if (-not (Test-Path $localPath)) {
                try {
                    $url = "$baseUrl/$key"
                    Invoke-WebRequest -Uri $url -OutFile $localPath -TimeoutSec 60 -ErrorAction Stop
                    $downloaded++
                    
                    if ($downloaded % 100 -eq 0) {
                        Write-Host "   -> Downloaded $downloaded images..."
                    }
                }
                catch {
                    Write-Warning "Failed to download $fileName : $_"
                }
            } else {
                $downloaded++
            }
        }
        
        Write-Host "   -> Downloaded $downloaded images"
    }
    catch {
        Write-Warning "Failed to download Amazon images: $_"
        Write-Host "   -> Use Python version for reliable S3 access"
    }
}

# --- 4. SEC FINANCIAL STATEMENTS ---
function Get-SECFinancials {
    param(
        [string]$Mode,
        [hashtable]$Dirs,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 2
    )
    
    Write-Host "`n[3/4] Fetching SEC Financial Statement Data..."
    Write-Host "   -> SEC EDGAR: 64 quarters available (2009 Q1 to 2024 Q4)"
    Write-Host "   -> Note: SEC may return 403 errors due to rate limiting"
    
    # Sample: 1 quarter, All: 20 quarters (5 years)
    if ($Mode -eq 'sample') {
        $quarters = @('2024q3')
    } else {
        # Last 5 years (20 quarters)
        $quarters = @()
        for ($year = 2024; $year -ge 2020; $year--) {
            $quarters += "$($year)q4"
            $quarters += "$($year)q3"
            $quarters += "$($year)q2"
            $quarters += "$($year)q1"
        }
    }
    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    foreach ($quarter in $quarters) {
        $url = "https://www.sec.gov/files/dera/data/financial-statement-data-sets/$quarter.zip"
        $extractDir = Join-Path $Dirs.WAREHOUSE_LOGS $quarter
        
        if (Test-Path $extractDir) {
            $fileCount = (Get-ChildItem -Path $extractDir -File -ErrorAction SilentlyContinue).Count
            if ($fileCount -gt 0) {
                Write-Host "   -> $quarter already extracted ($fileCount files)"
                continue
            }
        }
        
        Write-Host "   -> Downloading $quarter financial statements..."
        
        $result = Invoke-RetryDownload -ScriptBlock {
            param($quarter, $url, $headers, $extractDir)
            $tempZip = Join-Path $env:TEMP "$quarter.zip"
            try {
                Invoke-WebRequest -Uri $url -OutFile $tempZip -Headers $headers -TimeoutSec 120
                
                # Extract
                New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
                Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force
                $fileCount = (Get-ChildItem -Path $extractDir -File -ErrorAction SilentlyContinue).Count
                Write-Host "      [+] Extracted $fileCount CSV files"
                return $true
            }
            finally {
                if (Test-Path $tempZip) {
                    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                }
            }
        } -ArgumentList $quarter, $url, $headers, $extractDir -MaxAttempts $MaxRetries -Delay $RetryDelay
        
        if ($Mode -eq 'sample') { break }
    }
}

# --- 5. FEDERAL REGISTER ---
function Get-FederalRegister {
    param(
        [string]$Mode,
        [hashtable]$Dirs,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 2
    )
    
    Write-Host "`n[4/4] Fetching Federal Register Documents..."
    
    $apiUrl = "https://www.federalregister.gov/api/v1/documents.json"
    $limit = if ($Mode -eq 'sample') { 200 } else { 10000 }
    $docTypes = @('RULE', 'PRORULE', 'NOTICE')
    
    $downloaded = 0
    $perPage = 100
    
    Write-Host "   -> Target: $limit documents (30,000+ available in Federal Register)"
    
    foreach ($docType in $docTypes) {
        if ($downloaded -ge $limit) { break }
        
        $page = 1
        $docsForThisType = 0
        
        while ($downloaded -lt $limit) {
            # Build URL with properly encoded parameters
            $queryString = "per_page=$perPage&page=$page&order=newest&conditions[type][]=$docType"
            $queryString += "&fields[]=title&fields[]=document_number&fields[]=pdf_url&fields[]=type"
            $fullUrl = "$apiUrl`?$queryString"
            
            $response = Invoke-RetryDownload -ScriptBlock {
                param($fullUrl)
                Invoke-RestMethod -Uri $fullUrl -Method Get -TimeoutSec 30
            } -ArgumentList $fullUrl -MaxAttempts $MaxRetries -Delay $RetryDelay
            
            if (-not $response -or -not $response.results) { break }
            
            foreach ($doc in $response.results) {
                if ($downloaded -ge $limit) { break }
                
                $pdfUrl = $doc.pdf_url
                if (-not $pdfUrl) { continue }
                
                $docNum = if ($doc.document_number) { $doc.document_number } else { "doc_$downloaded" }
                $docNum = ($docNum -replace '[^a-zA-Z0-9_-]', '')
                if ([string]::IsNullOrWhiteSpace($docNum)) {
                    $docNum = "doc_$downloaded"
                }
                
                $filePath = Join-Path $Dirs.REGULATORY "$docNum.pdf"
                
                if (Test-Path $filePath) {
                    $downloaded++
                    $docsForThisType++
                    continue
                }
                
                $result = Invoke-RetryDownload -ScriptBlock {
                    param($pdfUrl, $filePath)
                    Invoke-WebRequest -Uri $pdfUrl -OutFile $filePath -TimeoutSec 30
                    return $true
                } -ArgumentList $pdfUrl, $filePath -MaxAttempts $MaxRetries -Delay $RetryDelay
                
                if ($result) {
                    $downloaded++
                    $docsForThisType++
                }
                
                # Delay to avoid rate limiting
                Start-Sleep -Milliseconds 200
            }
            
            if ($downloaded -ge $limit) { break }
            
            # Move to next page
            $page++
            Start-Sleep -Milliseconds 500
            
            # Safety check
            if ($page -gt 100) { break }
        }
        
        Write-Host "      [+] Downloaded $docsForThisType $docType documents"
    }
    
    Write-Host "   -> Downloaded $downloaded regulatory documents total"
}

# --- SUMMARY FUNCTION ---
function Show-Summary {
    param([hashtable]$Dirs, [string]$BaseDir)
    
    Write-Host "`n============================================================"
    Write-Host "DOWNLOAD SUMMARY"
    Write-Host "============================================================"
    
    foreach ($name in $Dirs.Keys) {
        $path = $Dirs[$name]
        if (Test-Path $path) {
            $files = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue).Count
            $size = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            $sizeMB = if ($size) { [math]::Round($size / 1MB, 1) } else { 0 }
            
            Write-Host ("{0,-15} | {1,6} files | {2,8:N1} MB" -f $name, $files, $sizeMB)
        } else {
            Write-Host ("{0,-15} | {1,6} files | {2,8:N1} MB" -f $name, 0, 0)
        }
    }
    
    Write-Host "============================================================"
    Write-Host "Data location: $BaseDir"
}

# --- MAIN EXECUTION ---
Write-Host "============================================================"
Write-Host "ENTERPRISE DATA LOADER - PowerShell Edition"
Write-Host "============================================================"
Write-Host "Mode: $($Mode.ToUpper())"
Write-Host "Target: $BaseDir"
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "============================================================"

Write-Host "`nStarting downloads...`n"

# Run downloads sequentially (more reliable than parallel in PowerShell)
Get-FederalContracts -Mode $Mode -Dirs $Dirs -MaxRetries $MaxRetries -RetryDelay $RetryDelay
Get-SECFinancials -Mode $Mode -Dirs $Dirs -MaxRetries $MaxRetries -RetryDelay $RetryDelay
Get-FederalRegister -Mode $Mode -Dirs $Dirs -MaxRetries $MaxRetries -RetryDelay $RetryDelay
Get-AmazonImages -Mode $Mode -Dirs $Dirs

# Show summary
Show-Summary -Dirs $Dirs -BaseDir $BaseDir

Write-Host "`n[*] DONE."
