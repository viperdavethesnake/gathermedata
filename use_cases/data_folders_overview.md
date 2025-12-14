# Data Folders Overview

This document provides a detailed understanding of each data folder downloaded to `/storage/nexus`.

**Total Dataset Summary:**
- **Total Size**: 1.3 GB
- **Total Files**: 2,315 files
- **Folders**: 7 distinct data categories

---

## 1. Office Documents - Government Files
**Path**: `/storage/nexus/1_Office_Docs_GovDocs/`

### Statistics
- **Size**: 481 MB
- **Files**: 981 files
- **Source**: GovDocs1 corpus (downloaded via `download_enterprise_sources.py`)

### File Type Distribution
- **PDF**: 200 files (most common)
- **HTML**: 181 files
- **TXT**: 154 files
- **DOC**: 111 files (Microsoft Word)
- **JPG**: 89 files
- **PPT**: 88 files (PowerPoint)
- **XLS**: 62 files (Excel)
- **Other**: GIF (23), PostScript (16), XML (12), CSV (11), RTF (4), SWF (4), etc.

### Content Description
Real government documents downloaded from `.gov` domains, including:
- Census data and demographic reports (CSV)
- Press releases and news articles (HTML)
- Administrative documents (DOC, PDF)
- Presentations and spreadsheets (PPT, XLS)
- Government web pages (HTML)

### Sample Content
- **HTML Example**: CBP press release about marijuana seizure ($3.2M smuggling attempt)
- **CSV Example**: Census household demographics, city population data
- **Legacy Formats**: Flash (SWF), PostScript (PS), WordPerfect (WP)

### Use Cases
- Document processing and parsing
- File format compatibility testing
- Legacy format support validation
- OCR and text extraction testing
- Digital forensics training

---

## 2. Federal Contracts - Financial Data
**Path**: `/storage/nexus/2_Federal_Contracts_USASpending/`

### Statistics
- **Size**: 225 KB
- **Files**: 48 files
- **Source**: USASpending.gov API (2023 contracts)

### File Structure
- **Format**: JSON (one file per contract)
- **Naming**: Award ID-based (e.g., `Z545.json`)

### Content Description
Structured financial data containing real federal contract information:
- Award ID and contract type
- Recipient names and organizations
- Award amounts (dollars)
- Start and end dates
- Awarding agency and sub-agency
- Contract descriptions
- Internal tracking IDs

### Sample Contract
```json
{
  "Award ID": "Z545",
  "Recipient Name": "VERTEX AEROSPACE LLC",
  "Award Amount": 2136663.45,
  "Description": "T-45 U.S.N. AIRCRAFT MAINTENANCE AND LOGISTICS SUPPORT",
  "Awarding Agency": "Department of Defense",
  "Contract Award Type": "DELIVERY ORDER"
}
```

### Use Cases
- JSON parsing and validation
- Financial data analysis
- Government spending research
- Structured data ETL pipelines
- Contract management systems testing

---

## 3. Warehouse Images - Computer Vision
**Path**: `/storage/nexus/3_Warehouse_Images_Amazon/`

### Statistics
- **Size**: 2.8 MB
- **Files**: 50 files
- **Source**: Amazon Bin Image Dataset (AWS S3)

### Image Specifications
- **Format**: JPEG (JFIF 1.01)
- **Encoding**: Baseline, 8-bit precision, 3 components (RGB)
- **Dimensions**: Variable (299x317 to 616x586 pixels typical)
- **File Size**: 23 KB to 85 KB per image

### Content Description
Real product bin photos from Amazon fulfillment centers showing:
- Multiple products in warehouse bins
- Various angles and lighting conditions
- Different bin configurations
- Product packaging and arrangements

### Use Cases
- Computer vision model training
- Object detection and classification
- Image processing pipelines
- Storage and retrieval systems
- Thumbnail generation testing
- Image compression analysis

---

## 4. Financial Statements - SEC EDGAR
**Path**: `/storage/nexus/4_Financial_Statements_SEC/`

### Statistics
- **Size**: 139 MB (compressed storage)
- **Files**: 5 files (per quarter)
- **Source**: SEC EDGAR (Q3 2024 financial statements)

### File Structure
Each quarter contains:
- **sub.txt** (565 KB): Company submission metadata (CIK, names, addresses, SIC codes)
- **num.txt** (120 MB): Numerical financial data (balance sheets, income statements)
- **tag.txt** (3.8 MB): XBRL taxonomy tags and definitions
- **pre.txt** (16 MB): Presentation linkbase information
- **readme.htm** (25 KB): Documentation

### Content Description
Corporate financial filings (10-K, 10-Q reports) containing:
- Company identification (CIK, EIN, state of incorporation)
- Balance sheet data
- Income statements
- Cash flow statements
- XBRL-tagged financial metrics

### Sample Companies (Q3 2024)
- Advanced Micro Devices (AMD)
- Air Products & Chemicals
- Adams Resources & Energy
- Alexanders Inc.

### Data Format
Tab-delimited text files with:
- Headers row
- Multiple data columns
- XBRL tag references
- Date ranges and fiscal periods

### Use Cases
- Financial data analysis
- ETL pipeline testing (large CSV processing)
- XBRL data parsing
- Accounting system integration
- Data warehouse loading
- Business intelligence dashboards

---

## 5. Regulatory Documents - Federal Register
**Path**: `/storage/nexus/5_Regulatory_Docs_FederalRegister/`

### Statistics
- **Size**: 95 MB
- **Files**: 200 PDF files
- **Source**: Federal Register API (current 2025 documents)

### Document Specifications
- **Format**: PDF 1.7
- **Page Count**: 3-4 pages typical
- **Document IDs**: Sequential (2025-20482, 2025-20492, etc.)
- **Date**: Current documents (December 2025)

### Content Description
Federal agency regulatory documents including:
- **Final Rules**: Completed regulations
- **Proposed Rules**: Draft regulations for public comment
- **Notices**: Agency announcements and public notices

**Excludes**: Presidential documents (per API filtering)

### Document Types
Real regulatory content from federal agencies covering:
- Administrative procedures
- Agency rules and standards
- Public policy changes
- Compliance requirements

### Use Cases
- PDF text extraction and parsing
- Regulatory compliance systems
- Document management systems
- Legal research tools
- Full-text search indexing
- Metadata extraction

---

## 6. Digital Corpora - Audio Files
**Path**: `/storage/nexus/DigitalCorpora/file_corpora/2009-audio/`

### Statistics
- **Size**: 105 MB
- **Files**: 50 files (audio tracks)
- **Source**: DigitalCorpora.org (forensic research)

### File Structure
Same audio content encoded at multiple bitrates:
- **MP3 Variants**: 128, 160, 192, 256, 320 kbps
- **WAV Format**: Uncompressed 16-bit stereo
- **Metadata Variants**: With/without album art (ID3 tags)

### Audio Specifications
- **Sample Rate**: 44.1 kHz (CD quality)
- **Channels**: Stereo
- **Encoding**: MPEG ADTS Layer III (MP3)
- **File Sizes**: 865 KB (128 kbps MP3) to 19 MB (WAV)

### Naming Convention
```
media1_01_128kbps_44100Hz_Stereo_art.mp3
media1_01_128kbps_44100Hz_Stereo_noart.mp3
media1_01_44100Hz_16bitStereo.wav
```

### Use Cases
- Audio codec testing and comparison
- Compression algorithm analysis
- Audio forensics training
- Metadata extraction (ID3 tags)
- Bitrate quality testing
- Audio processing pipeline validation
- Digital evidence handling

---

## 7. GovDocs1 - Duplicate Collection
**Path**: `/storage/nexus/GovDocs1/`

### Statistics
- **Size**: 481 MB
- **Files**: 981 files
- **Source**: GovDocs1 corpus (downloaded via `download_govdocs.py`)

### Note
This folder contains **duplicate data** from folder #1. Both `download_enterprise_sources.py` and `download_govdocs.py` downloaded the same GovDocs1 thread (000), resulting in identical content in two locations.

### Content
Identical to folder #1 - see "Office Documents - Government Files" above.

---

## Data Themes and Categories

### By Content Type
1. **Documents**: Folders 1, 5, 7 (Office docs, regulatory PDFs)
2. **Structured Data**: Folders 2, 4 (JSON contracts, CSV financials)
3. **Media Files**: Folders 3, 6 (Images, audio)

### By Source
1. **Government**: Folders 1, 2, 5, 7 (GovDocs, contracts, regulations)
2. **Corporate**: Folder 4 (SEC filings)
3. **Commercial**: Folder 3 (Amazon images)
4. **Forensic Research**: Folder 6 (Digital Corpora)

### By Use Case
1. **Document Processing**: Folders 1, 5, 7
2. **Financial Analysis**: Folders 2, 4
3. **Computer Vision**: Folder 3
4. **Digital Forensics**: Folders 6, 7
5. **Data Engineering**: All folders

---

## Data Quality Observations

### Authenticity
- ✅ All data from legitimate public sources
- ✅ Real-world production data (not synthetic)
- ✅ Current data (2024-2025 documents in some folders)

### Diversity
- ✅ 30+ file formats across all folders
- ✅ Legacy and modern formats
- ✅ Structured and unstructured data
- ✅ Text, images, audio, and tabular data

### Completeness
- ✅ Metadata included where applicable
- ✅ Documentation files present (SEC readme)
- ✅ Multiple encoding variants (audio)

### Issues
- ⚠️ Duplicate data in folders 1 and 7
- ℹ️ Some files may contain malware (intentional for forensics research)
- ℹ️ Legacy formats require older software/tools

---

## Recommendations

### Storage Optimization
- Consider removing duplicate GovDocs1 folder (481 MB savings)
- Enable filesystem compression (ZFS/BTRFS) for ~50% space savings
- Expected compression ratio: 1.8-2.0x

### Additional Downloads
For comprehensive testing:
- **GovDocs1**: Download larger tier (medium = 100K files, 54 GB)
- **Digital Corpora**: Add video files or forensic scenarios
- **SEC Data**: Download multiple quarters for time-series analysis
- **Federal Register**: Increase to 10,000 documents

### Use Case Development
Ideal for:
- NAS performance testing (high file count, mixed sizes)
- File format parser testing (30+ formats)
- ETL pipeline validation (large CSV files)
- Document management system testing
- Digital forensics training scenarios
- Computer vision model training

---

**Document Created**: December 14, 2025  
**Data Version**: Sample downloads (1.3 GB subset)  
**Location**: `/storage/nexus/use_cases/data_folders_overview.md`
