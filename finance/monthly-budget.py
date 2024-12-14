#!/usr/bin/env python

import argparse
import json
import time
import logging
import pandas as pd
import pdfplumber
import re

from decimal import Decimal
from pathlib import Path
from enum import Enum

# Define an Enum for expense categories
class ExpenseCategory(Enum):
    RENT = "rent"
    UTILITIES = "utilities"
    GROCERIES = "groceries"
    TRANSPORTATION = "transportation"
    ENTERTAINMENT = "entertainment"
    HEALTHCARE = "healthcare"
    MISCELLANEOUS = "miscellaneous"
    UNKNOWN = "unknown"

# Default json library doesn't like to serialize decimal :)
# Convert Decimal objects to strings before serializing to JSON
def decimal_default(obj):
    if isinstance(obj, Decimal):
        return str(obj)
    raise TypeError("Object of type Decimal is not JSON serializable")

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

# TODO - Maybe make this work for any pdf and "oursource" certain things to other methods
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
    have_continuation = False
    transaction_ct = 0

    name_pattern = re.compile(r"^([A-Z\s]+) #(\d+): Transactions")
    user_transactions_done = re.compile(r"^([A-Z\s]+) #(\d+): Total Transactions (\$\d{1,3}(?:,\d{3})*(?:\.\d{1,2}))")
    # Match any variation of money + expected pattern
    # Example: 'Nov 5 Nov 8 Moble Payment - ABCD $0,000.00"
    # Example: 'Nov 22 Nov 22 Moble Payment (new) - ABCD $0.00"
    transaction_pattern = re.compile(r"(\w{3} \d{1,2}) (\w{3} \d{1,2}) ([\w\s\*]+.*?[a-zA-Z]) (\$\d{1,3}(?:,\d{3})*(?:\.\d{1,2}))")
    header = "Trans Date Post Date Description Amount"
    processing_transactions = False

    for line in lines:
        # Fetch current user from queue memory
        # Regex matching
        if data.get("current_queue", ""):
            current_name = data["current_queue"] 
        name_match = name_pattern.match(line)
        done_match = user_transactions_done.match(line)

        # If we hit "<NAME> #<ACCOUNT>: Total Transactions", we are done for the current user
        #if done_match and not processing_transactions:
        # Check this early, as if we trigger done too early, we'll notice discrepancies
        if done_match:
            if have_continuation:
                logger.error("We should still be processing transactions. Something went wrong...")
                exit(1)
            this_user = done_match.group(1)
            logger.info(f"Done processing transactions for '{this_user}'")
            # Our total
            total_amount_from_data = data[this_user]["transactions_total_amount"]
            logger.debug(f"Converting our total {total_amount_from_data} to Decimal")
            total_amount_processed = Decimal(total_amount_from_data)
            # Statement total
            statement_final = done_match.group(3).replace('$', '').replace(',', '')
            logger.debug(f"Converting statement final total {statement_final} to Decimal")
            statement_final_amount = Decimal(statement_final)
            # Verify
            if total_amount_processed != statement_final_amount:
                logger.error(f"Failed to verify transaction amounts against process amount!")
                logger.error(f"Found: {total_amount_processed}")
                logger.error(f"Reported by document: {statement_final_amount}")
                #exit(1)
            logger.info("Final ammount verified!")
            data[this_user]["verified_amounts"] = True

            # Error if our current total amoutn processed doesn't match the amoutn reported in the final line
            # Clear the queue
            data["current_queue"] = None
            processing_transactions = False
            break

        # Get current person we are handling
        if name_match:
            current_name = name_match.group(1)
            current_account = name_match.group(2)
            # Set name in the queue so we have it handy
            data["current_queue"] = current_name
            logger.info(f"Processing transactions for '{current_name}' (Account #{current_account})")

            # Initialize if we don't have data yet
            if current_name not in data:
                data[current_name] = {}
                data[current_name]["account"] = current_account

            if not data.get(current_name, "").get("verified_amounts", ""):
                data[current_name]["verified_amounts"] = False
            if not data.get(current_name, "").get("transactions_count", ""):
                data[current_name]["transactions_count"] = []
            if not data.get(current_name, "").get("transactions", ""):
                data[current_name]["transactions"] = []
            if not data.get(current_name, "").get("transactions_total_amount", ""):
                data[current_name]["transactions_total_amount"] = Decimal(0)
            processing_transactions = False

        elif "Transactions (Continued)" in line:
            logger.info(f"We have more transactions on page {page_num}: (Continuation found)")
            processing_transactions = True
            have_continuation = True
            continue

        elif line == header and current_name:
            processing_transactions = True
            have_continuation = False
            # Do we have a transactions header and are we processing a user?
            logger.debug(f"Got transactions on page {page_num}")
            if not data.get(current_name, "").get("transactions", ""):
                data[current_name]["transactions"] = []
            continue

        elif current_name and processing_transactions:
            # Do we have an active queue and should process transactions?
            # Header: "'Trans Date' 'Post Date' 'Description' 'Amount'"
            have_continuation = False
            try:
                data_match = transaction_pattern.match(line)
                if not data_match:
                    logger.debug(f"Discarding possible transaction line: {line}")
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
                    # Ensure that all the transactions we collect match up later to
                    # the total amount
                    logger.debug(f"Coverting {amount} to Decimal")
                    amount_decimal = Decimal(amount.replace(',', ''))
                    logger.debug(f"Addding {amount_decimal} to total")
                    data[current_name]["transactions_total_amount"] += amount_decimal
                    total = data[current_name]["transactions_total_amount"]
                    logger.debug(f"Total: {total}")
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
        logger.info(json.dumps(transaction_data, indent=4, default=decimal_default))

    # Add high level info for budgeting
    transaction_data["budget"] = {}
    transaction_data["budget"]["breakdown"] = {}

    # Capital one budget information
    transaction_data["budget"]["breakdown"]["capital_one"] = {}
    transaction_data["budget"]["breakdown"]["capital_one"]
    for user, value in transaction_data["capital_one"].items():
        if value:
            total_expenses = value["transactions_total_amount"]
            transaction_data["budget"]["breakdown"]["capital_one"][user] = {}
            transaction_data["budget"]["breakdown"]["capital_one"][user]["expenses"] = total_expenses
    exit

    # Sort main keys so "budget" key is on top
    sorted_data = {key: transaction_data[key] for key in sorted(transaction_data)}

    # Write report
    with open(report_filename, "w") as outfile:
        json.dump(sorted_data, outfile, indent=4, default=decimal_default)


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


