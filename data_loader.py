#!/usr/bin/env python3
"""
Enterprise NAS Data Loader
Downloads real-world data from public repositories for testing.
"""
import os
import sys
import requests
import boto3
from botocore import UNSIGNED
from botocore.config import Config
import zipfile
import io
import argparse
import time
import threading
from tqdm import tqdm

# --- CONFIGURATION ---
BASE_DIR = "/storage/nexus"
DIRS = {
    "OFFICE": os.path.join(BASE_DIR, "1_Office_Docs_GovDocs"),
    "FINANCE": os.path.join(BASE_DIR, "2_Federal_Contracts_USASpending"),
    "WAREHOUSE_IMG": os.path.join(BASE_DIR, "3_Warehouse_Images_Amazon"),
    "WAREHOUSE_LOGS": os.path.join(BASE_DIR, "4_Financial_Statements_SEC"),
    "REGULATORY": os.path.join(BASE_DIR, "5_Regulatory_Docs_FederalRegister"),
}

MAX_RETRIES = 3
RETRY_DELAY = 2

def retry_download(func):
    """Decorator for retrying downloads on failure"""
    def wrapper(*args, **kwargs):
        for attempt in range(MAX_RETRIES):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                if attempt == MAX_RETRIES - 1:
                    print(f"      [!] Failed after {MAX_RETRIES} attempts: {e}")
                    return None
                print(f"      [!] Attempt {attempt + 1} failed: {e}. Retrying...")
                time.sleep(RETRY_DELAY)
        return None
    return wrapper

# --- 1. OFFICE DOCS (GovDocs1) ---
def download_govdocs(mode):
    print("\n[1/4] Starting GovDocs Download (Real Office Files)...")
    base_url = "https://downloads.digitalcorpora.org/corpora/files/govdocs1/zipfiles/"
    threads = range(50) if mode == 'all' else [0, 1]
    
    for i in threads:
        thread_id = f"{i:03d}.zip"
        url = base_url + thread_id
        print(f"   -> Downloading Thread {thread_id}...")
        
        @retry_download
        def fetch_thread():
            r = requests.get(url, stream=True, timeout=60)
            if r.status_code == 200:
                total_size = int(r.headers.get('content-length', 0))
                with tqdm(total=total_size, unit='B', unit_scale=True, desc=f"   {thread_id}") as pbar:
                    content = io.BytesIO()
                    for chunk in r.iter_content(chunk_size=8192):
                        content.write(chunk)
                        pbar.update(len(chunk))
                    content.seek(0)
                    z = zipfile.ZipFile(content)
                    z.extractall(DIRS["OFFICE"])
                    print(f"      [+] Extracted {len(z.namelist())} files.")
                return True
            else:
                print(f"      [!] Failed to get thread {thread_id} (Status: {r.status_code})")
                return None
        
        fetch_thread()
        
        if mode == 'sample':
            break

# --- 2. FINANCIAL DATA (USASpending.gov Federal Contracts) ---
# Note: Downloads structured JSON data containing real federal contract information
# including award amounts, recipients, agencies, dates, and descriptions
def download_federal_contracts(mode):
    print("\n[2/4] Starting Federal Contract Data (USASpending.gov)...")
    print("   -> Downloading structured financial records (JSON format)")
    api_url = "https://api.usaspending.gov/api/v2/search/spending_by_award/"
    limit = 50 if mode == 'sample' else 500
    
    payload = {
        "filters": {
            "award_type_codes": ["A", "B", "C", "D"],  # Contracts
            "time_period": [{"start_date": "2023-01-01", "end_date": "2023-12-31"}]
        },
        "fields": [
            "Award ID", "Recipient Name", "Start Date", "End Date",
            "Award Amount", "Total Outlays", "Description",
            "Awarding Agency", "Awarding Sub Agency", "Contract Award Type"
        ],
        "limit": 100,
        "page": 1
    }
    
    try:
        downloaded = 0
        page = 1
        
        with tqdm(total=limit, desc="   Contracts") as pbar:
            while downloaded < limit:
                payload["page"] = page
                payload["limit"] = min(100, limit - downloaded)
                
                @retry_download
                def fetch_contracts():
                    r = requests.post(api_url, json=payload, timeout=30)
                    if r.status_code == 200:
                        return r.json()
                    return None
                
                data = fetch_contracts()
                if not data or not data.get('results'):
                    break
                
                results = data.get('results', [])
                
                # Save each contract as a JSON file
                for contract in results:
                    if downloaded >= limit:
                        break
                    
                    # Create filename from award ID (sanitize)
                    award_id = contract.get('Award ID', f'contract_{downloaded}')
                    safe_id = "".join(c for c in award_id if c.isalnum() or c in ('-', '_'))[:50]
                    local_path = os.path.join(DIRS["FINANCE"], f"{safe_id}.json")
                    
                    if not os.path.exists(local_path):
                        import json
                        with open(local_path, 'w') as f:
                            json.dump(contract, f, indent=2)
                    
                    downloaded += 1
                    pbar.update(1)
                
                page += 1
                
        print(f"   -> Downloaded {downloaded} contract records")
                
    except Exception as e:
        print(f"   [!] Error fetching USASpending data: {e}")

# --- 3. WAREHOUSE IMAGES (Amazon) ---
def download_amazon_images(mode):
    print("\n[3/4] Starting Amazon Bin Image Download...")
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    bucket_name = 'aft-vbi-pds'
    prefix = 'bin-images/'
    target_count = 50 if mode == 'sample' else 2000
    
    try:
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=prefix)
        
        with tqdm(total=target_count, desc="   Images") as pbar:
            count = 0
            for page in pages:
                if 'Contents' not in page:
                    continue
                for obj in page['Contents']:
                    if count >= target_count:
                        return
                    key = obj['Key']
                    if key.endswith('.jpg'):
                        local_path = os.path.join(DIRS["WAREHOUSE_IMG"], key.split('/')[-1])
                        if not os.path.exists(local_path):
                            @retry_download
                            def fetch_image():
                                s3.download_file(bucket_name, key, local_path)
                                return True
                            
                            if fetch_image():
                                count += 1
                                pbar.update(1)
    except Exception as e:
        print(f"   [!] AWS Error: {e}")

# --- 4. FINANCIAL STATEMENTS (SEC EDGAR) ---
# Real company financial data from SEC filings (10-K, 10-Q reports)
# Each quarter contains multiple CSV files with balance sheet, income statement, cash flow data
def download_sec_financials(mode):
    print("\n[4/4] Fetching SEC Financial Statement Data...")
    
    # Download 1 quarter for sample, 4 quarters for all
    quarters = ['2024q3'] if mode == 'sample' else ['2024q3', '2024q2', '2024q1', '2023q4']
    
    headers = {
        'User-Agent': 'Mozilla/5.0 Enterprise-NAS-Test contact@example.com'
    }
    
    for quarter in quarters:
        url = f"https://www.sec.gov/files/dera/data/financial-statement-data-sets/{quarter}.zip"
        local_zip = os.path.join(DIRS["WAREHOUSE_LOGS"], f"sec_{quarter}.zip")
        extract_dir = os.path.join(DIRS["WAREHOUSE_LOGS"], quarter)
        
        if os.path.exists(extract_dir):
            print(f"   -> {quarter} already extracted")
            continue
        
        print(f"   -> Downloading {quarter} financial statements...")
        
        @retry_download
        def fetch_quarter():
            r = requests.get(url, headers=headers, stream=True, timeout=60)
            if r.status_code == 200:
                total_size = int(r.headers.get('content-length', 0))
                
                with open(local_zip, 'wb') as f:
                    with tqdm(total=total_size, unit='B', unit_scale=True, desc=f"   {quarter}") as pbar:
                        for chunk in r.iter_content(chunk_size=1024*1024):
                            f.write(chunk)
                            pbar.update(len(chunk))
                
                # Extract the ZIP
                os.makedirs(extract_dir, exist_ok=True)
                z = zipfile.ZipFile(local_zip)
                z.extractall(extract_dir)
                print(f"      [+] Extracted {len(z.namelist())} CSV files")
                
                # Remove zip after extraction
                os.remove(local_zip)
                return True
            return None
        
        fetch_quarter()
        
        if mode == 'sample':
            break

# --- 5. REGULATORY DOCUMENTS (Federal Register) ---
# Real federal agency rules, proposed rules, and notices (PDFs)
# Excludes presidential documents per requirements
def download_federal_register(mode):
    print("\n[5/5] Fetching Federal Register Documents...")
    api_url = "https://www.federalregister.gov/api/v1/documents.json"
    limit = 50 if mode == 'sample' else 200
    
    # Document types to include (excluding Presidential Documents)
    doc_types = ['RULE', 'PRORULE', 'NOTICE']
    
    downloaded = 0
    
    with tqdm(total=limit, desc="   Regulatory PDFs") as pbar:
        for doc_type in doc_types:
            if downloaded >= limit:
                break
            
            params = {
                'per_page': 20,
                'order': 'newest',
                'conditions[type][]': doc_type,
                'fields[]': ['title', 'document_number', 'pdf_url', 'type']
            }
            
            @retry_download
            def fetch_docs():
                return requests.get(api_url, params=params, timeout=30)
            
            response = fetch_docs()
            if not response or response.status_code != 200:
                continue
            
            data = response.json()
            results = data.get('results', [])
            
            for doc in results:
                if downloaded >= limit:
                    break
                
                pdf_url = doc.get('pdf_url')
                doc_num = doc.get('document_number', f'doc_{downloaded}')
                
                if not pdf_url:
                    continue
                
                # Sanitize filename
                safe_name = "".join(c for c in doc_num if c.isalnum() or c in ('-', '_'))
                local_path = os.path.join(DIRS["REGULATORY"], f"{safe_name}.pdf")
                
                if os.path.exists(local_path):
                    downloaded += 1
                    pbar.update(1)
                    continue
                
                @retry_download
                def fetch_pdf():
                    r = requests.get(pdf_url, stream=True, timeout=30)
                    if r.status_code == 200:
                        with open(local_path, 'wb') as f:
                            for chunk in r.iter_content(chunk_size=8192):
                                f.write(chunk)
                        return True
                    return None
                
                if fetch_pdf():
                    downloaded += 1
                    pbar.update(1)
                
                time.sleep(0.1)
    
    print(f"   -> Downloaded {downloaded} regulatory documents")

def get_dir_size(path):
    """Calculate total size of directory"""
    total = 0
    if not os.path.exists(path):
        return 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            if os.path.exists(fp):
                total += os.path.getsize(fp)
    return total

def count_files(path):
    """Count files in directory"""
    if not os.path.exists(path):
        return 0
    return sum(len(files) for _, _, files in os.walk(path))

def print_summary():
    """Print download summary"""
    print("\n" + "="*60)
    print("DOWNLOAD SUMMARY")
    print("="*60)
    for name, path in DIRS.items():
        size = get_dir_size(path)
        files = count_files(path)
        size_mb = size / (1024*1024)
        print(f"{name:15} | {files:6} files | {size_mb:8.1f} MB")
    print("="*60)
    print(f"Data location: {os.path.abspath(BASE_DIR)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Download real-world enterprise data for testing'
    )
    parser.add_argument(
        '--mode',
        choices=['sample', 'all'],
        default='sample',
        help='Download mode: sample (small batch) or all (large batch)'
    )
    args = parser.parse_args()
    
    print("="*60)
    print("ENTERPRISE DATA LOADER")
    print("="*60)
    print(f"Mode: {args.mode.upper()}")
    print(f"Target: {os.path.abspath(BASE_DIR)}")
    print("="*60)
    
    # Create directories
    for p in DIRS.values():
        os.makedirs(p, exist_ok=True)
    
    # Run downloads in parallel threads
    print("\nStarting parallel downloads...\n")
    
    threads = [
        threading.Thread(target=download_govdocs, args=(args.mode,), name="GovDocs"),
        threading.Thread(target=download_federal_contracts, args=(args.mode,), name="Contracts"),
        threading.Thread(target=download_amazon_images, args=(args.mode,), name="Images"),
        threading.Thread(target=download_sec_financials, args=(args.mode,), name="SEC"),
        threading.Thread(target=download_federal_register, args=(args.mode,), name="FedRegister"),
    ]
    
    # Start all threads
    for thread in threads:
        thread.start()
    
    # Wait for all threads to complete
    for thread in threads:
        thread.join()
    
    # Print summary
    print_summary()
    print("\n[*] DONE.")

