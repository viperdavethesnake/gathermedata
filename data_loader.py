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
from tqdm import tqdm

# --- CONFIGURATION ---
BASE_DIR = "REAL_ENTERPRISE_DATA"
DIRS = {
    "OFFICE": os.path.join(BASE_DIR, "1_Office_Docs_GovDocs"),
    "FINANCE": os.path.join(BASE_DIR, "2_Finance_Invoices_UCSF"),
    "WAREHOUSE_IMG": os.path.join(BASE_DIR, "3_Warehouse_Images_Amazon"),
    "WAREHOUSE_LOGS": os.path.join(BASE_DIR, "4_Sales_Logs_UCI"),
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

# --- 2. FINANCE (UCSF Industry Documents) ---
def download_ucsf_invoices(mode):
    print("\n[2/4] Starting UCSF Industry Docs (Real Invoices)...")
    solr_url = "https://solr.idl.ucsf.edu/solr/ltdl3/select"
    limit = 50 if mode == 'sample' else 1000
    params = {
        'q': 'type:invoice AND format:pdf',
        'wt': 'json',
        'rows': limit,
        'fl': 'id,filename,file_size'
    }
    
    try:
        r = requests.get(solr_url, params=params, timeout=30)
        docs = r.json().get('response', {}).get('docs', [])
        print(f"   -> Found metadata for {len(docs)} real invoices...")
        
        with tqdm(total=len(docs), desc="   Invoices") as pbar:
            for doc in docs:
                doc_id = doc.get('id', 'unknown')
                download_url = f"https://iiif.idl.ucsf.edu/file/{doc_id}/{doc_id}.pdf"
                local_path = os.path.join(DIRS["FINANCE"], f"{doc_id}.pdf")
                
                if os.path.exists(local_path):
                    pbar.update(1)
                    continue
                
                @retry_download
                def fetch_invoice():
                    pdf_r = requests.get(download_url, stream=True, timeout=30)
                    if pdf_r.status_code == 200:
                        with open(local_path, 'wb') as f:
                            for chunk in pdf_r.iter_content(chunk_size=8192):
                                f.write(chunk)
                        return True
                    return None
                
                fetch_invoice()
                pbar.update(1)
                time.sleep(0.3)
                
    except Exception as e:
        print(f"   [!] Error querying UCSF API: {e}")

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

# --- 4. SALES LOGS (UCI Retail) ---
def download_retail_logs(mode):
    print("\n[4/4] Fetching Real Sales Logs (UCI Retail II)...")
    url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00502/online_retail_II.xlsx"
    local_path = os.path.join(DIRS["WAREHOUSE_LOGS"], "real_sales_data.xlsx")
    
    if os.path.exists(local_path):
        print("   -> Already downloaded.")
        return

    @retry_download
    def fetch_logs():
        print("   -> Downloading 45MB Excel file...")
        r = requests.get(url, stream=True, timeout=60)
        total_size = int(r.headers.get('content-length', 0))
        
        with open(local_path, 'wb') as f:
            with tqdm(total=total_size, unit='B', unit_scale=True, desc="   Excel") as pbar:
                for chunk in r.iter_content(chunk_size=1024*1024):
                    f.write(chunk)
                    pbar.update(len(chunk))
        print("      [+] Download complete.")
        return True
    
    fetch_logs()

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
    
    # Run downloads
    download_govdocs(args.mode)
    download_ucsf_invoices(args.mode)
    download_amazon_images(args.mode)
    download_retail_logs(args.mode)
    
    # Print summary
    print_summary()
    print("\n[*] DONE.")

