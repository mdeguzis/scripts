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

def analyze_capitalone_pdf(file_path, accumulated_data=None):
    parsed_data = accumulated_data or {}
    
    try:
        current_page = 0
        with pdfplumber.open(file_path) as pdf:
            logger.info("Extracting data from Capital One PDF...")
            for page_num, page in enumerate(pdf.pages):
                current_page += 1
                logger.info(f"Processing page {current_page}...")
                # Extract text to locate "Transactions" section
                page_text = page.extract_text()
                parsed_data = parse_capitalone_transactions_text(page_text, parsed_data, current_page)
        if parsed_data:
            return parsed_data
        else:
            logger.error("Failed to parse data! Data is empty!")
            exit(1)
    except Exception as e:
        raise Exception(e)

def parse_capitalone_transactions_text(pdf_text, data, page_num):
    """
    Parse the PDF text to extract and organize transaction data.
    """
    lines = pdf_text.splitlines()
    current_name = None
    current_account = None
    transaction_ct = 0

    name_pattern = re.compile(r"^([A-Z\s]+) #(\d+): Transactions$")
    user_transactions_done = re.compile(r"^([A-Z\s]+) #(\d+): Total Transactions")
    transaction_pattern = re.compile(r"(\w{3} \d{1,2}) (\w{3} \d{1,2}) ([\w\s\*]+.*?[a-zA-Z]) (\$\d+\.\d{1,2})")
    header = "Trans Date Post Date Description Amount"
    processing_transactions = False

    for line in lines:
        match = name_pattern.match(line)
        # Get current person we are handling
        if match and not processing_transactions:
            current_name = match.group(1)  # Name part up to '#1234'
            current_account = match.group(2)  # The account number
            logger.info(f"Processing transaction for '{current_name}' (Account #{current_account})")

            # Initialize if we don't have data yet
            if current_name not in data:
                data[current_name] = {}
                data[current_name]["account"] = current_account

            if not data.get(current_name, "").get("transactions_count", ""):
                data[current_name]["transactions_count"] = []

            if not data.get(current_name, "").get("transactions", ""):
                data[current_name]["transactions"] = []

            processing_transactions = False
            continue

        if line == header and current_name and not processing_transactions:
            logger.info(f"Got transactions on page {page_num}")
            # Initialize transactions data
            if not data.get(current_name, "").get("transactions", ""):
                data[current_name]["transactions"] = []
            # Set flow
            processing_transactions = True
            continue

        # If we hit "<NAME> #<ACCOUNT>: Total Transactions", we are done for the current user
        done_match = user_transactions_done.match(line)
        if done_match:
            this_user = (done_match.group(1))
            logger.info(f"Done processing transactions for '{this_user}'")
            processing_transactions = False

        # Process transactions list
        # "Trans Date Post Date Description Amount"
        if current_name:
            try:
                data_match = transaction_pattern.match(line)
                transactions_data_raw = line
                logger.debug(f"Transaction data (raw): '{transactions_data_raw}'")
                if data_match:
                    processing_transactions = True
                    transaction_ct += 1
                    data[current_name]["transactions_count"] = transaction_ct
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
    parser = argparse.ArgumentParser(description="Analyze financial statements.")
    parser.add_argument("--capital-one", "-c", required=True, help="Path to the Capital One statement (CSV or PDF).")
    parser.add_argument("--debug", "-d", action='store_true', help="Enable debug output")
    parser.add_argument("--print", "-p", action='store_true', help="Print all data to screen")
    return parser.parse_args()

def main(args, report_filename):
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
    if args.print:
        logger.info(json.dumps(transaction_data, indent=4))

    # Write report
    with open(report_filename, "w") as outfile:
        json.dump(transaction_data, outfile, indent=4)

if __name__ == "__main__":
    args = process_args()
    report_filename = "/tmp/monthly-budget-report.json"
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

    # File handler
    log_filename = "/tmp/monthly-budget.log"
    file_handler = logging.FileHandler(log_filename, mode='w')
    file_handler.setFormatter(formatter)
    # Add file handler to logger
    logger.addHandler(file_handler)

    main(args, report_filename)


    print(f"Log: {log_filename}")
    print(f"Transactions report: {report_filename}")

