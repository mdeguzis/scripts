#!/usr/bin/env python

import argparse
import json
import time
import logging
import pandas as pd
import pdfplumber
import re

from pathlib import Path

def analyze_capitalone_csv(file_path):
    try:
        # Load and analyze the CSV file
        data = pd.read_csv(file_path)
        print("\nCapital One CSV Headers:")
        print(data.columns.tolist())
        print("\nFirst Row of Data:")
        print(data.iloc[0].to_dict())  # Display the first row for analysis
    except Exception as e:
        print(f"Error reading the CSV file: {e}")

def analyze_capitalone_pdf(file_path):
    extracted_data = []
    try:
        with pdfplumber.open(file_path) as pdf:
            logger.info("Extracting data from Capital One PDF...")
            for i, page in enumerate(pdf.pages):
                logger.info(f"Processing page {i + 1}...")
                # Extract text to locate "Transactions" section
                page_text = page.extract_text()
                parsed_data = parse_capitalone_transactions_text(page_text)
                if parsed_data:
                    extracted_data.append(parsed_data)

        return extracted_data
    except Exception as e:
        print(f"Error reading the PDF file: {e}")

def parse_capitalone_transactions_text(pdf_text):
    """
    Parse the PDF text to extract and organize transaction data.
    """
    lines = pdf_text.splitlines()
    data = {}
    current_name = None
    current_account = None
    collecting_transactions = False

    name_pattern = re.compile(r"^([A-Z\s]+) #(\d+): Transactions$")
    # Match 
    transaction_pattern = re.compile(r"(\w{3} \d{2}) (\w{3} \d{2}) ([\w\s\*]+.*?[a-zA-Z]) (\$\d+\.\d{1,2})")
    header = "Trans Date Post Date Description Amount"
    current_name = None
    processing_transactions = False

    for line in lines:
        #logger.debug(f"State: processing_transactions({processing_transactions})")
        match = name_pattern.match(line)
        # Get current person we are handling
        if match and not processing_transactions:
            current_name = match.group(1)  # Name part up to '#1234'
            current_account = match.group(2)  # The account number
            data[current_name] = {}
            data[current_name]["account"] = current_account
            data[current_name]["transactions"] = []
            # Set flow
            processing_transactions = False
            continue
            
        if line == header and current_name and not processing_transactions:
            logger.debug("Got transactions")
            data[current_name]["transactions"] = []
            # Set flow
            processing_transactions = True
            continue

        # Process transactions list?
        # "Trans Date Post Date Description Amount"
        if processing_transactions:
            try:
                data_match = transaction_pattern.match(line)
                transactions_data_raw = line
                #logger.debug(f"Transaction data (raw): '{transactions_data_raw}'")
                if data_match:
                    logger.debug(data_match.groups())
                    transaction_date = data_match.group(1)
                    post_date = data_match.group(2)
                    description = data_match.group(3)
                    amount = data_match.group(4).replace('$', '')
                    data[current_name]["transactions"].append(
                        {
                            "transaction_date": transaction_date,
                            "post_date": post_date,
                            "description": description,
                            "amount": amount
                        }
                    )
            except Exception as e:
                raise Exception(e)

    return data

def process_args():
    parser = argparse.ArgumentParser(description="Analyze Capital One financial statements.")
    parser.add_argument("--capital-one", "-c", required=True, help="Path to the Capital One statement (CSV or PDF).")
    parser.add_argument("--debug", "-d", action='store_true', help="Enable debug output")
    return parser.parse_args()

def main(args):
    # Check the file extension
    transaction_data = {}
    data = None
    if args.capital_one:
        file_path = Path(args.capital_one).resolve()
        logger.info(f"Analyzing file: {file_path}")
        if file_path.suffix.lower() == ".csv":
            logger.info("Detected file type: CSV")
            data = analyze_capitalone_csv(file_path)
        elif file_path.suffix.lower() == ".pdf":
            logger.info("Detected file type: PDF")
            data = analyze_capitalone_pdf(file_path)
        else:
            logger.error("Unsupported file type. Please provide a CSV or PDF file.")
        transaction_data["capital_one"] = data

    # Print data
    logger.info(json.dumps(transaction_data, indent=4))

if __name__ == "__main__":
    args = process_args()
    logger = logging.getLogger('monthly-budget')
    if args.debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)

    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    # Add console handler to logger
    logger.addHandler(console_handler)

    main(args)

