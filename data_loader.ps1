<#
.SYNOPSIS
    Enterprise NAS Data Loader - PowerShell Version
.DESCRIPTION
    Downloads real-world data from public repositories for testing.
    Requires PowerShell 7.0 or later (latest: 7.5.4).
.PARAMETER Mode
    Download mode: 'sample' (small batch) or 'all' (large batch)
.PARAMETER Path
    Download path (default: S:\Shared)
.EXAMPLE
    .\data_loader.ps1 -Mode sample
.EXAMPLE
    .\data_loader.ps1 -Mode all -Path "D:\TestData"
#>

param(
    [Parameter()]
    [ValidateSet('sample', 'all')]
    [string]$Mode = 'sample',
    
    [Parameter()]
    [string]$Path = "S:\Shared"
)

# --- CONFIGURATION ---
$BaseDir = $Path
$Dirs = @{
    OFFICE = Join-Path $BaseDir "1_Office_Docs_GovDocs"
    FINANCE = Join-Path $BaseDir "2_Federal_Contracts_USASpending"
    WAREHOUSE_IMG = Join-Path $BaseDir "3_Warehouse_Images_Amazon"
    WAREHOUSE_LOGS = Join-Path $BaseDir "4_Financial_Statements_SEC"
    REGULATORY = Join-Path $BaseDir "5_Regulatory_Docs_FederalRegister"
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
        [int]$MaxAttempts = $MaxRetries
    )
    
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($i -eq ($MaxAttempts - 1)) {
                Write-Warning "Failed after $MaxAttempts attempts: $_"
                return $null
            }
            Write-Warning "Attempt $($i + 1) failed: $_. Retrying..."
            Start-Sleep -Seconds $RetryDelay
        }
    }
}

# --- 1. OFFICE DOCUMENTS (GovDocs1) ---
function Get-GovDocs {
    param([string]$Mode)
    
    Write-Host "`n[1/5] Starting GovDocs Download (Real Office Files)..."
    Write-Host "   -> GovDocs1 corpus: ~986,000 files in 1000 ZIP files"
    
    $baseUrl = "https://downloads.digitalcorpora.org/corpora/files/govdocs1/zipfiles/"
    # Sample: 2 threads, All: 1000 threads (complete corpus)
    $threads = if ($Mode -eq 'all') { 0..999 } else { @(0, 1) }
    
    foreach ($i in $threads) {
        $threadId = "{0:D3}.zip" -f $i
        $url = $baseUrl + $threadId
        $extractPath = $Dirs.OFFICE
        
        Write-Host "   -> Downloading Thread $threadId..."
        
        Invoke-RetryDownload -ScriptBlock {
            $webClient = New-Object System.Net.WebClient
            $tempFile = [System.IO.Path]::GetTempFileName()
            
            $webClient.DownloadFile($url, $tempFile)
            
            # Extract ZIP
            Expand-Archive -Path $tempFile -DestinationPath $extractPath -Force
            Remove-Item $tempFile -Force
            
            Write-Host "      [+] Extracted thread $threadId"
        }
        
        if ($Mode -eq 'sample') { break }
    }
}

# --- 2. FEDERAL CONTRACTS (USASpending.gov) ---
function Get-FederalContracts {
    param([string]$Mode)
    
    Write-Host "`n[2/5] Starting Federal Contract Data (USASpending.gov)..."
    Write-Host "   -> Downloading structured financial records (JSON format)"
    
    $apiUrl = "https://api.usaspending.gov/api/v2/search/spending_by_award/"
    $limit = if ($Mode -eq 'sample') { 50 } else { 500 }
    
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
        limit = 100
        page = 1
    } | ConvertTo-Json -Depth 10
    
    $downloaded = 0
    $page = 1
    
    while ($downloaded -lt $limit) {
        $bodyObj = $body | ConvertFrom-Json
        $bodyObj.page = $page
        $bodyObj.limit = [Math]::Min(100, $limit - $downloaded)
        $currentBody = $bodyObj | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $currentBody -ContentType "application/json"
        
        if (-not $response.results) { break }
        
        foreach ($contract in $response.results) {
            if ($downloaded -ge $limit) { break }
            
            $awardId = $contract.'Award ID' -replace '[^a-zA-Z0-9_-]', ''
            $awardId = $awardId.Substring(0, [Math]::Min(50, $awardId.Length))
            $filePath = Join-Path $Dirs.FINANCE "$awardId.json"
            
            $contract | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath
            $downloaded++
        }
        
        $page++
    }
    
    Write-Host "   -> Downloaded $downloaded contract records"
}

# --- 3. WAREHOUSE IMAGES (Amazon) ---
function Get-AmazonImages {
    param([string]$Mode)
    
    Write-Host "`n[3/5] Starting Amazon Bin Image Download..."
    Write-Host "   -> Amazon Bin Images: 536,434 JPG images available"
    
    # Sample: 50 images, All: 50,000 images (subset of 536K available)
    $targetCount = if ($Mode -eq 'sample') { 50 } else { 50000 }
    
    # Check if AWS Tools module is available
    if (-not (Get-Module -ListAvailable -Name AWS.Tools.S3)) {
        Write-Host "   -> AWS.Tools.S3 module not found"
        Write-Host "   -> Install with: Install-Module -Name AWS.Tools.S3 -Force"
        Write-Host "   -> Skipping Amazon images (use Python version for automatic S3 access)"
        return
    }
    
    try {
        Import-Module AWS.Tools.S3 -ErrorAction Stop
        
        $bucket = 'aft-vbi-pds'
        $prefix = 'bin-images/'
        $downloaded = 0
        
        $objects = Get-S3Object -BucketName $bucket -KeyPrefix $prefix -NoAutoIteration | 
                   Where-Object { $_.Key -match '\.jpg$' } | 
                   Select-Object -First $targetCount
        
        Write-Host "   -> Found $($objects.Count) images to download"
        
        foreach ($obj in $objects) {
            if ($downloaded -ge $targetCount) { break }
            
            $fileName = Split-Path $obj.Key -Leaf
            $localPath = Join-Path $Dirs.WAREHOUSE_IMG $fileName
            
            if (-not (Test-Path $localPath)) {
                Read-S3Object -BucketName $bucket -Key $obj.Key -File $localPath | Out-Null
                $downloaded++
                
                if ($downloaded % 100 -eq 0) {
                    Write-Host "   -> Downloaded $downloaded images..."
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
    param([string]$Mode)
    
    Write-Host "`n[4/5] Fetching SEC Financial Statement Data..."
    Write-Host "   -> SEC EDGAR: 64 quarters available (2009 Q1 to 2024 Q4)"
    
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
        'User-Agent' = 'Mozilla/5.0 Enterprise-NAS-Test contact@example.com'
    }
    
    foreach ($quarter in $quarters) {
        $url = "https://www.sec.gov/files/dera/data/financial-statement-data-sets/$quarter.zip"
        $extractDir = Join-Path $Dirs.WAREHOUSE_LOGS $quarter
        
        if (Test-Path $extractDir) {
            Write-Host "   -> $quarter already extracted"
            continue
        }
        
        Write-Host "   -> Downloading $quarter financial statements..."
        
        Invoke-RetryDownload -ScriptBlock {
            $tempZip = Join-Path $env:TEMP "$quarter.zip"
            Invoke-WebRequest -Uri $url -OutFile $tempZip -Headers $headers
            
            # Extract
            Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force
            Remove-Item $tempZip -Force
            
            $fileCount = (Get-ChildItem -Path $extractDir).Count
            Write-Host "      [+] Extracted $fileCount CSV files"
        }
        
        if ($Mode -eq 'sample') { break }
    }
}

# --- 5. FEDERAL REGISTER ---
function Get-FederalRegister {
    param([string]$Mode)
    
    Write-Host "`n[5/5] Fetching Federal Register Documents..."
    
    $apiUrl = "https://www.federalregister.gov/api/v1/documents.json"
    $limit = if ($Mode -eq 'sample') { 50 } else { 200 }
    $docTypes = @('RULE', 'PRORULE', 'NOTICE')
    
    $downloaded = 0
    
    foreach ($docType in $docTypes) {
        if ($downloaded -ge $limit) { break }
        
        $params = @{
            per_page = 20
            order = 'newest'
            'conditions[type][]' = $docType
            'fields[]' = @('title', 'document_number', 'pdf_url', 'type')
        }
        
        $response = Invoke-RestMethod -Uri $apiUrl -Body $params
        
        foreach ($doc in $response.results) {
            if ($downloaded -ge $limit) { break }
            
            $pdfUrl = $doc.pdf_url
            if (-not $pdfUrl) { continue }
            
            $docNum = $doc.document_number -replace '[^a-zA-Z0-9_-]', ''
            $filePath = Join-Path $Dirs.REGULATORY "$docNum.pdf"
            
            if (Test-Path $filePath) {
                $downloaded++
                continue
            }
            
            Invoke-RetryDownload -ScriptBlock {
                Invoke-WebRequest -Uri $pdfUrl -OutFile $filePath
            }
            
            $downloaded++
            Start-Sleep -Milliseconds 100
        }
    }
    
    Write-Host "   -> Downloaded $downloaded regulatory documents"
}

# --- SUMMARY FUNCTION ---
function Show-Summary {
    Write-Host "`n============================================================"
    Write-Host "DOWNLOAD SUMMARY"
    Write-Host "============================================================"
    
    foreach ($name in $Dirs.Keys) {
        $path = $Dirs[$name]
        if (Test-Path $path) {
            $files = (Get-ChildItem -Path $path -Recurse -File).Count
            $size = (Get-ChildItem -Path $path -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($size / 1MB, 1)
            
            Write-Host ("{0,-15} | {1,6} files | {2,8:N1} MB" -f $name, $files, $sizeMB)
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

Write-Host "`nStarting parallel downloads...`n"

# Run downloads in parallel using background jobs
$jobs = @()
$jobs += Start-Job -ScriptBlock ${function:Get-GovDocs} -ArgumentList $Mode
$jobs += Start-Job -ScriptBlock ${function:Get-FederalContracts} -ArgumentList $Mode
$jobs += Start-Job -ScriptBlock ${function:Get-SECFinancials} -ArgumentList $Mode
$jobs += Start-Job -ScriptBlock ${function:Get-FederalRegister} -ArgumentList $Mode

# Wait for all jobs and show output
$jobs | Wait-Job | Receive-Job

# Cleanup jobs
$jobs | Remove-Job

# Show summary
Show-Summary

Write-Host "`n[*] DONE."

