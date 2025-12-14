# Enterprise NAS Data Loader

Downloads real-world data from public repositories for NAS testing environments.

## Data Sources

1. **Office Documents**: GovDocs1 (Digital Corpora)
2. **Finance/Invoices**: UCSF Industry Documents Library
3. **Warehouse Images**: Amazon Bin Image Dataset (AWS)
4. **Sales Logs**: UCI Online Retail II Dataset

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

