# Enterprise Data Sources Downloader - macOS Edition

Downloads data from multiple public sources for NAS testing:
- Amazon warehouse images, SEC financials, Federal Register, USASpending contracts, GovDocs1

## Requirements

- **macOS 11 (Big Sur) or later**
- **Python 3.9+** (included with macOS or via Homebrew)
- Internet connection
- Storage space:
  - Sample mode: ~8 GB
  - All mode: ~588 GB (or use GovDocs tiers for smaller downloads)

## Installation

### 1. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Python (if needed)

```bash
# Check current Python version
python3 --version

# If older than 3.9, install latest via Homebrew
brew install python@3.12
```

### 3. Clone Repository

```bash
git clone https://github.com/viperdavethesnake/gathermedata.git
cd gathermedata
```

### 4. Create Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Data Sources

1. **Office Documents**: GovDocs1 - Real government files (DOC, PDF, PPT, XLS, HTML)
2. **Federal Contracts**: USASpending.gov - Structured contract data (JSON)
3. **Warehouse Images**: Amazon Bin Images - Product photos (JPG)
4. **Financial Statements**: SEC EDGAR - Company financial filings (CSV)
5. **Regulatory Documents**: Federal Register - Agency rules and notices (PDF)

## Usage

### Download Sample Data (~2 GB)

```bash
# Default location: ~/Downloads/EnterpriseData
python data_loader.py --mode sample

# Custom location:
python data_loader.py --mode sample --path /Volumes/MyDrive/Data

# Or on external drive:
python data_loader.py --mode sample --path /Volumes/External/EnterpriseData
```

### Download Full Dataset (~30 GB)

```bash
python data_loader.py --mode all

# With custom path:
python data_loader.py --mode all --path /Volumes/NAS/TestData
```

### Run in Background

```bash
# Using screen (recommended for long downloads)
screen -S gatherdata
python data_loader.py --mode all
# Press Ctrl+A then D to detach
# Reattach: screen -r gatherdata

# Or using nohup
nohup python data_loader.py --mode all > download.log 2>&1 &
tail -f download.log
```

## Default Download Locations by Platform

| Platform | Default Path |
|----------|-------------|
| macOS | `~/Downloads/EnterpriseData` |
| Linux | `/storage/nexus` |
| Windows | `S:\Shared` |

You can override with `--path`:

```bash
python data_loader.py --mode sample --path /Users/yourname/Desktop/TestData
```

## Features

### Enterprise Sources (`download_enterprise_sources.py`)
- ✅ Downloads from 5 public data sources
- ✅ Parallel downloads using threading
- ✅ Automatic retry on failures (3 attempts)
- ✅ Progress bars with tqdm
- ✅ Resume capability (skips existing files)
- ✅ Custom download paths with `--path` parameter
- ✅ Summary report at completion
- ✅ Platform-aware default paths

### GovDocs1 Downloader (`download_govdocs.py`)
- ✅ 7 download tiers (1K to 986K files)
- ✅ Parallel downloads with `--parallel` parameter (default: 4)
- ✅ Custom thread ranges for precise control
- ✅ Resume capability (skips existing threads)
- ✅ Custom download paths with `--path` parameter
- ✅ Confirmation prompt for large downloads

## Estimated Download Sizes

### Sample Mode
- Download: ~8 GB
- Storage: ~6 GB (varies by filesystem)
- Time: ~10-20 minutes (depends on connection)
- Files: ~12,000+

### All Mode
- Download: ~588 GB
- Storage: ~300-588 GB (depends on compression)
- Time: 6-12 hours (depends on connection)
- Files: ~1 million+

### GovDocs1-Only Downloader (`download_govdocs.py`)

See [README_GOVDOCS.md](README_GOVDOCS.md) for complete details. Quick reference:

| Tier | Files | Size | Command |
|------|-------|------|---------|
| **Tiny** | 1K | 540 MB | `python download_govdocs.py --tier tiny` |
| **Sample** | 10K | 5.4 GB | `python download_govdocs.py --tier sample` |
| **Small** | 50K | 27 GB | `python download_govdocs.py --tier small` |
| **Medium** | 100K | 54 GB | `python download_govdocs.py --tier medium` |
| **Large** | 250K | 135 GB | `python download_govdocs.py --tier large` |
| **XLarge** | 500K | 270 GB | `python download_govdocs.py --tier xlarge` |
| **Complete** | 986K | 540 GB | `python download_govdocs.py --tier complete` |

Add `--parallel 8` for faster downloads with 8 concurrent workers.

## macOS-Specific Tips

### 1. Prevent Sleep During Download

```bash
caffeinate -i python download_enterprise_sources.py --mode all
```

### 2. Use External Drive for Storage

```bash
# Check available drives
ls -l /Volumes/

# Download to external drive
python download_enterprise_sources.py --mode all --path /Volumes/MyExternalDrive/Data
```

### 3. Check Download Progress (from another terminal)

```bash
# Monitor storage usage
du -sh ~/Downloads/EnterpriseData/*

# Watch in real-time
watch -n 5 'du -sh ~/Downloads/EnterpriseData/*'
```

### 4. Optimize for APFS (Apple File System)

APFS doesn't have built-in compression like ZFS, but you can enable compression on specific folders:

```bash
# Enable compression (requires admin)
sudo diskutil apfs enableFileVault /Volumes/YourDrive
```

## Troubleshooting

### Python Not Found

```bash
# Use python3 explicitly
python3 --version
python3 data_loader.py --mode sample
```

### Permission Denied

```bash
# Ensure you have write permissions
mkdir -p ~/Downloads/EnterpriseData
chmod 755 ~/Downloads/EnterpriseData
```

### SSL Certificate Errors

```bash
# Update certificates
/Applications/Python\ 3.*/Install\ Certificates.command

# Or install certifi
pip install --upgrade certifi
```

### Slow Download Speeds

1. **Check your internet connection**
2. **Disable VPN** temporarily (some sources may be slower through VPN)
3. **Use wired connection** if possible (faster than Wi-Fi)
4. **Close bandwidth-heavy apps** (streaming, cloud sync, etc.)

### Out of Disk Space

```bash
# Check available space
df -h ~/Downloads

# Use a different location with more space
python data_loader.py --mode sample --path /Volumes/External/Data
```

## Uninstall

```bash
# Remove downloaded data
rm -rf ~/Downloads/EnterpriseData

# Remove virtual environment
cd gathermedata
rm -rf venv

# Remove repository
cd ..
rm -rf gathermedata
```

## Advanced Usage

### Run with Different Python Version

```bash
# Use specific Python version
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python data_loader.py --mode sample
```

### Combine with Time Command

```bash
# Measure download time
time python data_loader.py --mode sample
```

### Monitor System Resources

```bash
# Install htop for monitoring
brew install htop

# Run in another terminal
htop
```

## Automation with Cron

```bash
# Edit crontab
crontab -e

# Add entry to run daily at 2 AM (example)
0 2 * * * cd /path/to/gathermedata && source venv/bin/activate && python data_loader.py --mode all --path /Volumes/Backup/Data
```

## Support

For issues specific to macOS:
- Python issues: https://docs.python.org/3/using/mac.html
- Homebrew issues: https://docs.brew.sh/
- APFS: https://support.apple.com/guide/disk-utility/

For general issues, see the main README.md

