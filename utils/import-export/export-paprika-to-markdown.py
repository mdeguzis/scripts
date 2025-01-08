#!/usr/bin/env python3

import argparse
import gzip
import json
import logging
import os
import shutil
import zipfile
import re

from datetime import datetime

home_dir = os.path.expanduser("~")
log_file = f"{home_dir}/paprika-export.log"

def setup_logger(debug=False):
    """
    Configure logging with optional debug level.
    # Log file should store to user home dir, as /tmp is not always accessible on all devices
    """
    level = logging.DEBUG if debug else logging.INFO
    
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )



def extract_paprika_file(paprika_file, extract_dir):
    """Extracts the main Paprika export zip file."""
    if not zipfile.is_zipfile(paprika_file):
        logging.error(f"{paprika_file} is not a valid zip file.")
        return None

    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(paprika_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    logging.info(f"Extracted Paprika recipes to: {extract_dir}")
    return extract_dir


def decompress_recipes(paprika_file, extract_dir):
    """Decompresses all `.paprikarecipe` (gzip) files in the directory."""

    logging.debug(f"Decompressing Paprika file {paprika_file}")

    output_dir = os.path.join(extract_dir, "json")
    os.makedirs(output_dir, exist_ok=True)

    # First, extract all files from the zip archive
    logging.info(f"Extracting recipes from {paprika_file}")
    with zipfile.ZipFile(paprika_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    for file_name in os.listdir(extract_dir):
        if file_name.endswith(".paprikarecipe"):
            logging.debug(f"Decompressing recipe: {file_name}")
            file_path = os.path.join(extract_dir, file_name)
            with gzip.open(file_path, "rt", encoding="utf-8") as gz_file:
                json_data = gz_file.read()

             # Create the json filename (lowercase, spaces to dashes)
            json_filename = os.path.splitext(file_name)[0].lower().replace(" ", "-") + ".json"
            # Create the full path in the json subdirectory
            json_file_path = os.path.join(extract_dir, "json", json_filename)
            with open(json_file_path, "w", encoding="utf-8") as json_file:
                json_file.write(json_data)

            # Rename the JSON file, lowercase, space to dash
            os.rename(json_file_path, json_file_path.lower().replace(" ", "-"))

            # Remove the original .paprikarecipe file
            os.remove(file_path)
            logging.debug(f"Decompressed: {file_name} to {json_file_path}")

    # Remove all .paprikareDecompressing Paprika filcipe files from the extract dir
    for file_name in os.listdir(extract_dir):
        if file_name.endswith(".paprikarecipe"):
            os.remove(os.path.join(extract_dir, file_name))


def convert_json_to_markdown(json_file, output_dir):
    """Converts a single JSON recipe file to Markdown format."""

    with open(json_file, "r", encoding="utf-8") as f:
        recipe_data = json.load(f)

    title = recipe_data.get("name", "Untitled Recipe")
    title = title.lower().replace(" ", "-")

    # Split ingredients to list
    ingredients = recipe_data.get("ingredients", "")
    ingredients = "- " + ingredients
    ingredients = ingredients.replace("\n", "\n- ")

    # Number instructions
    instructions = recipe_data.get("directions", "")
    instructions = "1. " + instructions
    instructions = instructions.replace("\n\n", "\n1. ")
    notes = recipe_data.get("notes", "")

    # Other data
    nutritional_info = recipe_data.get("nutritional_info", "")
    prep_time = recipe_data.get("prep_time", "")
    cook_time = recipe_data.get("cook_time", "")
    total_time = recipe_data.get("total_time", "")
    difficulty = recipe_data.get("difficulty", "")
    categories = ", ".join(recipe_data.get("categories", ""))
    servings = recipe_data.get("servings", "")
    rating = recipe_data.get("rating", "")
    source = recipe_data.get("source", "")
    source_url = recipe_data.get("source_url", "")

    # Photo data
    # Assuming photo_data contains the base64 string
    source_url_formatted = f'<a href="{source_url}">{source}</a>'
    markdown_content = ""
    if photo_data := recipe_data.get("photo_data", ""):
        image_data = f"data:image/jpeg;base64,{photo_data}"
        markdown_content += '<div style="float: left; margin-right: 20px;">\n\n'
        markdown_content += f"![Recipe Photo]({image_data})\n"
        markdown_content += "</div>\n\n"

    # Top summary info
    markdown_content += '<div style="float: right;">\n'
    markdown_content += f"Rating: {'★' * int(rating)}<br>\n"
    markdown_content += f"Categories: {categories}<br>\n"
    markdown_content += f"Source: {source_url_formatted}<br>\n"
    markdown_content += f"Prep time: {prep_time}<br>\n"
    markdown_content += f"Cook time: {cook_time}<br>\n"
    markdown_content += f"Total time: {total_time}<br>\n"
    markdown_content += f"Servings: {servings}\n"
    markdown_content += "</div>\n\n"

    # Clear the floats
    markdown_content += '<div style="clear: both;"></div>\n\n'

    # Main content
    markdown_content += f"# {title}\n\n"
    markdown_content += "## Ingredients\n"
    markdown_content += f"{ingredients}\n\n"
    markdown_content += "## Instructions\n"
    markdown_content += f"{instructions}\n\n"
    if notes:
        markdown_content += "## Notes\n"
        markdown_content += f"{notes}\n\n"

    # Source info
    markdown_content += "## Source\n\n"
    markdown_content += f"* Source: {source}\n"
    markdown_content += f"* Source URL: {source_url}\n\n"

    # Make an output_dir sub_dir based on preset catetories I set
    # This is first-come-first server to place recipes until I
    # have a better solution
    sub_folder_name = None
    if "soup" in categories.lower():
        sub_folder_name = "soup"
    elif "chicken" in categories.lower():
        sub_folder_name = "chicken"
    elif "beef" in categories.lower():
        sub_folder_name = "beef"
    elif "pork" in categories.lower():
        sub_folder_name = "pork"
    elif "fish" in categories.lower():
        sub_folder_name = "fish"

    if sub_folder_name:
        output_dir = os.path.join(output_dir, sub_folder_name)
        os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, f"{title}.md")

    # Check if file exists and skip if overwrite is False
    if os.path.exists(output_file) and not args.update:
        logging.warning(f"Skipping existing file: {output_file}. Use --update to force changes.")
        return
        
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(markdown_content)

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(markdown_content)

    logging.info(f"Converted to Markdown: {output_file}")
    return output_file


def process_paprika_to_markdown(paprika_file, extract_dir):
    """Main process to convert Paprika file to Markdown."""

    logging.info("Converting recipes to Markdown")
    decompress_recipes(paprika_file, extract_dir)

    json_output_dir = os.path.join(extract_dir, "json")
    logging.info(f"Converting recipes to Markdown in: {json_output_dir}")
    processed = False

    # Keep track of processed files for sync
    processed_files = set()
    for file_name in os.listdir(json_output_dir):
        if file_name.endswith(".json"):
            json_file = os.path.join(json_output_dir, file_name)
            output_file = convert_json_to_markdown(json_file, extract_dir)
            if output_file:
                processed_files.add(output_file)
            processed = True 

    if not processed:
        logging.error("No recipes found to convert.")
        return

    if args.sync:
        logging.warning("Syncing: Removing old recipes not found in source data...")
        for root, _, files in os.walk(extract_dir):
            if "json" in root:
                continue
            for file in files:
                if file.endswith(".md"):
                    full_path = os.path.join(root, file)
                    if full_path not in processed_files:
                        logging.info(f"Removing old recipe that do not exist in source: {full_path}")
                        os.remove(full_path)

    # Write a success file with current date/time
    current_time = datetime.now().strftime('%Y-%m-%d:%H.%M.%S')
    success_file = os.path.join(
        extract_dir,
        f"last-exported.txt"
    )
    with open(success_file, "w", encoding="utf-8") as f:
        f.write(f"Export successful: {current_time}\n")

    logging.info(f"All recipes converted to Markdown in: {extract_dir}")


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Convert Paprika 3 recipes to Markdown."
    )
    parser.add_argument("--debug", action="store_true", default=False,
                       help="Enable debug logging")
    parser.add_argument(
        "-f", "--file", help="Path to the .paprikarecipes file."
    )
    parser.add_argument("-i", "--input-dir",
                        help="Input directory. This will export the latest file found.")
    parser.add_argument("-o", "--output-dir", required=True, help="Output directory.")
    parser.add_argument("-u", "--update", action="store_true", default=False,
                   help="Overwrite/update existing markdown files")
    parser.add_argument("-s", "--sync", action="store_true", default=False,
                   help="Remove recipes in output directory that don't exist in source")
    args = parser.parse_args()

    # logging
    setup_logger(args.debug)

    if not args.file and not args.input_dir:
        logging.info("Please provide either a file or an input directory.")
        exit(1)
    os.makedirs(args.output_dir, exist_ok=True)

    if args.input_dir:
        # Find the latest file in the directory that matches the regex:
        # Export YYYY-MM-DD.*All Recipes.paprikarecipes.zip
        # Make .zip optional, as on *Nix systems, this is not present
        regex = re.compile(r"Export \d{4}-\d{2}-\d{2}.*All Recipes\.paprikarecipes(\.zip)?$")
        latest_file = None
        for file_name in os.listdir(args.input_dir):
            if regex.match(file_name):
                file_path = os.path.join(args.input_dir, file_name)
                if not latest_file or os.path.getmtime(file_path) > os.path.getmtime(latest_file):
                    latest_file = file_path

        if not latest_file:
            logging.error("No matching files found in the directory. Export <DATE>All Recipes.paprikarecipes.zip")
            exit(1)
        logging.info(f"Found latest file: {latest_file}")
        args.file = latest_file

    if not os.path.exists(args.file):
        logging.info(f"Error: File {args.file} does not exist.")
    else:
        process_paprika_to_markdown(args.file, args.output_dir)

    # Copy log to output dir
    shutil.copy(log_file, args.output_dir)
    logging.info(f"Done. Log: {log_file}")
