#!/usr/bin/env python3

import argparse
import base64
import json
import logging
import os
import re
import shutil
import zipfile
from datetime import datetime
from io import BytesIO

from bs4 import BeautifulSoup
from PIL import Image

home_dir = os.path.expanduser("~")
log_file = f"{home_dir}/recipe-keeper-export.log"


def resize_until_threshold(image_path, max_size=400, output_format="JPEG"):
    """
    Resizes an image repeatedly until both dimensions are under the specified max size.
    Then converts it to a Base64 string.

    :param image_path: Path to the input image
    :param max_size: Maximum width or height allowed
    :param output_format: Output format for the image (default is JPEG)
    :return: Base64 encoded string of the resized image
    """
    # Open the image
    with Image.open(image_path) as img:
        # Ensure the image is in RGB mode for formats like JPEG
        if img.mode != "RGB":
            img = img.convert("RGB")

        # Resize repeatedly until both dimensions are under max_size
        while img.width > max_size or img.height > max_size:
            img = img.resize(
                (img.width // 2, img.height // 2),
                Image.Resampling.LANCZOS,  # Updated from ANTIALIAS
            )

        # Save the resized image to a buffer
        buffer = BytesIO()
        img.save(buffer, format=output_format, quality=85)  # Adjust quality as needed
        buffer.seek(0)

        # Encode the image to Base64
        base64_string = base64.b64encode(buffer.read()).decode("utf-8")

        return base64_string


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


def extract_recipe_keeper_file(recipe_keeper_file, extract_dir):
    """Extracts the main recipekeeper export zip file."""
    if not zipfile.is_zipfile(recipe_keeper_file):
        logging.error("%s is not a valid zip file.", recipe_keeper_file)
        return None

    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(recipe_keeper_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    logging.info("Extracted recipekeeper recipes to: %s", extract_dir)
    return extract_dir


def decompress_recipes(recipe_keeper_file, extract_dir):
    """Extracts recipes from HTML and images from the zip file."""

    logging.debug("Extracting from recipekeeper file %s", recipe_keeper_file)

    output_dir = os.path.join(extract_dir, "json")
    # Clear out files in extract dir/json if sync is set
    if args.sync:
        if os.path.exists(output_dir):
            shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # Extract all files from the zip archive
    logging.info("Extracting recipes from %s", recipe_keeper_file)
    with zipfile.ZipFile(recipe_keeper_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    # Parse the HTML file
    html_file = os.path.join(extract_dir, "recipes.html")
    if not os.path.exists(html_file):
        logging.error("recipes.html not found in zip file")
        return

    with open(html_file, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    # Find all recipe divs
    recipe_divs = soup.find_all("div", class_="recipe-details")
    processed_files = set()

    for recipe_div in recipe_divs:
        try:
            recipe_data = {}

            # Extract recipe ID
            recipe_id = recipe_div.find("meta", attrs={"itemprop": "recipeId"})[
                "content"
            ]
            recipe_data["id"] = recipe_id

            # Extract name
            name = recipe_div.find("h2", attrs={"itemprop": "name"}).text.strip()
            recipe_data["name"] = name

            # Extract course
            course_span = recipe_div.find("span", attrs={"itemprop": "recipeCourse"})
            recipe_data["course"] = course_span.text.strip() if course_span else ""

            # Extract category
            category_meta = recipe_div.find(
                "meta", attrs={"itemprop": "recipeCategory"}
            )
            recipe_data["category"] = category_meta["content"] if category_meta else ""

            # Extract source
            source_span = recipe_div.find("span", attrs={"itemprop": "recipeSource"})
            if source_span:
                source_link = source_span.find("a")
                if source_link:
                    recipe_data["source"] = source_link["href"]
                else:
                    recipe_data["source"] = source_span.text.strip()

            # Extract serving size
            serving_span = recipe_div.find("span", attrs={"itemprop": "recipeYield"})
            recipe_data["servings"] = serving_span.text.strip() if serving_span else ""

            # Extract times
            prep_time = recipe_div.find("meta", attrs={"itemprop": "prepTime"})
            if prep_time:
                prep_span = prep_time.parent.find("span")
                recipe_data["prep_time"] = prep_span.text.strip() if prep_span else ""

            cook_time = recipe_div.find("meta", attrs={"itemprop": "cookTime"})
            if cook_time:
                cook_span = cook_time.parent.find("span")
                recipe_data["cook_time"] = cook_span.text.strip() if cook_span else ""

            # Extract ingredients
            ingredients_div = recipe_div.find("div", class_="recipe-ingredients")
            if ingredients_div:
                ingredients = [
                    p.text.strip()
                    for p in ingredients_div.find_all("p")
                    if p.text.strip()
                ]
                recipe_data["ingredients"] = ingredients

            # Extract directions
            directions_div = recipe_div.find(
                "div", attrs={"itemprop": "recipeDirections"}
            )
            if directions_div:
                directions = [
                    p.text.strip()
                    for p in directions_div.find_all("p")
                    if p.text.strip()
                ]
                recipe_data["directions"] = directions

            # Extract notes
            notes_div = recipe_div.find("div", class_="recipe-notes")
            recipe_data["notes"] = notes_div.text.strip() if notes_div else ""

            # Handle image
            img = recipe_div.find("img", class_="recipe-photo")
            if img and "src" in img.attrs:
                img_src = img["src"]
                if img_src.startswith("images/"):
                    # Read the image file and convert to base64
                    img_path = os.path.join(extract_dir, img_src)
                    if os.path.exists(img_path):
                        with open(img_path, "rb") as img_file:
                            # img_data = base64.b64encode(img_file.read()).decode("utf-8")
                            img_data = resize_until_threshold(img_file, max_size=600)
                            recipe_data["photo_data"] = img_data

            # Create sanitized filename
            filename = re.sub(r"[^\w\s-]", "", name.lower())
            filename = re.sub(r"[-\s]+", "-", filename)
            json_filename = f"{filename}.json"
            json_path = os.path.join(output_dir, json_filename)

            with open(json_path, "w", encoding="utf-8") as json_file:
                json.dump(recipe_data, json_file, indent=2)

            processed_files.add(json_path)
            logging.debug("Created JSON file: %s", json_path)

        except Exception as e:
            logging.error("Error processing recipe: %s", str(e))
            continue

    # Clean up the extracted files
    os.remove(html_file)
    shutil.rmtree(os.path.join(extract_dir, "images"), ignore_errors=True)

    logging.info("Finished processing recipes")
    return processed_files


def convert_json_to_markdown(json_file, output_dir):
    """Converts a single JSON recipe file to Markdown format."""

    with open(json_file, "r", encoding="utf-8") as f:
        recipe_data = json.load(f)

    title = recipe_data.get("name", "Untitled Recipe")

    # Handle ingredients list
    ingredients = recipe_data.get("ingredients", [])
    if isinstance(ingredients, list):
        formatted_ingredients = []
        current_section = None

        for ingredient in ingredients:
            if ingredient:
                # Check if this is a section header (all caps or ends with :)
                if ingredient.isupper() or ingredient.endswith(":"):
                    current_section = ingredient
                    formatted_ingredients.append(f"\n### {ingredient}\n")
                else:
                    # Regular ingredient - add bullet point
                    formatted_ingredients.append(f"- {ingredient}")

        ingredients = "\n".join(formatted_ingredients)
    else:
        ingredients = "- " + ingredients if ingredients else ""

    # Handle directions/instructions list
    instructions = recipe_data.get("directions", [])
    if isinstance(instructions, list):
        formatted_instructions = []
        for i, instruction in enumerate(instructions, 1):
            if instruction:
                formatted_instructions.append(instruction)
        instructions = "\n".join(formatted_instructions)
    else:
        instructions = instructions if instructions else ""

    # Get notes
    notes = recipe_data.get("notes", "")
    if notes:
        notes = f"\n## Notes\n{notes}\n"

    # Get course and category
    course = recipe_data.get("course", "")
    category = recipe_data.get("category", "")
    categories = []
    if course:
        categories.append(course)
    if category:
        categories.append(category)
    categories = ", ".join(categories)

    # Times
    prep_time = recipe_data.get("prep_time", "")
    cook_time = recipe_data.get("cook_time", "")

    # Source information
    source = recipe_data.get("source", "")
    source_formatted = ""
    if source:
        if source.startswith("http"):
            source_formatted = f'<a href="{source}">{source}</a>'
        else:
            source_formatted = source

    # Servings
    servings = recipe_data.get("servings", "")

    # Photo data
    markdown_content = ""
    if photo_data := recipe_data.get("photo_data", ""):
        image_data = f"data:image/jpeg;base64,{photo_data}"
        markdown_content += '<div style="float: left; margin-right: 20px;">\n\n'
        markdown_content += f"![Recipe Photo]({image_data})\n"
        markdown_content += "</div>\n\n"

    # Top summary info
    markdown_content += '<div style="float: left;">\n\n'
    if categories:
        markdown_content += f"Categories: {categories}<br>\n"
    if source_formatted:
        markdown_content += f"Source: {source_formatted}<br>\n"
    if prep_time:
        markdown_content += f"Prep time: {prep_time}<br>\n"
    if cook_time:
        markdown_content += f"Cook time: {cook_time}<br>\n"
    if servings:
        markdown_content += f"Servings: {servings}\n"
    markdown_content += "</div>\n\n"

    # Clear the floats
    markdown_content += '<div style="clear: both;"></div>\n\n'

    # Main content
    markdown_content += f"# {title}\n\n"

    if ingredients:
        markdown_content += "## Ingredients\n\n"
        markdown_content += f"{ingredients}\n\n"

    if instructions:
        markdown_content += "## Instructions\n\n"
        markdown_content += f"{instructions}\n\n"

    if notes:
        markdown_content += notes

    # Create the output filename
    output_filename = re.sub(r"[^\w\s-]", "", title.lower())
    output_filename = re.sub(r"[-\s]+", "-", output_filename)
    output_file = os.path.join(output_dir, f"{output_filename}.md")

    # Write the markdown file
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(markdown_content)

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


def process_recipe_keeper_to_markdown(recipe_keeper_file, extract_dir):
    """Main process to convert recipekeeper file to Markdown."""

    logging.info("Converting recipes to Markdown")
    decompress_recipes(recipe_keeper_file, extract_dir)

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
        description="Convert RecipeKeeper recipes to Markdown."
    )
    parser.add_argument(
        "--debug", action="store_true", default=False, help="Enable debug logging"
    )
    parser.add_argument("-f", "--file", help="Path to the .recipekeeperrecipes file.")
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
        # Export YYYY-MM-DD.*All Recipes.recipekeeperrecipes.zip
        # Make .zip optional, as on *Nix systems, this is not present
        regex = re.compile(r"RecipeKeeper_\d{8}_\d{6}\.zip$")
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
                "No matching files found in the directory. Export <DATE>All Recipes.recipekeeperrecipes.zip"
            )
            exit(1)
        logging.info(f"Found latest file: {latest_file}")
        args.file = latest_file

    if not os.path.exists(args.file):
        logging.info(f"Error: File {args.file} does not exist.")
    else:
        process_recipe_keeper_to_markdown(args.file, args.output_dir)

    # Copy log to output dir
    shutil.copy(log_file, args.output_dir)
    logging.info(f"Done. Log: {log_file}")
