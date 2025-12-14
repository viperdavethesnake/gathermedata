# Enterprise NAS Data Loader - Windows PowerShell Edition

Downloads real-world data from public repositories for NAS testing environments.

## Requirements

- **PowerShell 7.0 or later** (latest: 7.5.4)
- Windows 10/11 or Windows Server 2019+
- Internet connection
- ~30 GB free space (for sample mode: ~2 GB)

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

### Download Sample Data (~2 GB)

```powershell
.\data_loader.ps1 -Mode sample
```

### Download Full Dataset (~30 GB)

```powershell
.\data_loader.ps1 -Mode all
```

### Change Download Location

Edit the `$BaseDir` variable in `data_loader.ps1`:

```powershell
$BaseDir = "D:\MyData"  # Change from S:\Shared
```

## Default Download Location

**Default**: `S:\Shared`

The script creates subdirectories:
- `S:\Shared\1_Office_Docs_GovDocs`
- `S:\Shared\2_Federal_Contracts_USASpending`
- `S:\Shared\3_Warehouse_Images_Amazon`
- `S:\Shared\4_Financial_Statements_SEC`
- `S:\Shared\5_Regulatory_Docs_FederalRegister`

## Features

- ✅ Parallel downloads using PowerShell jobs
- ✅ Automatic retry on failures (3 attempts)
- ✅ Progress reporting
- ✅ Resume capability (skips existing files)
- ✅ Summary report at completion

## Estimated Download Sizes

### Sample Mode
- Download: ~2 GB
- Storage: ~1.5 GB
- Time: ~5-10 minutes (depends on connection)

### All Mode
- Download: ~30 GB
- Storage: ~26 GB
- Time: ~30-60 minutes (depends on connection)

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

