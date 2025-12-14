# GatherMe Data - Real-World Data Collection Tools

Collection of scripts for downloading real-world data from public repositories for NAS testing, forensics research, and data science.

**🚀 Quick Start:** See [HOWTO.md](HOWTO.md) for copy/paste commands

## Data Sources

1. **Office Documents**: GovDocs1 - Real government files (DOC, PDF, PPT, XLS, HTML)
2. **Federal Contracts**: USASpending.gov - Structured contract data (JSON)
   - Real contract awards, recipients, amounts, agencies, descriptions
3. **Warehouse Images**: Amazon Bin Image Dataset - Product bin photos (JPG)
4. **Financial Statements**: SEC EDGAR - Company financial filings (CSV)
   - Real 10-K/10-Q data: balance sheets, income statements, cash flows
   - Multiple CSV files per quarter
5. **Regulatory Documents**: Federal Register - Agency rules and notices (PDF)
   - Final rules, proposed rules, public notices from federal agencies
   - 30,000+ documents available (sample: 200, all: 10,000)
   - Daily updates, excludes presidential documents

## Setup

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # Linux/Mac
# OR
venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt
```

## Usage

### Enterprise Sources (Mixed Public Data)

Downloads from Amazon, SEC, Federal Register, and USASpending.

**Python:**
```bash
# Download sample data (~8 GB) - uses platform default path
python download_enterprise_sources.py --mode sample

# Download full datasets (~588 GB)
python download_enterprise_sources.py --mode all

# Specify custom download path
python download_enterprise_sources.py --mode all --path /mnt/nas/testdata
```

**PowerShell (Windows):**
```powershell
# Download sample data
.\download_enterprise_sources.ps1 -Mode sample

# Download full datasets with custom path
.\download_enterprise_sources.ps1 -Mode all -Path "D:\TestData"
```

### GovDocs1-Only Downloader (Dedicated Script)

For granular control over GovDocs1 downloads (7 tiers):

**Python:**
```bash
# List available tiers
python download_govdocs.py --list

# Download specific tier with parallel downloads
python download_govdocs.py --tier medium --parallel 8

# Custom path
python download_govdocs.py --tier complete --path /storage/govdocs
```

**PowerShell (Windows):**
```powershell
# List available tiers
.\download_govdocs.ps1 -List

# Download with parallel jobs
.\download_govdocs.ps1 -Tier medium -Parallel 8 -Path "D:\GovDocs1"
```

### Default Paths by Platform

| Platform | Default Path |
|----------|-------------|
| Linux | `/storage/nexus` |
| macOS | `~/Downloads/EnterpriseData` |
| Windows (Python) | `S:\Shared` |
| Windows (PowerShell) | `S:\Shared` |

### Additional Scripts & Documentation

- **macOS**: See [README_MACOS.md](README_MACOS.md)
- **Windows**: See [README_WINDOWS.md](README_WINDOWS.md)
- **GovDocs1 Only**: See [README_GOVDOCS.md](README_GOVDOCS.md) - Dedicated downloader with 7 tiers
- **Digital Corpora**: See [README_DIGITALCORPORA.md](README_DIGITALCORPORA.md) - Forensic scenarios & file corpora

## Features

### Enterprise Sources (`download_enterprise_sources.*`)
- ✅ Downloads from 5 public data sources
- ✅ Automatic retry on network failures
- ✅ Progress bars for all downloads
- ✅ Resume capability (skips existing files)
- ✅ Summary report at completion
- ✅ Custom download paths
- ✅ Cross-platform (Python + PowerShell)

### GovDocs1 Downloader (`download_govdocs.py` / `download_govdocs.ps1`)
- ✅ 7 download tiers (1K to 986K files)
- ✅ Parallel downloads (4-8 workers recommended)
- ✅ Custom thread ranges for precise control
- ✅ Resume capability (skips existing threads)
- ✅ Custom download paths
- ✅ Cross-platform (Python + PowerShell)

## Storage Requirements

### Enterprise Sources (`download_enterprise_sources.py`)
- Sample mode: ~8 GB download, ~6 GB storage
- All mode: ~588 GB download, ~300-588 GB storage
  - GovDocs1: ~540 GB (1000 threads) - *use download_govdocs.py for tiers*
  - Amazon Images: ~27 GB (50,000 images)
  - SEC Financials: ~12 GB (20 quarters)
  - Federal Register: ~4 GB (10,000 PDFs)
  - Federal Contracts: <1 MB (JSON metadata)

### GovDocs1 Only (`download_govdocs.py`)
See [README_GOVDOCS.md](README_GOVDOCS.md) for 7 download tiers from 540 MB to 540 GB

### Digital Corpora Scenarios (`download_digitalcorpora_scenarios.py`)
See [README_DIGITALCORPORA.md](README_DIGITALCORPORA.md) for forensic scenarios and small file corpora:
- **7 Forensic Scenarios**: Complete investigation scenarios (25-223 GB each)
- **5 Small File Corpora**: PDFs, audio, video, media collections

### SAFEDOCS (`download_safedocs.py`)
- **8 tiers**: tiny (1K, 100 MB) → complete (8M PDFs, 800 GB)
- Common Crawl PDF collection (CC-MAIN-2021-31-PDF-UNTRUNCATED)

### UNSAFE-DOCS (`download_unsafedocs.py`)
- **8 tiers**: tiny (1K, 120 MB) → complete (5.3M+ files, 650 GB)
- Common Crawl mixed files (CC-MAIN-2021-31-UNSAFE)

