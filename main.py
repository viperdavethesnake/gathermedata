#!/usr/bin/env python3
"""
GatherMeData - Main script for downloading data
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv


def main():
    """Main entry point for the data download script"""
    
    # Load environment variables
    load_dotenv()
    
    print("GatherMeData - Data Download Script")
    print("=" * 40)
    
    # Create data directory if it doesn't exist
    data_dir = Path("data")
    data_dir.mkdir(exist_ok=True)
    
    # TODO: Add your data download logic here
    print("\nReady to download data...")
    print(f"Data will be saved to: {data_dir.absolute()}")


if __name__ == "__main__":
    main()
