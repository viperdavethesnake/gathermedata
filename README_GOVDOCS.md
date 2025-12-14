# GovDocs1 Dedicated Downloader

Standalone script for downloading the GovDocs1 corpus - nearly 1 million real government files from .gov domains.

## About GovDocs1

**Source**: [Digital Corpora](https://digitalcorpora.org/corpora/file-corpora/files/)

The GovDocs1 corpus contains ~986,000 files downloaded from US Government (.gov) web servers. Files include:
- Microsoft Office documents (DOC, XLS, PPT)
- PDFs
- HTML pages
- Images
- And many other file types

This is real-world data collected by searching .gov domains, making it perfect for:
- Document processing testing
- File format analysis
- Digital forensics research
- NAS performance testing

## Download Tiers

| Tier | Threads | Files | Size | Use Case |
|------|---------|-------|------|----------|
| **tiny** | 1 | ~1,000 | ~540 MB | Quick test |
| **sample** | 10 | ~10,000 | ~5.4 GB | Development/testing |
| **small** | 50 | ~50,000 | ~27 GB | Substantial test dataset |
| **medium** | 100 | ~100,000 | ~54 GB | Large representative sample |
| **large** | 250 | ~250,000 | ~135 GB | Quarter of full dataset |
| **xlarge** | 500 | ~500,000 | ~270 GB | Half of full dataset |
| **complete** | 1000 | ~986,000 | **~540 GB** | Complete corpus |

## Installation

```bash
# Same requirements as main data_loader
pip install -r requirements.txt
```

## Usage

### Using Tiers (Recommended)

```bash
# List all available tiers
python download_govdocs.py --list

# Download sample tier (10,000 files)
python download_govdocs.py --tier sample

# Download complete corpus (986,000 files)
python download_govdocs.py --tier complete

# With custom path
python download_govdocs.py --tier medium --path /mnt/nas/govdocs
```

### Custom Thread Range

```bash
# Download first 100 threads
python download_govdocs.py --threads 100

# Resume: Download threads 100-199
python download_govdocs.py --threads 100 --start 100

# Download specific range: threads 500-599
python download_govdocs.py --threads 100 --start 500
```

## Default Paths

| Platform | Default Path |
|----------|-------------|
| Linux | `/storage/nexus/GovDocs1` |
| macOS | `~/Downloads/GovDocs1` |
| Windows | `S:\GovDocs1` |

## Resume Capability

The script **automatically skips already-downloaded threads**, so you can:
- Stop and resume anytime
- Re-run safely (won't re-download)
- Download in chunks over multiple sessions

```bash
# Day 1: Download first 250 threads
python download_govdocs.py --threads 250

# Day 2: Download next 250 threads
python download_govdocs.py --threads 250 --start 250

# Or just run complete and it will skip 0-249
python download_govdocs.py --tier complete
```

## Running in Background

### Using screen (recommended)

```bash
# Start screen session
screen -S govdocs

# Run download
python download_govdocs.py --tier complete

# Detach: Ctrl+A then D
# Reattach: screen -r govdocs
```

### Using nohup

```bash
nohup python download_govdocs.py --tier complete > govdocs.log 2>&1 &
tail -f govdocs.log
```

### Using tmux

```bash
tmux new -s govdocs
python download_govdocs.py --tier complete
# Detach: Ctrl+B then D
# Reattach: tmux attach -t govdocs
```

## Performance Tips

### 1. Use Fast Storage
- SSD preferred over HDD
- Local storage faster than network mounts
- ZFS with compression recommended (saves ~45% space)

### 2. Network Optimization
- Use wired connection (faster than Wi-Fi)
- Close bandwidth-heavy applications
- Expect 1-5 hours for complete download (depends on connection)

### 3. Filesystem Compression
```bash
# Linux ZFS with zstd compression (recommended)
sudo zfs create -o compression=zstd storage/govdocs
python download_govdocs.py --tier complete --path /storage/govdocs

# Expected compression: 1.8-2.0x
# 540 GB logical → ~270-300 GB physical
```

## Estimated Download Times

| Tier | Size | Time @ 100 Mbps | Time @ 1 Gbps |
|------|------|-----------------|---------------|
| tiny | 540 MB | ~1 min | <1 min |
| sample | 5.4 GB | ~7 min | ~1 min |
| small | 27 GB | ~36 min | ~4 min |
| medium | 54 GB | ~72 min | ~7 min |
| large | 135 GB | ~3 hours | ~18 min |
| xlarge | 270 GB | ~6 hours | ~36 min |
| **complete** | **540 GB** | **~12 hours** | **~72 min** |

*Times are approximate and include extraction overhead*

## File Organization

```
GovDocs1/
├── 000/
│   ├── 000000.swf
│   ├── 000001.doc
│   ├── 000002.doc
│   └── ... (~1000 files)
├── 001/
│   └── ... (~1000 files)
├── 002/
...
└── 999/
    └── ... (~1000 files)
```

Each thread (000-999) contains approximately 1,000 files in a subdirectory.

## Monitoring Progress

```bash
# From another terminal - watch file count
watch -n 10 'find /storage/nexus/GovDocs1 -type f | wc -l'

# Check disk usage
du -sh /storage/nexus/GovDocs1

# On ZFS - check compression ratio
sudo zfs get compressratio storage/nexus
```

## What's in the Corpus?

- **File types**: 50+ different formats
- **Sources**: US Government web servers (.gov domains)
- **Collection method**: Random searches (words, numbers, combinations)
- **Time period**: Files from various years
- **Note**: Some files may contain malware (kept for forensic research purposes)

## Troubleshooting

### Download Stuck/Slow
- Check internet connection
- Verify no firewall blocking downloads.digitalcorpora.org
- Try resuming with --start parameter

### Out of Disk Space
- Use tier with less data
- Enable filesystem compression (ZFS, BTRFS)
- Use different path with more space

### Thread Failed to Download
- Script will retry 3 times automatically
- Check specific thread manually:
  ```bash
  curl -I https://downloads.digitalcorpora.org/corpora/files/govdocs1/zipfiles/050.zip
  ```

## Integration with Main Data Loader

The main `data_loader.py` script now uses reduced GovDocs1 settings:
- Sample mode: 2 threads
- All mode: 1000 threads (complete)

For more granular control, use this dedicated script instead.

## Citation

If using this data in research, please cite:

**Garfinkel, Farrell, Roussev and Dinolt, "Bringing Science to Digital Forensics with Standardized Forensic Corpora", DFRWS 2009, Montreal, Canada**

