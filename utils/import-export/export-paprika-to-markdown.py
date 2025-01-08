#!/usr/bin/env python3

import gzip
import json
import os
import zipfile


def extract_paprika_file(paprika_file, extract_dir):
    """Extracts the main Paprika export zip file."""
    if not zipfile.is_zipfile(paprika_file):
        print(f"Error: {paprika_file} is not a valid zip file.")
        return None

    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(paprika_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    print(f"Extracted Paprika recipes to: {extract_dir}")
    return extract_dir


def decompress_recipes(paprika_file, extract_dir):
    """Decompresses all `.paprikarecipe` (gzip) files in the directory."""

    print(f"Decompressing Paprika file {paprika_file}")

    # Create a directory for the extracted recipes
    os.makedirs(extract_dir, exist_ok=True)

    # First, extract all files from the zip archive
    print(f"Extracting recipes from {paprika_file}")
    with zipfile.ZipFile(paprika_file, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    for file_name in os.listdir(extract_dir):
        print(f"Decompressing recipe: {file_name}")
        if file_name.endswith(".paprikarecipe"):
            file_path = os.path.join(extract_dir, file_name)
            with gzip.open(file_path, "rt", encoding="utf-8") as gz_file:
                json_data = gz_file.read()

            file_name = file_name.lower().replace(" ", "-")
            json_file_path = os.path.splitext(file_path)[0] + ".json"
            with open(json_file_path, "w", encoding="utf-8") as json_file:
                json_file.write(json_data)

            # Rename the JSON file, lowercase, space to dash
            os.rename(json_file_path, json_file_path.lower().replace(" ", "-"))

            # Remove the original .paprikarecipe file
            os.remove(file_path)
            print(f"Decompressed: {file_name} to {json_file_path}")

    # Remove all .paprikareDecompressing Paprika filcipe files from the extract dir
    for file_name in os.listdir(extract_dir):
        if file_name.endswith(".paprikarecipe"):
            os.remove(os.path.join(extract_dir, file_name))


def convert_json_to_markdown(json_file, output_dir):
    """Converts a single JSON recipe file to Markdown format."""

    print("Converting JSON to Markdown")
    with open(json_file, "r", encoding="utf-8") as f:
        recipe_data = json.load(f)

    title = recipe_data.get("name", "Untitled Recipe")
    title = title.lower().replace(" ", "-")

    # Split ingredients to list
    ingredients = recipe_data.get("ingredients", "")
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
    servings = recipe_data.get("servings", "")
    rating = recipe_data.get("rating", "")
    source = recipe_data.get("source", "")
    source_url = recipe_data.get("source_url", "")

    # Photo data
    # Assuming photo_data contains the base64 string
    markdown_content = ""
    if photo_data := recipe_data.get("photo_data", ""):
        image_data = f"data:image/jpeg;base64,{photo_data}"
        markdown_content += '<div style="float: left; margin-right: 20px;">\n\n'
        markdown_content += f"![Recipe Photo]({image_data})\n"
        markdown_content += "</div>\n\n"

    # Top summary info
    # Top summary info
    markdown_content += '<div style="float: right;">\n'
    markdown_content += f"Prep time:{prep_time}<br>\n"
    markdown_content += f"Cook time:{cook_time}<br>\n"
    markdown_content += f"Total time:{total_time}<br>\n"
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

    output_file = os.path.join(output_dir, f"{title}.md")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(markdown_content)

    print(f"Converted to Markdown: {output_file}")


def process_paprika_to_markdown(paprika_file, extract_dir):
    """Main process to convert Paprika file to Markdown."""

    print("Converting recipes to Markdown")
    decompress_recipes(paprika_file, extract_dir)
    output_dir = os.path.join(extract_dir, "markdown_recipes")
    os.makedirs(output_dir, exist_ok=True)

    for file_name in os.listdir(extract_dir):
        if file_name.endswith(".json"):
            json_file = os.path.join(extract_dir, file_name)
            convert_json_to_markdown(json_file, output_dir)

    print(f"All recipes converted to Markdown in: {output_dir}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Convert Paprika 3 recipes to Markdown."
    )
    parser.add_argument(
        "-f", "--file", required=True, help="Path to the .paprikarecipes file."
    )
    parser.add_argument("-o", "--output-dir", required=True, help="Output directory.")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    if not os.path.exists(args.file):
        print(f"Error: File {args.paprika_file} does not exist.")
    else:
        process_paprika_to_markdown(args.file, args.output_dir)
