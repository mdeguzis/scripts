#!/usr/bin/env python3

import argparse
import gzip
import json
import logging
import os
import re
import shutil
import zipfile
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
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[logging.FileHandler(log_file), logging.StreamHandler()],
    )


def extract_paprika_file(paprika_file, extract_dir):
    """Extracts the main Paprika export zip file."""
    if not zipfile.is_zipfile(paprika_file):
        logging.error("%s is not a valid zip file.", paprika_file)
        return None

    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(paprika_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    logging.info("Extracted Paprika recipes to: %s", extract_dir)
    return extract_dir


def decompress_recipes(paprika_file, extract_dir):
    """Decompresses all `.paprikarecipe` (gzip) files in the directory."""

    logging.debug("Decompressing Paprika file %s", paprika_file)

    output_dir = os.path.join(extract_dir, "json")
    # Clear out files in extract dir/json if sync is set
    if args.sync:
        if os.path.exists(output_dir):
            shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # First, extract all files from the zip archive
    logging.info("Extracting recipes from %s", paprika_file)
    with zipfile.ZipFile(paprika_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    for file_name in os.listdir(extract_dir):
        if file_name.endswith(".paprikarecipe"):
            logging.debug("Decompressing recipe: %s", file_name)
            file_path = os.path.join(extract_dir, file_name)
            with gzip.open(file_path, "rt", encoding="utf-8") as gz_file:
                json_data = gz_file.read()

            # Create the json filename (lowercase, spaces to dashes)
            json_filename = (
                os.path.splitext(file_name)[0].lower().replace(" ", "-") + ".json"
            )
            # Create the full path in the json subdirectory
            json_file_path = os.path.join(extract_dir, "json", json_filename)
            with open(json_file_path, "w", encoding="utf-8") as json_file:
                json_file.write(json_data)

            # Rename the JSON file, lowercase, space to dash
            os.rename(json_file_path, json_file_path.lower().replace(" ", "-"))

            # Remove the original .paprikarecipe file
            os.remove(file_path)
            logging.debug("Decompressed: %s to %s", file_name, json_file_path)


def convert_json_to_markdown(json_file, output_dir):
    """Converts a single JSON recipe file to Markdown format."""

    with open(json_file, "r", encoding="utf-8") as f:
        recipe_data = json.load(f)

    title = recipe_data.get("name", "Untitled Recipe")
    title = title.lower().replace(" ", "-")

    # Handle ingredients that may not have sections
    ingredients = recipe_data.get("ingredients", "")
    ingredients = f"- {ingredients}"
    # First split on double newlines to get sections
    sections = ingredients.split("\n\n")
    formatted_lines = []
    for section in sections:
        # Split each section on single newlines
        lines = section.split("\n")
        if lines:
            formatted_lines.append(lines[0])

        for line in lines[1:]:
            # Check for different line types
            if line[0].isupper():
                # Lines starting with capital letters (likely headers)
                formatted_lines.append(f"\n{line}")
            elif line.startswith(("*", "-", "•")):
                # Lines that already have bullets/markers
                formatted_lines.append(line)
            elif line.strip().startswith("("):
                # Optional ingredients or notes in parentheses
                formatted_lines.append(line)
            else:
                # All other lines get a dash
                formatted_lines.append(f"- {line}")

    # Join sections back with double newlines
    ingredients = "\n".join(formatted_lines)

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
    markdown_content += '<div style="float: left;">\n\n'
    markdown_content += f"Rating: {'★' * int(rating)}<br>\n"
    markdown_content += f"Categories: {categories}<br>\n"
    markdown_content += f"Source: {source_url_formatted}<br>\n"
    markdown_content += f"Prep time: {prep_time}<br>\n"
    markdown_content += f"Cook time: {cook_time}<br>\n"
    if difficulty:
        markdown_content += f"Difficulty: {difficulty}<br>\n"
    if total_time:
        markdown_content += f"Total time: {total_time}<br>\n"
    markdown_content += f"Servings: {servings}\n"
    markdown_content += "</div>\n\n"

    # Clear the floats
    markdown_content += '<div style="clear: both;"></div>\n\n'

    # Main content
    markdown_content += f"# {title}\n\n"
    markdown_content += "## Ingredients\n\n"
    markdown_content += f"{ingredients}\n\n"
    markdown_content += "## Instructions\n"
    markdown_content += f"{instructions}\n\n"

    # Create table for nutritional info
    if nutritional_info:
        markdown_content += "## Nutritional Info\n"
        # Simple markdown table
        nutrition_table = []
        nutrition_table.append("| **[label]** | **[value]** | **[% daily value]** |\n")
        nutrition_table.append("|---|---|---|\n")
        pattern = r"(.*?)\s*(\d+[a-zA-Z]+)\s*(\d+%)"
        for n in nutritional_info.split("\n"):
            matches = re.match(pattern, n)
            if matches:
                label = matches.group(1).strip()
                amount = matches.group(2).strip()
                percent = matches.group(3).strip()
                nutrition_table.append(f"|{label}|{amount}|{percent}\n")
        nutrition_table = "".join(nutrition_table)
        markdown_content += f"{nutrition_table}\n\n"
    if notes:
        markdown_content += "## Notes\n"
        markdown_content += f"{notes}\n\n"

    # Source info
    markdown_content += "## Source\n\n"
    markdown_content += f"* Source: {source}\n"
    markdown_content += f"* Source URL: {source_url}\n\n"

    # Replace any lines with only "*" with ""
    # These are usually from ingredient parsing
    markdown_content = re.sub(r"^\*\s*$", "", markdown_content, flags=re.MULTILINE)

    # Make an output_dir sub_dir based on preset categories I set
    # This is first-come-first serve processing to place recipes until I
    # have a better solution
    sub_folder_name = None
    if len(recipe_data.get("categories", "")) == 1:
        sub_folder_name = categories.lower()
    else:
        if "soup" in categories.lower():
            sub_folder_name = "soup"
        elif "chicken" in categories.lower():
            sub_folder_name = "chicken"
        elif "bread" in categories.lower():
            sub_folder_name = "bread"
        elif "beef" in categories.lower():
            sub_folder_name = "beef"
        elif "pork" in categories.lower():
            sub_folder_name = "pork"
        elif "fish" in categories.lower():
            sub_folder_name = "fish"
        else:
            sub_folder_name = "uncategorized"

    if sub_folder_name:
        output_dir = os.path.join(output_dir, sub_folder_name)
        os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, f"{title}.md")

    # Check if file exists and skip if overwrite is False
    if os.path.exists(output_file) and not args.update:
        logging.warning(
            "Skipping existing file: %s. Use --update to force changes.", output_file
        )
        return

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(markdown_content)

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(markdown_content)

    logging.info("Converted to Markdown: %s", output_file)
    return output_file


def sync_markdown_files(extract_dir, processed_files):
    """
    Sync markdown files by removing duplicates and old recipes.
    Also removes corresponding JSON files that are no longer needed.

    Args:
        extract_dir (str): Base directory containing markdown files
        processed_files (set): Set of processed file paths

    Returns:
        int: Number of files removed during sync
    """
    logging.warning("Syncing: Removing duplicates and old recipes...")
    removed_count = 0
    json_dir = os.path.join(extract_dir, "json")

    # First find all markdown files
    all_markdown_files = {}
    for root, _, files in os.walk(extract_dir):
        if "json" in root:
            continue
        for file in files:
            if file.endswith(".md"):
                full_path = os.path.join(root, file)
                # Group by filename
                if file not in all_markdown_files:
                    all_markdown_files[file] = [full_path]
                else:
                    all_markdown_files[file].append(full_path)

    # Now check each file
    for filename, paths in all_markdown_files.items():
        # Get the correct path from processed_files if it exists
        correct_path = None
        for processed_path in processed_files:
            if os.path.basename(processed_path) == filename:
                correct_path = processed_path
                break

        if correct_path:
            # Remove any paths that don't match the correct one
            for path in paths:
                if path != correct_path:
                    logging.info(
                        "Removing duplicate recipe: %s (keeping %s)", path, correct_path
                    )
                    os.remove(path)

                    # Remove corresponding JSON file
                    json_filename = (
                        os.path.splitext(os.path.basename(path))[0] + ".json"
                    )
                    json_path = os.path.join(json_dir, json_filename)
                    if os.path.exists(json_path):
                        logging.info("Removing corresponding JSON file: %s", json_path)
                        os.remove(json_path)

                    removed_count += 1
        else:
            # File doesn't exist in source anymore, remove all instances
            for path in paths:
                logging.info(
                    "Removing old recipe that no longer exists in source: %s", path
                )
                os.remove(path)

                # Remove corresponding JSON file
                json_filename = os.path.splitext(os.path.basename(path))[0] + ".json"
                json_path = os.path.join(json_dir, json_filename)
                if os.path.exists(json_path):
                    logging.info("Removing corresponding JSON file: %s", json_path)
                    os.remove(json_path)

                removed_count += 1

    logging.info("Sync complete. Removed %d files.", removed_count)
    return removed_count


def process_paprika_to_markdown(paprika_file, extract_dir):
    """Main process to convert Paprika file to Markdown."""

    logging.info("Converting recipes to Markdown")
    decompress_recipes(paprika_file, extract_dir)

    json_output_dir = os.path.join(extract_dir, "json")
    logging.info("Converting recipes to Markdown in: %s", json_output_dir)
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
        sync_markdown_files(extract_dir, processed_files)

    # Write a success file with current date/time
    current_time = datetime.now().strftime("%Y-%m-%d:%H.%M.%S")
    success_file = os.path.join(extract_dir, "last-exported.txt")
    with open(success_file, "w", encoding="utf-8") as f:
        f.write(f"Export successful: {current_time}\n")

    logging.info("All recipes converted to Markdown in: %s", extract_dir)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Convert Paprika 3 recipes to Markdown."
    )
    parser.add_argument(
        "--debug", action="store_true", default=False, help="Enable debug logging"
    )
    parser.add_argument("-f", "--file", help="Path to the .paprikarecipes file.")
    parser.add_argument(
        "-i",
        "--input-dir",
        help="Input directory. This will export the latest file found.",
    )
    parser.add_argument("-o", "--output-dir", required=True, help="Output directory.")
    parser.add_argument(
        "-u",
        "--update",
        action="store_true",
        default=False,
        help="Overwrite/update existing markdown files",
    )
    parser.add_argument(
        "-s",
        "--sync",
        action="store_true",
        default=False,
        help="Remove recipes in output directory that don't exist in source",
    )
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
        regex = re.compile(
            r"Export \d{4}-\d{2}-\d{2}.*All Recipes\.paprikarecipes(\.zip)?$"
        )
        latest_file = None
        for file_name in os.listdir(args.input_dir):
            if regex.match(file_name):
                file_path = os.path.join(args.input_dir, file_name)
                if not latest_file or os.path.getmtime(file_path) > os.path.getmtime(
                    latest_file
                ):
                    latest_file = file_path

        if not latest_file:
            logging.error(
                "No matching files found in the directory. Export <DATE>All Recipes.paprikarecipes.zip"
            )
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
