# HOW TO USE - Quick Copy/Paste Commands

Simple guide with ready-to-use commands for each script.

---

## 🚀 Quick Setup (First Time Only)

```bash
# Clone repository
git clone https://github.com/viperdavethesnake/gathermedata.git
cd gathermedata

# Setup Python environment (Linux/macOS)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Windows PowerShell:** No setup needed, just run the `.ps1` scripts directly (requires PowerShell 7.0+)

---

## 📦 SCRIPT 1: Enterprise Sources (Mixed Public Data)

Downloads from 5 sources: Amazon, SEC, Federal Register, USASpending, GovDocs1

### Option 1: Download Sample (~8 GB)
```bash
# Linux/macOS - Default path
python download_enterprise_sources.py --mode sample

# Linux/macOS - Custom path
python download_enterprise_sources.py --mode sample --path /mnt/data

# Windows PowerShell
.\download_enterprise_sources.ps1 -Mode sample
.\download_enterprise_sources.ps1 -Mode sample -Path "D:\TestData"
```

### Option 2: Download Everything (~588 GB)
```bash
# Linux/macOS - Uses default path
python download_enterprise_sources.py --mode all

# Linux/macOS - Custom path
python download_enterprise_sources.py --mode all --path /storage/nas

# Windows PowerShell
.\download_enterprise_sources.ps1 -Mode all
.\download_enterprise_sources.ps1 -Mode all -Path "D:\Data"
```

### Option 3: Background Download (Linux/macOS)
```bash
# Using screen
screen -S enterprise
python download_enterprise_sources.py --mode all
# Detach: Ctrl+A then D
# Reattach: screen -r enterprise

# Using nohup
nohup python download_enterprise_sources.py --mode all > download.log 2>&1 &
tail -f download.log
```

---

## 📚 SCRIPT 2: GovDocs1 (Government Files)

Downloads 986K government files with 7 size tiers.

### Option 1: Download Tiny Sample (1K files, 540 MB)
```bash
# Linux/macOS
python download_govdocs.py --tier tiny

# Windows PowerShell
.\download_govdocs.ps1 -Tier tiny
```

### Option 2: Download Medium Sample (100K files, 54 GB)
```bash
# Linux/macOS - With 8 parallel downloads
python download_govdocs.py --tier medium --parallel 8

# Linux/macOS - Custom path
python download_govdocs.py --tier medium --parallel 8 --path /mnt/nas

# Windows PowerShell
.\download_govdocs.ps1 -Tier medium -Parallel 8
.\download_govdocs.ps1 -Tier medium -Parallel 8 -Path "D:\GovDocs"
```

### Option 3: Download Custom Range (Threads 100-199, ~100K files)
```bash
# Linux/macOS
python download_govdocs.py --threads 100 --start 100 --parallel 8

# Windows PowerShell
.\download_govdocs.ps1 -Threads 100 -Start 100 -Parallel 8
```

### Option 4: Download EVERYTHING (986K files, 540 GB)
```bash
# Linux/macOS - Recommended to run in screen
screen -S govdocs-complete
python download_govdocs.py --tier complete --parallel 8
# Detach: Ctrl+A then D

# Windows PowerShell (will prompt for confirmation)
.\download_govdocs.ps1 -Tier complete -Parallel 8
```

---

## 🔬 SCRIPT 3: Digital Corpora (Forensic Scenarios)

Downloads forensic scenarios with disk images, memory dumps, and network captures.

### Option 1: List Available Content
```bash
# Linux/macOS - List all scenarios
python download_digitalcorpora.py --list-scenarios

# Linux/macOS - List all file corpora
python download_digitalcorpora.py --list-corpora

# Windows PowerShell
.\download_digitalcorpora.ps1 -ListScenarios
.\download_digitalcorpora.ps1 -ListCorpora
```

### Option 2: Download Small Scenario (25 GB)
```bash
# Linux/macOS - Starter scenario
python download_digitalcorpora.py --scenario 2008-nitroba

# Linux/macOS - With 8 parallel downloads
python download_digitalcorpora.py --scenario 2008-nitroba --parallel 8

# Windows PowerShell
.\download_digitalcorpora.ps1 -Scenario "2008-nitroba" -Parallel 8
```

### Option 3: Download Medium Scenarios (79-112 GB)
```bash
# Linux/macOS - Lone Wolf scenario (79 GB)
python download_digitalcorpora.py --scenario 2018-lonewolf --parallel 8

# Linux/macOS - National Gallery DC (112 GB)
python download_digitalcorpora.py --scenario 2012-ngdc --parallel 8 --path /mnt/forensics

# Windows PowerShell
.\download_digitalcorpora.ps1 -Scenario "2018-lonewolf" -Parallel 8
```

### Option 4: Download File Corpus
```bash
# Linux/macOS - Audio files
python download_digitalcorpora.py --corpus 2009-audio

# Linux/macOS - Media with limit
python download_digitalcorpora.py --corpus media1 --limit 1000 --parallel 8

# Linux/macOS - Large PDF corpus subset
python download_digitalcorpora.py --corpus CC-MAIN-2021-31-PDF-UNTRUNCATED --limit 10000 --parallel 8

# Windows PowerShell
.\download_digitalcorpora.ps1 -Corpus "2009-audio"
.\download_digitalcorpora.ps1 -Corpus "media1" -Limit 1000
```

### Option 5: Download Large Scenario (150-223 GB)
```bash
# Linux/macOS - Narcos scenario (153 GB) - Use screen!
screen -S narcos
python download_digitalcorpora.py --scenario 2019-narcos --parallel 8
# Detach: Ctrl+A then D

# Linux/macOS - Owl scenario (223 GB) - Largest scenario
screen -S owl
python download_digitalcorpora.py --scenario 2019-owl --parallel 8 --path /storage/forensics
# Detach: Ctrl+A then D
```

---

## 💡 Common Use Cases

### Use Case 1: Quick NAS Test (~10 GB)
```bash
# Download small samples from all sources
python download_enterprise_sources.py --mode sample
python download_govdocs.py --tier tiny
```

### Use Case 2: Comprehensive NAS Test (~100 GB)
```bash
# Medium-sized datasets for thorough testing
python download_enterprise_sources.py --mode sample
python download_govdocs.py --tier medium --parallel 8
python download_digitalcorpora.py --scenario 2008-nitroba
```

### Use Case 3: Forensics Research (~200 GB)
```bash
# Focus on forensic scenarios
python download_digitalcorpora.py --scenario 2018-lonewolf --parallel 8
python download_digitalcorpora.py --scenario 2012-ngdc --parallel 8
python download_govdocs.py --tier small
```

### Use Case 4: Download EVERYTHING to Same Base Directory
```bash
# All scripts to /storage/nexus (organized in subfolders)
python download_enterprise_sources.py --mode all --path /storage/nexus
python download_govdocs.py --tier complete --parallel 8 --path /storage/nexus
python download_digitalcorpora.py --scenario 2019-owl --parallel 8 --path /storage/nexus

# Results in:
# /storage/nexus/
# ├── 1_Office_Docs_GovDocs/
# ├── 2_Federal_Contracts.../
# ├── GovDocs1/
# └── DigitalCorpora/
```

---

## 🖥️ Platform-Specific Quick Starts

### Linux (with ZFS compression)
```bash
# Setup ZFS dataset with compression
sudo zfs create -o compression=zstd storage/nexus

# Download to ZFS dataset
cd /space/projects/gathermedata
source venv/bin/activate
python download_govdocs.py --tier medium --parallel 8 --path /storage/nexus
```

### macOS (prevent sleep)
```bash
# Use caffeinate to prevent sleep during download
cd gathermedata
source venv/bin/activate
caffeinate -i python download_enterprise_sources.py --mode all
```

### Windows PowerShell
```powershell
# Navigate to project and run
cd C:\Projects\gathermedata
.\download_govdocs.ps1 -Tier medium -Parallel 8 -Path "D:\Data"
```

---

## 📊 Download Size Reference

### Enterprise Sources (download_enterprise_sources.*)
- **Sample**: ~8 GB
- **All**: ~588 GB

### GovDocs1 (download_govdocs.*)
- **tiny**: 540 MB (1K files)
- **sample**: 5.4 GB (10K files)
- **small**: 27 GB (50K files)
- **medium**: 54 GB (100K files)
- **large**: 135 GB (250K files)
- **xlarge**: 270 GB (500K files)
- **complete**: 540 GB (986K files)

### Digital Corpora (download_digitalcorpora.*)
- **2008-nitroba**: 25 GB (smallest scenario)
- **2018-lonewolf**: 79 GB
- **2019-tuck**: 100 GB
- **2012-ngdc**: 112 GB
- **2009-m57-patents**: 150 GB
- **2019-narcos**: 153 GB
- **2019-owl**: 223 GB (largest scenario)
- **All 7 scenarios**: ~842 GB

---

## 🔍 Monitoring Downloads

### Check Progress (from another terminal)
```bash
# Watch file count
watch -n 10 'find /storage/nexus -type f | wc -l'

# Check disk usage
du -sh /storage/nexus/*

# On ZFS - check compression ratio
sudo zfs get compressratio storage/nexus
```

### Check Running Downloads
```bash
# See if scripts are running
ps aux | grep download_

# Check network activity
nethogs  # or
iftop    # Shows bandwidth usage
```

---

## ⚠️ Important Notes

1. **Always use `--parallel 8` for faster downloads** (4-8 recommended)
2. **Use `screen` or `tmux` for large downloads** (they take hours)
3. **Check disk space first**: `df -h`
4. **Enable filesystem compression** if possible (saves ~50% space)
5. **Resume capability**: All scripts skip existing files, safe to re-run

---

## 🆘 Quick Troubleshooting

### Download stopped?
```bash
# Just re-run the same command - it will resume
python download_govdocs.py --tier medium --parallel 8
```

### Out of space?
```bash
# Check space
df -h

# Use smaller tier
python download_govdocs.py --tier small  # Instead of medium
```

### Too slow?
```bash
# Increase parallel workers
python download_govdocs.py --tier medium --parallel 8  # Instead of 4
```

### Script not executable?
```bash
chmod +x *.py *.ps1
```

---

## 📚 More Information

- **Main README**: [README.md](README.md)
- **Windows Guide**: [README_WINDOWS.md](README_WINDOWS.md)
- **macOS Guide**: [README_MACOS.md](README_MACOS.md)
- **GovDocs Details**: [README_GOVDOCS.md](README_GOVDOCS.md)
- **Digital Corpora Details**: [README_DIGITALCORPORA.md](README_DIGITALCORPORA.md)

