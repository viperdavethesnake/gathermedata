# Enterprise Data Sources Downloader - Windows PowerShell Edition

Downloads data from multiple public sources for NAS testing:
- Amazon warehouse images, SEC financials, Federal Register, USASpending contracts, GovDocs1

## Requirements

- **PowerShell 7.0 or later** (latest: 7.5.4)
- Windows 10/11 or Windows Server 2019+
- Internet connection
- Storage space:
  - Sample mode: ~8 GB
  - All mode: ~588 GB (or use GovDocs tiers for smaller downloads)

### Install PowerShell 7

If you don't have PowerShell 7, install it:

```powershell
# Run in Windows PowerShell (as Administrator)
winget install --id Microsoft.PowerShell --source winget
```

Or download from: https://github.com/PowerShell/PowerShell/releases

## Data Sources

1. **Office Documents**: GovDocs1 - Real government files (DOC, PDF, PPT, XLS, HTML)
2. **Federal Contracts**: USASpending.gov - Structured contract data (JSON)
3. **Warehouse Images**: Amazon Bin Images - Product photos (JPG) - *Requires AWS Tools*
4. **Financial Statements**: SEC EDGAR - Company financial filings (CSV)
5. **Regulatory Documents**: Federal Register - Agency rules and notices (PDF)

## Setup

### 1. Open PowerShell 7

Press `Win + X` and select "Windows PowerShell" or "Terminal"

### 2. Navigate to Script Directory

```powershell
cd C:\path\to\gathermedata
```

### 3. Set Execution Policy (if needed)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 4. Optional: Install AWS Tools (for Amazon images)

```powershell
Install-Module -Name AWS.Tools.S3 -Force
```

## Usage

### Download Sample Data (~8 GB)

```powershell
.\download_enterprise_sources.ps1 -Mode sample
```

### Download Full Dataset (~588 GB)

```powershell
# Default path: S:\Shared
.\download_enterprise_sources.ps1 -Mode all

# Custom path
.\download_enterprise_sources.ps1 -Mode all -Path "D:\TestData"
```

### GovDocs1-Only Downloader

For granular control over GovDocs1 downloads (7 tiers from 540 MB to 540 GB):

```powershell
# List available tiers
.\download_govdocs.ps1 -List

# Download sample tier (10K files, 5 GB)
.\download_govdocs.ps1 -Tier sample

# Complete corpus with 8 parallel downloads
.\download_govdocs.ps1 -Tier complete -Parallel 8

# Custom thread range
.\download_govdocs.ps1 -Threads 100 -Start 50 -Path "D:\GovDocs1"
```

## Default Download Locations

**download_enterprise_sources.ps1**: `S:\Shared` (override with `-Path`)
**download_govdocs.ps1**: `S:\GovDocs1` (override with `-Path`)
**download_digitalcorpora_scenarios.ps1**: `S:\DigitalCorpora` (override with `-Path`)

The script creates subdirectories:
- `S:\Shared\1_Office_Docs_GovDocs`
- `S:\Shared\2_Federal_Contracts_USASpending`
- `S:\Shared\3_Warehouse_Images_Amazon`
- `S:\Shared\4_Financial_Statements_SEC`
- `S:\Shared\5_Regulatory_Docs_FederalRegister`

## Features

### Enterprise Sources (`download_enterprise_sources.ps1`)
- ✅ Downloads from 5 public data sources
- ✅ Parallel downloads using PowerShell jobs
- ✅ Automatic retry on failures (3 attempts)
- ✅ Progress reporting
- ✅ Resume capability (skips existing files)
- ✅ Custom download paths with `-Path` parameter
- ✅ Summary report at completion

### GovDocs1 Downloader (`download_govdocs.ps1`)
- ✅ 7 download tiers (1K to 986K files)
- ✅ Parallel downloads with `-Parallel` parameter (default: 4)
- ✅ Custom thread ranges for precise control
- ✅ Resume capability (skips existing threads)
- ✅ Custom download paths with `-Path` parameter
- ✅ Confirmation prompt for large downloads

## Estimated Download Sizes

### Enterprise Sources (`download_enterprise_sources.ps1`)

**Sample Mode:**
- Download: ~8 GB
- Storage: ~6 GB
- Time: ~10-20 minutes (depends on connection)
- Files: ~12,000+

**All Mode:**
- Download: ~588 GB
- Storage: ~300-588 GB (depends on filesystem compression)
- Time: 6-12 hours (depends on connection)
- Files: ~1 million+
- Breakdown:
  - GovDocs1: ~540 GB (986K files)
  - Amazon Images: ~27 GB (50K images) - *requires AWS.Tools.S3*
  - SEC Financials: ~12 GB (20 quarters)
  - Federal Register: ~4 GB (10K PDFs)
  - Federal Contracts: <1 MB (JSON)

### GovDocs1-Only Downloader (`download_govdocs.ps1`)

See [README_GOVDOCS.md](README_GOVDOCS.md) for complete tier breakdown:
- **Tiny**: 540 MB (1K files)
- **Sample**: 5.4 GB (10K files)
- **Small**: 27 GB (50K files)
- **Medium**: 54 GB (100K files)
- **Large**: 135 GB (250K files)
- **XLarge**: 270 GB (500K files)
- **Complete**: 540 GB (986K files)

## Troubleshooting

### "Execution Policy" Error

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\data_loader.ps1 -Mode sample
```

### Network/Firewall Issues

Ensure these domains are accessible:
- `downloads.digitalcorpora.org`
- `api.usaspending.gov`
- `www.sec.gov`
- `www.federalregister.gov`
- `s3.amazonaws.com` (for Amazon images)

### Amazon Images Not Downloading

The Amazon S3 images require AWS Tools:

```powershell
Install-Module -Name AWS.Tools.S3 -Force
Import-Module AWS.Tools.S3
```

Then re-run the script.

### Permission Denied on S:\

If `S:\Shared` doesn't exist or you don't have permissions:

1. Create the directory with appropriate permissions
2. Or change `$BaseDir` in the script to a different location

## Performance Tips

1. **Use SSD storage** for faster extraction
2. **Disable antivirus scanning** temporarily for the download folder
3. **Close other bandwidth-intensive applications**
4. Run from PowerShell 7 (not Windows PowerShell 5.1) for better performance

## Differences from Python Version

- Amazon S3 images require AWS Tools module (Python uses boto3)
- Progress bars work differently in PowerShell
- Parallel execution uses PowerShell jobs instead of threading
- Some operations may be slightly slower than Python equivalent

## Support

For issues specific to the PowerShell version:
1. Check PowerShell version: `$PSVersionTable.PSVersion`
2. Verify script execution: `Get-ExecutionPolicy`
3. Check available disk space: `Get-PSDrive`

For general issues, see the main README.md

