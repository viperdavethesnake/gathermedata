#!/usr/bin/env python3
"""
Digital Corpora Scenarios Downloader - Downloads forensic scenarios and file corpora
Source: https://digitalcorpora.org

Includes:
- Forensic Scenarios (disk images, network captures, memory dumps)
- Small File Corpora (PDFs, audio, video, and other file types)

For massive PDF collections use dedicated scripts:
- GovDocs1 (986K files): use download_govdocs.py
- SAFEDOCS (8M PDFs): use download_safedocs.py
- UNSAFE-DOCS (5.3M+ files): use download_unsafedocs.py
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
    'linux': '/storage/nexus/DigitalCorpora',
    'darwin': os.path.expanduser('~/Downloads/DigitalCorpora'),
    'win32': 'S:\\DigitalCorpora'
}

S3_BUCKET = 'digitalcorpora'
MAX_RETRIES = 3
RETRY_DELAY = 2

# Forensic Scenarios
SCENARIOS = {
    '2018-lonewolf': {
        'name': '2018 Lone Wolf Scenario',
        'description': 'Laptop seizure of fictional person planning mass shooting',
        'size': '~79 GB',
        'files': 19
    },
    '2019-narcos': {
        'name': '2019 Narcos',
        'description': 'Passengers intercepted by customs for illegal activity',
        'size': '~153 GB',
        'files': 16
    },
    '2019-owl': {
        'name': '2019 Owl',
        'description': 'Illegal trade of owls scenario',
        'size': '~223 GB',
        'files': 29
    },
    '2019-tuck': {
        'name': '2019 Tuck',
        'description': 'Person attempting to join terrorist organization',
        'size': '~100 GB',
        'files': 10
    },
    '2012-ngdc': {
        'name': '2012 National Gallery DC',
        'description': 'Fictional attack on National Gallery DC',
        'size': '~112 GB',
        'files': 161
    },
    '2009-m57-patents': {
        'name': '2009 M57 Patents',
        'description': 'Complex scenario with multiple drives and actors',
        'size': '~150 GB',
        'files': 50
    },
    '2008-nitroba': {
        'name': '2008 Nitroba University',
        'description': 'Network forensics harassment scenario',
        'size': '~25 GB',
        'files': 15
    }
}

# File Corpora (excluding GovDocs1, SAFEDOCS, UNSAFE-DOCS - use dedicated scripts)
FILE_CORPORA = {
    '2008-pdfs': {
        'name': '2008 PDFs Collection',
        'description': 'Various PDF files from 2008',
        'category': 'documents'
    },
    '2009-audio': {
        'name': '2009 Audio Files',
        'description': 'Audio file corpus',
        'category': 'media'
    },
    '2009-video': {
        'name': '2009 Video Files',
        'description': 'Video file corpus',
        'category': 'media'
    },
    'media1': {
        'name': 'Media Corpus 1',
        'description': 'Mixed media files collection',
        'category': 'media'
    },
    'media2': {
        'name': 'Media Corpus 2',
        'description': 'Additional media files',
        'category': 'media'
    }
}

# Note: SAFEDOCS and UNSAFE-DOCS moved to dedicated scripts:
# - download_safedocs.py (8M PDFs, 8 tiers)
# - download_unsafedocs.py (5.3M+ files, 8 tiers)

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

def download_file_from_s3(s3_client, bucket, key, local_path):
    """Download a single file from S3"""
    try:
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        s3_client.download_file(bucket, key, local_path)
        return True
    except Exception as e:
        print(f"Failed to download {key}: {e}")
        return False

def download_scenario(scenario_id, base_dir, parallel=4):
    """Download a complete forensic scenario"""
    if scenario_id not in SCENARIOS:
        print(f"Unknown scenario: {scenario_id}")
        return False
    
    info = SCENARIOS[scenario_id]
    print(f"\nDownloading: {info['name']}")
    print(f"  Description: {info['description']}")
    print(f"  Size: {info['size']}")
    print(f"  Files: {info['files']}")
    print()
    
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    prefix = f"corpora/scenarios/{scenario_id}/"
    scenario_dir = os.path.join(base_dir, 'scenarios', scenario_id)
    
    # List all files
    print("  -> Listing files...")
    paginator = s3.get_paginator('list_objects_v2')
    files_to_download = []
    
    for page in paginator.paginate(Bucket=S3_BUCKET, Prefix=prefix):
        for obj in page.get('Contents', []):
            key = obj['Key']
            if key.endswith('/'):  # Skip directories
                continue
            
            relative_path = key.replace(prefix, '')
            local_path = os.path.join(scenario_dir, relative_path)
            
            if not os.path.exists(local_path):
                files_to_download.append((key, local_path, obj['Size']))
    
    if not files_to_download:
        print("  -> All files already downloaded!")
        return True
    
    print(f"  -> Downloading {len(files_to_download)} files...")
    
    # Download with progress bar
    with tqdm(total=len(files_to_download), desc="  Files", unit="file") as pbar:
        with ThreadPoolExecutor(max_workers=parallel) as executor:
            futures = {
                executor.submit(download_file_from_s3, s3, S3_BUCKET, key, local_path): (key, local_path)
                for key, local_path, size in files_to_download
            }
            
            for future in as_completed(futures):
                result = future.result()
                pbar.update(1)
    
    print(f"  ✓ Scenario '{scenario_id}' complete!")
    return True

def download_file_corpus(corpus_id, base_dir, max_files=None, parallel=4):
    """Download a file corpus"""
    if corpus_id not in FILE_CORPORA and corpus_id not in LARGE_CORPORA:
        print(f"Unknown corpus: {corpus_id}")
        return False
    
    info = FILE_CORPORA.get(corpus_id) or LARGE_CORPORA.get(corpus_id)
    print(f"\nDownloading: {info['name']}")
    print(f"  Description: {info['description']}")
    if max_files:
        print(f"  Limit: {max_files} files")
    print()
    
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    prefix = f"corpora/files/{corpus_id}/"
    corpus_dir = os.path.join(base_dir, 'file_corpora', corpus_id)
    
    # List files
    print("  -> Listing files...")
    paginator = s3.get_paginator('list_objects_v2')
    files_to_download = []
    
    for page in paginator.paginate(Bucket=S3_BUCKET, Prefix=prefix):
        for obj in page.get('Contents', []):
            if max_files and len(files_to_download) >= max_files:
                break
            
            key = obj['Key']
            if key.endswith('/'):
                continue
            
            relative_path = key.replace(prefix, '')
            local_path = os.path.join(corpus_dir, relative_path)
            
            if not os.path.exists(local_path):
                files_to_download.append((key, local_path, obj['Size']))
        
        if max_files and len(files_to_download) >= max_files:
            break
    
    if not files_to_download:
        print("  -> All files already downloaded!")
        return True
    
    print(f"  -> Downloading {len(files_to_download)} files...")
    
    with tqdm(total=len(files_to_download), desc="  Files", unit="file") as pbar:
        with ThreadPoolExecutor(max_workers=parallel) as executor:
            futures = {
                executor.submit(download_file_from_s3, s3, S3_BUCKET, key, local_path): (key, local_path)
                for key, local_path, size in files_to_download
            }
            
            for future in as_completed(futures):
                result = future.result()
                pbar.update(1)
    
    print(f"  ✓ Corpus '{corpus_id}' complete!")
    return True

def list_scenarios():
    """List all available scenarios"""
    print("\n" + "="*70)
    print("AVAILABLE FORENSIC SCENARIOS")
    print("="*70)
    print(f"{'ID':<25} | {'Name':<30} | {'Size':<12}")
    print("-"*70)
    
    for scenario_id, info in SCENARIOS.items():
        print(f"{scenario_id:<25} | {info['name']:<30} | {info['size']:<12}")
    
    print("="*70)
    print(f"\nTotal: {len(SCENARIOS)} scenarios")
    print("\nExamples:")
    print("  python download_digitalcorpora.py --scenario 2018-lonewolf")
    print("  python download_digitalcorpora.py --scenario 2019-narcos --parallel 8")
    print()

def list_corpora():
    """List all available file corpora"""
    print("\n" + "="*70)
    print("AVAILABLE FILE CORPORA")
    print("="*70)
    
    print("\nStandard File Corpora:")
    print("-"*70)
    for corpus_id, info in FILE_CORPORA.items():
        print(f"  • {corpus_id:<25} - {info['name']}")
        print(f"    {info['description']}")
    
    print("\nLarge PDF Corpora (MASSIVE - Several TB each):")
    print("-"*70)
    for corpus_id, info in LARGE_CORPORA.items():
        print(f"  • {corpus_id}")
        print(f"    {info['description']}")
        print(f"    Size: {info['size']}, Files: {info['files']}")
    
    print("="*70)
    print("\nExamples:")
    print("  python download_digitalcorpora.py --corpus 2009-audio")
    print("  python download_digitalcorpora.py --corpus media1 --limit 1000")
    print()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Download forensic scenarios and file corpora from Digital Corpora',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --list-scenarios              # List all scenarios
  %(prog)s --list-corpora                # List all file corpora
  %(prog)s --scenario 2018-lonewolf      # Download single scenario
  %(prog)s --corpus 2009-audio           # Download file corpus
  %(prog)s --scenario 2019-narcos --path /mnt/nas --parallel 8
        """
    )
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--list-scenarios', action='store_true',
                      help='List available forensic scenarios')
    group.add_argument('--list-corpora', action='store_true',
                      help='List available file corpora')
    group.add_argument('--scenario', type=str,
                      help='Download a specific scenario')
    group.add_argument('--corpus', type=str,
                      help='Download a specific file corpus')
    
    parser.add_argument('--path', type=str, default=None,
                       help='Download path (default: platform-specific)')
    parser.add_argument('--parallel', type=int, default=4,
                       help='Number of parallel downloads (default: 4)')
    parser.add_argument('--limit', type=int, default=None,
                       help='Limit number of files for corpus downloads')
    
    args = parser.parse_args()
    
    if args.list_scenarios:
        list_scenarios()
        sys.exit(0)
    
    if args.list_corpora:
        list_corpora()
        sys.exit(0)
    
    # Determine base directory
    if args.path:
        # If user provides custom path, ensure DigitalCorpora subfolder
        custom_base = os.path.abspath(os.path.expanduser(args.path))
        # Only add DigitalCorpora if not already in the path
        if 'DigitalCorpora' not in custom_base:
            base_dir = os.path.join(custom_base, 'DigitalCorpora')
        else:
            base_dir = custom_base
    else:
        base_dir = DEFAULT_PATHS.get(sys.platform, DEFAULT_PATHS['linux'])
    
    print(f"\n{'='*60}")
    print("DIGITAL CORPORA DOWNLOADER")
    print(f"{'='*60}")
    print(f"Download path: {base_dir}")
    print(f"Parallel workers: {args.parallel}")
    print(f"{'='*60}")
    
    start_time = time.time()
    
    if args.scenario:
        success = download_scenario(args.scenario, base_dir, args.parallel)
    elif args.corpus:
        success = download_file_corpus(args.corpus, base_dir, args.limit, args.parallel)
    
    elapsed = time.time() - start_time
    
    print(f"\n[*] Total time: {elapsed/60:.1f} minutes")
    print("[*] DONE.")

