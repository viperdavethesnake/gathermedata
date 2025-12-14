# Digital Corpora Downloader

Dedicated script for downloading forensic scenarios and file corpora from [DigitalCorpora.org](https://digitalcorpora.org).

## About Digital Corpora

Digital Corpora provides forensic research data including:
- **Forensic Scenarios**: Complete incident simulations with disk images, memory dumps, and network captures
- **File Corpora**: Collections of various file types (PDFs, audio, video, media)
- **SAFEDOCS & UNSAFE-DOCS**: Massive PDF collections from Common Crawl

All data is freely available for research and education, sponsored by the AWS Open Data Program.

## What's Available

### Forensic Scenarios (7 scenarios)

Complete forensic investigation scenarios with disk images, network captures, and memory dumps:

| Scenario | Description | Size | Files |
|----------|-------------|------|-------|
| **2008-nitroba** | Network forensics harassment scenario | ~25 GB | 15 |
| **2009-m57-patents** | Complex scenario with multiple drives/actors | ~150 GB | 50 |
| **2012-ngdc** | Fictional attack on National Gallery DC | ~112 GB | 161 |
| **2018-lonewolf** | Laptop seizure - mass shooting suspect | ~79 GB | 19 |
| **2019-narcos** | Customs interception - illegal activity | ~153 GB | 16 |
| **2019-owl** | Illegal trade of owls investigation | ~223 GB | 29 |
| **2019-tuck** | Joining terrorist organization attempt | ~100 GB | 10 |

**Total**: ~842 GB for all scenarios

### File Corpora

Standard collections of various file types:

| Corpus | Description |
|--------|-------------|
| **2008-pdfs** | PDF files from 2008 |
| **2009-audio** | Audio file corpus |
| **2009-video** | Video file corpus |
| **media1** | Mixed media files collection |
| **media2** | Additional media files |

### Large PDF Corpora (MASSIVE!)

⚠️ **Warning**: These are multi-TB collections. Use `--limit` to download subsets.

| Corpus | Files | Size | Description |
|--------|-------|------|-------------|
| **CC-MAIN-2021-31-PDF-UNTRUNCATED** | ~8M PDFs | Several TB | SAFEDOCS - PDFs from Common Crawl |
| **CC-MAIN-2021-31-UNSAFE** | ~5.5M files | Several TB | UNSAFE-DOCS - PDFs + other files |

## Installation

```bash
# Same requirements as main data_loader
pip install -r requirements.txt
```

**Note**: For PowerShell, AWS.Tools.S3 module is recommended but not required:
```powershell
Install-Module -Name AWS.Tools.S3 -Force
```

## Usage

### List Available Content

**Python:**
```bash
# List all forensic scenarios
python download_digitalcorpora.py --list-scenarios

# List all file corpora
python download_digitalcorpora.py --list-corpora
```

**PowerShell:**
```powershell
# List all forensic scenarios
.\download_digitalcorpora.ps1 -ListScenarios

# List all file corpora
.\download_digitalcorpora.ps1 -ListCorpora
```

### Download Forensic Scenarios

**Python:**
```bash
# Download a scenario
python download_digitalcorpora.py --scenario 2018-lonewolf

# With custom path and 8 parallel downloads
python download_digitalcorpora.py --scenario 2019-narcos --path /mnt/nas/forensics --parallel 8

# Smaller scenario for testing
python download_digitalcorpora.py --scenario 2008-nitroba
```

**PowerShell:**
```powershell
# Download a scenario
.\download_digitalcorpora.ps1 -Scenario "2018-lonewolf"

# With custom path and parallel downloads
.\download_digitalcorpora.ps1 -Scenario "2019-narcos" -Path "D:\Forensics" -Parallel 8
```

### Download File Corpora

**Python:**
```bash
# Download entire corpus
python download_digitalcorpora.py --corpus 2009-audio

# Download with file limit
python download_digitalcorpora.py --corpus media1 --limit 1000

# Large corpus with limit (recommended)
python download_digitalcorpora.py --corpus CC-MAIN-2021-31-PDF-UNTRUNCATED --limit 10000 --parallel 8
```

**PowerShell:**
```powershell
# Download corpus
.\download_digitalcorpora.ps1 -Corpus "2009-audio"

# With file limit
.\download_digitalcorpora.ps1 -Corpus "media1" -Limit 1000
```

## Default Paths

| Platform | Default Path |
|----------|-------------|
| Linux | `/storage/nexus/DigitalCorpora` |
| macOS | `~/Downloads/DigitalCorpora` |
| Windows | `S:\DigitalCorpora` |

Override with `--path` (Python) or `-Path` (PowerShell)

## Directory Structure

```
DigitalCorpora/
├── scenarios/
│   ├── 2018-lonewolf/
│   │   ├── (disk images, memory dumps, network captures)
│   ├── 2019-narcos/
│   └── 2019-owl/
└── file_corpora/
    ├── 2009-audio/
    ├── 2009-video/
    ├── media1/
    └── CC-MAIN-2021-31-PDF-UNTRUNCATED/
```

## Features

### Python Version (`download_digitalcorpora.py`)
- ✅ Parallel downloads with ThreadPoolExecutor
- ✅ Progress bars with tqdm
- ✅ Resume capability (skips existing files)
- ✅ Automatic retry on failures
- ✅ Custom download paths
- ✅ File limits for large corpora
- ✅ Direct S3 access via boto3

### PowerShell Version (`download_digitalcorpora.ps1`)
- ✅ Optional AWS.Tools.S3 integration
- ✅ HTTP fallback if AWS Tools unavailable
- ✅ Parallel downloads
- ✅ Custom download paths
- ✅ File limits for large corpora
- ✅ Confirmation prompts for large downloads

## Download Recommendations

### For Learning/Testing
Start with smaller scenarios:
```bash
# Best starter scenario (25 GB)
python download_digitalcorpora.py --scenario 2008-nitroba

# Good for testing (79 GB)
python download_digitalcorpora.py --scenario 2018-lonewolf
```

### For Comprehensive Testing
Medium-sized scenarios:
```bash
python download_digitalcorpora.py --scenario 2012-ngdc  # 112 GB
```

### For Advanced Research
Large, complex scenarios:
```bash
python download_digitalcorpora.py --scenario 2019-owl  # 223 GB
python download_digitalcorpora.py --scenario 2009-m57-patents  # 150 GB
```

### For File Type Testing
```bash
# Audio files
python download_digitalcorpora.py --corpus 2009-audio

# Video files
python download_digitalcorpora.py --corpus 2009-video

# Mixed media
python download_digitalcorpora.py --corpus media1 --limit 5000
```

## Estimated Download Times

| Scenario/Corpus | Size | Time @ 100 Mbps | Time @ 1 Gbps |
|-----------------|------|-----------------|---------------|
| 2008-nitroba | 25 GB | ~33 min | ~3 min |
| 2018-lonewolf | 79 GB | ~1.7 hours | ~10 min |
| 2012-ngdc | 112 GB | ~2.5 hours | ~15 min |
| 2019-narcos | 153 GB | ~3.4 hours | ~20 min |
| 2009-m57-patents | 150 GB | ~3.3 hours | ~20 min |
| 2019-tuck | 100 GB | ~2.2 hours | ~13 min |
| 2019-owl | 223 GB | ~5 hours | ~30 min |
| **All scenarios** | **~842 GB** | **~18 hours** | **~1.8 hours** |

## Running in Background

### Using screen (recommended for Linux/macOS)

```bash
# Start screen session
screen -S digitalcorpora

# Run download
python download_digitalcorpora.py --scenario 2019-narcos --parallel 8

# Detach: Ctrl+A then D
# Reattach: screen -r digitalcorpora
```

### Using nohup (Linux/macOS)

```bash
nohup python download_digitalcorpora.py --scenario 2019-owl > download.log 2>&1 &
tail -f download.log
```

### Using tmux (Linux/macOS)

```bash
tmux new -s forensics
python download_digitalcorpora.py --scenario 2012-ngdc --parallel 8
# Detach: Ctrl+B then D
# Reattach: tmux attach -t forensics
```

## Performance Tips

### 1. Use Parallel Downloads
```bash
# Increase parallel workers for faster downloads
python download_digitalcorpora.py --scenario 2018-lonewolf --parallel 8
```

### 2. Use Local Storage First
- Download to local SSD/HDD first
- Then move to NAS to avoid network bottlenecks

### 3. For Large Corpora, Use Limits
```bash
# Don't try to download all 8M PDFs at once
python download_digitalcorpora.py --corpus CC-MAIN-2021-31-PDF-UNTRUNCATED --limit 100000 --parallel 8
```

### 4. Monitor Disk Space
```bash
# Check available space before large downloads
df -h /storage/nexus

# Monitor during download
watch -n 10 'df -h /storage/nexus'
```

## What's in the Scenarios?

Each forensic scenario typically includes:
- **Disk Images**: E01 format, full disk or partitions
- **Memory Dumps**: RAM captures from systems
- **Network Captures**: PCAP files of network traffic
- **Documentation**: Case details, timelines, actor information
- **Metadata**: DFXML files describing file structures

## Use Cases

### Education
- Teaching digital forensics courses
- Training incident response teams
- Practicing forensic tool usage

### Research
- Testing new forensic tools
- Benchmark comparisons
- Algorithm development
- File format analysis

### Professional Development
- Certification preparation
- Skill maintenance
- Team exercises
- Competition preparation

## Troubleshooting

### Download Stuck/Slow
- Check internet connection
- Verify firewall isn't blocking S3
- Try reducing parallel workers (`--parallel 2`)
- Use wired connection instead of Wi-Fi

### Out of Disk Space
- Use smaller scenarios first (2008-nitroba)
- Use `--limit` for file corpora
- Enable filesystem compression (ZFS, BTRFS)
- Check available space: `df -h`

### AWS/boto3 Issues (Python)
```bash
# Reinstall boto3
pip install --upgrade boto3 botocore
```

### PowerShell AWS Tools Issues
```powershell
# Install/update AWS Tools
Install-Module -Name AWS.Tools.S3 -Force -AllowClobber
```

## Citation

If using this data in research, please cite:

**Garfinkel, Farrell, Roussev and Dinolt, "Bringing Science to Digital Forensics with Standardized Forensic Corpora", DFRWS 2009, Montreal, Canada**

## Related Scripts

- **download_govdocs.py**: Dedicated GovDocs1 downloader (986K files)
- **data_loader.py**: Multi-source data loader (5 sources)

## Additional Resources

- [Digital Corpora Website](https://digitalcorpora.org)
- [Digital Corpora S3 Bucket](https://s3.amazonaws.com/digitalcorpora/index.html)
- [AWS Open Data Program](https://registry.opendata.aws/digitalcorpora/)

