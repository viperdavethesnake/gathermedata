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
# Download sample data (~5-10GB)
python data_loader.py --mode sample

# Download full datasets (100GB+)
python data_loader.py --mode all
```

## Features

- Automatic retry on network failures
- Progress bars for all downloads
- Resume capability (skips existing files)
- Summary report at completion
- Organized directory structure

## Storage Requirements

- Sample mode: ~5-10 GB
- All mode: 100+ GB (potentially 500GB+)

