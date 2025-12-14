#!/usr/bin/env python3
"""
SAFEDOCS Downloader - Dedicated script for downloading SAFEDOCS corpus
~8 million PDFs sourced from Common Crawl (CC-MAIN-2021-31-PDF-UNTRUNCATED)

Source: https://digitalcorpora.org/corpora/file-corpora/files/
"""
import os
import sys
import argparse
import time
import boto3
from botocore import UNSIGNED
from botocore.config import Config
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- CONFIGURATION ---
DEFAULT_PATHS = {
    'linux': '/storage/nexus/SAFEDOCS',
    'darwin': os.path.expanduser('~/Downloads/SAFEDOCS'),
    'win32': 'S:\\SAFEDOCS'
}

S3_BUCKET = 'digitalcorpora'
S3_PREFIX = 'corpora/files/CC-MAIN-2021-31-PDF-UNTRUNCATED/'
MAX_RETRIES = 3
RETRY_DELAY = 2

# Download tiers - customize based on your needs
DOWNLOAD_TIERS = {
    'tiny': {
        'files': 1000,
        'size': '~100 MB',
        'description': 'Minimal test set'
    },
    'sample': {
        'files': 10000,
        'size': '~1 GB',
        'description': 'Good for development/testing'
    },
    'small': {
        'files': 50000,
        'size': '~5 GB',
        'description': 'Substantial test dataset'
    },
    'medium': {
        'files': 100000,
        'size': '~10 GB',
        'description': 'Large representative sample'
    },
    'large': {
        'files': 500000,
        'size': '~50 GB',
        'description': 'Large dataset'
    },
    'xlarge': {
        'files': 1000000,
        'size': '~100 GB',
        'description': 'Million PDF sample'
    },
    'xxlarge': {
        'files': 2000000,
        'size': '~200 GB',
        'description': 'Two million PDFs'
    },
    'complete': {
        'files': 8000000,
        'size': '~800 GB',
        'description': 'Complete SAFEDOCS corpus (8M PDFs)'
    }
}

def get_s3_client():
    """Create an anonymous S3 client"""
    return boto3.client(
        's3',
        config=Config(signature_version=UNSIGNED, max_pool_connections=50)
    )

def download_single_file(s3_client, key, dest_path):
    """Download a single file from S3 with retry logic"""
    for attempt in range(MAX_RETRIES):
        try:
            if os.path.exists(dest_path):
                return ('skipped', key)
            
            # Create directory if needed
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            
            # Download file
            s3_client.download_file(S3_BUCKET, key, dest_path)
            return ('downloaded', key)
            
        except Exception as e:
            if attempt == MAX_RETRIES - 1:
                return ('failed', key, str(e))
            time.sleep(RETRY_DELAY)
    
    return ('failed', key, 'Max retries exceeded')

def list_s3_files(s3_client, limit=None):
    """List all files in the SAFEDOCS S3 prefix"""
    print(f"   -> Listing files from s3://{S3_BUCKET}/{S3_PREFIX}")
    files = []
    paginator = s3_client.get_paginator('list_objects_v2')
    
    try:
        for page in paginator.paginate(Bucket=S3_BUCKET, Prefix=S3_PREFIX):
            if 'Contents' not in page:
                continue
            
            for obj in page['Contents']:
                key = obj['Key']
                # Skip directory markers
                if key.endswith('/'):
                    continue
                files.append(key)
                
                if limit and len(files) >= limit:
                    print(f"   -> Reached limit of {limit} files")
                    return files
    
    except Exception as e:
        print(f"   [!] Error listing S3 files: {e}")
        return []
    
    return files

def download_safedocs(base_dir, tier=None, limit=None, parallel=4):
    """Download SAFEDOCS corpus"""
    print(f"\n{'='*60}")
    print(f"SAFEDOCS DOWNLOADER")
    print(f"{'='*60}")
    print(f"Source: Common Crawl (CC-MAIN-2021-31-PDF-UNTRUNCATED)")
    print(f"Total: ~8 million PDFs")
    print(f"Download path: {base_dir}")
    
    # Determine file limit
    if tier:
        if tier not in DOWNLOAD_TIERS:
            print(f"[!] Invalid tier: {tier}")
            print(f"    Available tiers: {', '.join(DOWNLOAD_TIERS.keys())}")
            return
        file_limit = DOWNLOAD_TIERS[tier]['files']
        print(f"Tier: {tier} ({DOWNLOAD_TIERS[tier]['description']})")
        print(f"Files: {file_limit:,} ({DOWNLOAD_TIERS[tier]['size']})")
    elif limit:
        file_limit = limit
        print(f"Custom limit: {file_limit:,} files")
    else:
        file_limit = None
        print(f"Mode: Complete download (all 8M PDFs)")
    
    print(f"Parallel workers: {parallel}")
    print(f"{'='*60}\n")
    
    # Confirm large downloads
    if not file_limit or file_limit > 100000:
        size_estimate = "800 GB" if not file_limit else DOWNLOAD_TIERS.get(tier, {}).get('size', 'unknown')
        response = input(f"This will download {file_limit if file_limit else '8M'} files (~{size_estimate}). Continue? (yes/no): ")
        if response.lower() not in ['yes', 'y']:
            print("Download cancelled.")
            return
    
    # Create S3 client
    s3_client = get_s3_client()
    
    # List files
    print("Listing files from S3...")
    files = list_s3_files(s3_client, limit=file_limit)
    
    if not files:
        print("[!] No files found to download")
        return
    
    print(f"Found {len(files):,} files to download\n")
    
    # Download files
    stats = {'downloaded': 0, 'skipped': 0, 'failed': 0}
    
    with ThreadPoolExecutor(max_workers=parallel) as executor:
        # Submit all download tasks
        future_to_file = {}
        for key in files:
            # Maintain directory structure
            rel_path = key.replace(S3_PREFIX, '')
            dest_path = os.path.join(base_dir, rel_path)
            future = executor.submit(download_single_file, s3_client, key, dest_path)
            future_to_file[future] = key
        
        # Process results with progress bar
        with tqdm(total=len(files), desc="Downloading", unit="file") as pbar:
            for future in as_completed(future_to_file):
                result = future.result()
                status = result[0]
                
                if status == 'downloaded':
                    stats['downloaded'] += 1
                elif status == 'skipped':
                    stats['skipped'] += 1
                elif status == 'failed':
                    stats['failed'] += 1
                
                pbar.update(1)
                pbar.set_postfix({
                    'DL': stats['downloaded'],
                    'Skip': stats['skipped'],
                    'Fail': stats['failed']
                })
    
    # Summary
    print(f"\n{'='*60}")
    print(f"DOWNLOAD SUMMARY")
    print(f"{'='*60}")
    print(f"Downloaded:    {stats['downloaded']:,} files")
    print(f"Skipped:       {stats['skipped']:,} files (already exist)")
    print(f"Failed:        {stats['failed']:,} files")
    print(f"Total:         {len(files):,} files")
    print(f"Location:      {base_dir}")
    print(f"{'='*60}\n")

def main():
    parser = argparse.ArgumentParser(
        description='Download SAFEDOCS corpus (8M PDFs from Common Crawl)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Download tiny sample (1K PDFs, ~100 MB)
  %(prog)s --tier tiny
  
  # Download sample (10K PDFs, ~1 GB)
  %(prog)s --tier sample
  
  # Download medium sample (100K PDFs, ~10 GB)
  %(prog)s --tier medium --parallel 8
  
  # Download custom amount
  %(prog)s --limit 50000 --parallel 8
  
  # Download to custom path
  %(prog)s --tier sample --path /mnt/data
  
  # Download complete corpus (8M PDFs, ~800 GB)
  %(prog)s --tier complete --parallel 8

Available tiers:
  tiny      : 1K files    (~100 MB)
  sample    : 10K files   (~1 GB)
  small     : 50K files   (~5 GB)
  medium    : 100K files  (~10 GB)
  large     : 500K files  (~50 GB)
  xlarge    : 1M files    (~100 GB)
  xxlarge   : 2M files    (~200 GB)
  complete  : 8M files    (~800 GB)
        """
    )
    
    parser.add_argument('--tier', choices=DOWNLOAD_TIERS.keys(),
                        help='Download tier (see available tiers above)')
    parser.add_argument('--limit', type=int,
                        help='Custom file limit (overrides tier)')
    parser.add_argument('--path', type=str,
                        help='Custom download path (default: platform-specific)')
    parser.add_argument('--parallel', type=int, default=4,
                        help='Number of parallel downloads (default: 4, recommended: 4-8)')
    
    args = parser.parse_args()
    
    # Validate arguments
    if not args.tier and not args.limit:
        parser.error("Must specify either --tier or --limit")
    
    if args.tier and args.limit:
        parser.error("Cannot specify both --tier and --limit")
    
    # Determine base directory
    if args.path:
        custom_base = os.path.abspath(os.path.expanduser(args.path))
        # Only add SAFEDOCS if not already in the path
        if 'SAFEDOCS' not in custom_base:
            base_dir = os.path.join(custom_base, 'SAFEDOCS')
        else:
            base_dir = custom_base
    else:
        base_dir = DEFAULT_PATHS.get(sys.platform, DEFAULT_PATHS['linux'])
    
    # Create base directory
    os.makedirs(base_dir, exist_ok=True)
    
    # Start download
    download_safedocs(base_dir, tier=args.tier, limit=args.limit, parallel=args.parallel)

if __name__ == '__main__':
    main()

