#!/usr/bin/env python3
"""
GovDocs1 Downloader - Dedicated script for downloading the GovDocs1 corpus
~986,000 real government files from .gov domains

Source: https://digitalcorpora.org/corpora/file-corpora/files/
"""
import os
import sys
import requests
import zipfile
import io
import argparse
import time
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

# --- CONFIGURATION ---
DEFAULT_PATHS = {
    'linux': '/storage/nexus/GovDocs1',
    'darwin': os.path.expanduser('~/Downloads/GovDocs1'),
    'win32': 'S:\\GovDocs1'
}

BASE_URL = "https://downloads.digitalcorpora.org/corpora/files/govdocs1/zipfiles/"
MAX_RETRIES = 3
RETRY_DELAY = 2

# Download tiers - you can customize these
DOWNLOAD_TIERS = {
    'tiny': {
        'threads': 1,
        'files': '~1,000',
        'size': '~540 MB',
        'description': 'Minimal test set'
    },
    'sample': {
        'threads': 10,
        'files': '~10,000',
        'size': '~5.4 GB',
        'description': 'Good for development/testing'
    },
    'small': {
        'threads': 50,
        'files': '~50,000',
        'size': '~27 GB',
        'description': 'Substantial test dataset'
    },
    'medium': {
        'threads': 100,
        'files': '~100,000',
        'size': '~54 GB',
        'description': 'Large representative sample'
    },
    'large': {
        'threads': 250,
        'files': '~250,000',
        'size': '~135 GB',
        'description': 'Quarter of full dataset'
    },
    'xlarge': {
        'threads': 500,
        'files': '~500,000',
        'size': '~270 GB',
        'description': 'Half of full dataset'
    },
    'complete': {
        'threads': 1000,
        'files': '~986,000',
        'size': '~540 GB',
        'description': 'Complete GovDocs1 corpus'
    }
}

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

def download_single_thread(thread_num, base_dir):
    """Download a single GovDocs1 thread"""
    thread_id = f"{thread_num:03d}.zip"
    url = BASE_URL + thread_id
    thread_dir = os.path.join(base_dir, f"{thread_num:03d}")
    
    # Check if already downloaded
    if os.path.exists(thread_dir) and len(os.listdir(thread_dir)) > 0:
        return ('skipped', thread_num, 0)
    
    @retry_download
    def fetch_thread():
        r = requests.get(url, stream=True, timeout=120)
        if r.status_code == 200:
            total_size = int(r.headers.get('content-length', 0))
            
            # Download to memory
            content = io.BytesIO()
            for chunk in r.iter_content(chunk_size=8192):
                content.write(chunk)
            
            # Extract
            content.seek(0)
            z = zipfile.ZipFile(content)
            z.extractall(thread_dir)
            
            file_count = len(z.namelist())
            return file_count
        else:
            return None
    
    result = fetch_thread()
    if result:
        return ('success', thread_num, result)
    else:
        return ('failed', thread_num, 0)

def download_govdocs(base_dir, num_threads, start_thread=0, parallel_workers=4):
    """
    Download GovDocs1 threads with parallel processing
    
    Args:
        base_dir: Base directory for downloads
        num_threads: Number of threads to download
        start_thread: Starting thread number (for resume capability)
        parallel_workers: Number of parallel downloads (default: 4)
    """
    print(f"\nDownloading GovDocs1 Corpus")
    print(f"  Threads: {start_thread} to {start_thread + num_threads - 1}")
    print(f"  Parallel workers: {parallel_workers}")
    print(f"  Target: {base_dir}")
    print()
    
    os.makedirs(base_dir, exist_ok=True)
    
    successful = 0
    failed = 0
    skipped = 0
    
    thread_range = range(start_thread, start_thread + num_threads)
    
    with ThreadPoolExecutor(max_workers=parallel_workers) as executor:
        # Submit all tasks
        futures = {executor.submit(download_single_thread, i, base_dir): i 
                   for i in thread_range}
        
        # Process results as they complete
        with tqdm(total=num_threads, desc="Overall Progress", unit="thread") as pbar:
            for future in as_completed(futures):
                status, thread_num, file_count = future.result()
                
                if status == 'success':
                    print(f"   ✓ Thread {thread_num:03d}: {file_count} files extracted")
                    successful += 1
                elif status == 'skipped':
                    skipped += 1
                else:  # failed
                    print(f"   ✗ Thread {thread_num:03d}: Failed")
                    failed += 1
                
                pbar.update(1)
    
    print(f"\n{'='*60}")
    print(f"DOWNLOAD SUMMARY")
    print(f"{'='*60}")
    print(f"Successful: {successful:,} threads")
    print(f"Failed:     {failed:,} threads")
    print(f"Skipped:    {skipped:,} threads (already downloaded)")
    print(f"Total:      {successful + skipped:,} threads")
    print(f"Location:   {os.path.abspath(base_dir)}")
    print(f"{'='*60}")
    
    # Calculate actual file count
    total_files = 0
    total_size = 0
    for root, dirs, files in os.walk(base_dir):
        total_files += len(files)
        for f in files:
            fp = os.path.join(root, f)
            if os.path.exists(fp):
                total_size += os.path.getsize(fp)
    
    size_gb = total_size / (1024**3)
    print(f"\nActual Data:")
    print(f"  Files: {total_files:,}")
    print(f"  Size:  {size_gb:.2f} GB")

def show_tiers():
    """Display available download tiers"""
    print("\n" + "="*70)
    print("GOVDOCS1 DOWNLOAD TIERS")
    print("="*70)
    print(f"{'Tier':<10} | {'Threads':<8} | {'Files':<12} | {'Size':<12} | Description")
    print("-"*70)
    
    for tier, info in DOWNLOAD_TIERS.items():
        print(f"{tier:<10} | {info['threads']:<8} | {info['files']:<12} | "
              f"{info['size']:<12} | {info['description']}")
    
    print("="*70)
    print("\nExamples:")
    print("  python download_govdocs.py --tier sample")
    print("  python download_govdocs.py --tier complete")
    print("  python download_govdocs.py --threads 100 --start 50  # Custom range")
    print()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Download GovDocs1 corpus - ~986K real government files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --tier sample              # Download 10,000 files (~5 GB)
  %(prog)s --tier complete            # Download complete corpus (~540 GB)
  %(prog)s --threads 100              # Download first 100 threads
  %(prog)s --threads 50 --start 100   # Download threads 100-149 (resume)
  %(prog)s --path /mnt/nas/govdocs    # Custom download location
        """
    )
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '--tier',
        choices=list(DOWNLOAD_TIERS.keys()),
        help='Download tier (use --list to see options)'
    )
    group.add_argument(
        '--threads',
        type=int,
        help='Number of threads to download (custom amount)'
    )
    group.add_argument(
        '--list',
        action='store_true',
        help='List available download tiers and exit'
    )
    
    parser.add_argument(
        '--start',
        type=int,
        default=0,
        help='Starting thread number (default: 0, max: 999)'
    )
    parser.add_argument(
        '--path',
        type=str,
        default=None,
        help='Download path (default: platform-specific)'
    )
    parser.add_argument(
        '--parallel',
        type=int,
        default=4,
        help='Number of parallel downloads (default: 4, max recommended: 8)'
    )
    
    args = parser.parse_args()
    
    # Show tiers and exit
    if args.list:
        show_tiers()
        sys.exit(0)
    
    # Determine number of threads
    if args.tier:
        num_threads = DOWNLOAD_TIERS[args.tier]['threads']
        tier_info = DOWNLOAD_TIERS[args.tier]
        print(f"\nSelected Tier: {args.tier.upper()}")
        print(f"  Threads: {num_threads}")
        print(f"  Files: {tier_info['files']}")
        print(f"  Size: {tier_info['size']}")
        print(f"  {tier_info['description']}")
    else:
        num_threads = args.threads
        print(f"\nCustom Download: {num_threads} threads")
    
    # Validate thread range
    if args.start < 0 or args.start >= 1000:
        print(f"Error: --start must be between 0 and 999 (got {args.start})")
        sys.exit(1)
    
    if args.start + num_threads > 1000:
        print(f"Warning: Adjusting threads from {num_threads} to {1000 - args.start} (max available)")
        num_threads = 1000 - args.start
    
    # Determine base directory
    if args.path:
        base_dir = os.path.abspath(os.path.expanduser(args.path))
    else:
        base_dir = DEFAULT_PATHS.get(sys.platform, DEFAULT_PATHS['linux'])
    
    print(f"\n{'='*60}")
    print("GOVDOCS1 DOWNLOADER")
    print(f"{'='*60}")
    print(f"Platform: {sys.platform}")
    print(f"Download path: {base_dir}")
    print(f"Thread range: {args.start:03d} to {args.start + num_threads - 1:03d}")
    print(f"{'='*60}")
    
    # Confirm for large downloads
    if num_threads >= 250:
        size_gb = num_threads * 0.54
        print(f"\n⚠️  WARNING: This will download ~{size_gb:.0f} GB")
        response = input("Continue? (yes/no): ")
        if response.lower() not in ['yes', 'y']:
            print("Aborted.")
            sys.exit(0)
    
    # Start download
    start_time = time.time()
    download_govdocs(base_dir, num_threads, args.start, args.parallel)
    elapsed = time.time() - start_time
    
    print(f"\n[*] Total time: {elapsed/60:.1f} minutes")
    print("[*] DONE.")

