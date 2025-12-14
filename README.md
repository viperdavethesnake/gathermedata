# Enterprise NAS Data Loader

Downloads real-world data from public repositories for NAS testing environments.

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
   - 30,000+ documents available (sample: 200, all: 5,000)
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

```bash
# Download sample data (~2 GB) - uses platform default path
python data_loader.py --mode sample

# Download full datasets (~30 GB)
python data_loader.py --mode all

# Specify custom download path
python data_loader.py --mode sample --path /your/custom/path

# Example with custom path
python data_loader.py --mode all --path /mnt/nas/testdata
```

### Default Paths by Platform

| Platform | Default Path |
|----------|-------------|
| Linux | `/storage/nexus` |
| macOS | `~/Downloads/EnterpriseData` |
| Windows (Python) | `S:\Shared` |
| Windows (PowerShell) | `S:\Shared` |

### Platform-Specific Documentation

- **Linux**: This README
- **macOS**: See [README_MACOS.md](README_MACOS.md)
- **Windows**: See [README_WINDOWS.md](README_WINDOWS.md)

## Features

- Automatic retry on network failures
- Progress bars for all downloads
- Resume capability (skips existing files)
- Summary report at completion
- Organized directory structure

## Storage Requirements

- Sample mode: ~2 GB download, ~1.5 GB storage
- All mode: ~30 GB download, ~13-26 GB storage (depends on filesystem compression)

