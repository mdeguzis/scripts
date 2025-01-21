#!/usr/bin/env python3

import argparse
import base64
import json
import logging
import os
import re
import shutil
from io import BytesIO
from typing import Any, Dict, Optional

import isodate
import requests
from PIL import Image

home_dir = os.path.expanduser("~")
log_file = f"{home_dir}/recipe-sage-export.log"

def initialize_logger(
    log_level: int = logging.INFO,
    log_filename: Optional[str] = None,
    propagate: bool = False,
    scope: Optional[str] = None,
    debug_more: bool = False,
    formatter: str = "%(asctime)s - %(levelname)s - %(message)s",
) -> logging.Logger:
    """Initialize logger for both stdout and file output.

    Args:
        log_level: Logging level (default: logging.INFO)
        log_filename: Output file name (default: None)
        propagate: Whether to propagate to root logger (default: False)
        scope: Logger scope name (default: None)
        debug_more: Enable extra debug logging (default: False)
        formatter: Log message format (default: "%(asctime)s - %(levelname)s - %(message)s")

    Returns:
        Configured logger instance
    """
    if (
        formatter == "%(asctime)s - %(levelname)s - %(message)s"
        and log_level == logging.DEBUG
    ):
        formatter = "[%(name)s] %(asctime)s - %(levelname)s - %(message)s"

    if log_level == logging.DEBUG:
        formatter = f"[%(name)s] {formatter}"

    if not debug_more:
        for module in ["botocore", "urllib3"]:
            logging.getLogger(module).setLevel(logging.WARNING)

    logger = logging.getLogger(scope)
    logger.setLevel(log_level)
    logger.propagate = propagate

    console_handler = logging.StreamHandler()
    console_handler.setLevel(log_level)
    console_formatter = logging.Formatter(formatter)
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    if log_filename:
        if len(log_filename) < 4 or not log_filename.endswith(".log"):
            log_filename += ".log"

        file_handler = logging.FileHandler(log_filename, "w", encoding=None, delay=True)
        file_handler.setLevel(log_level)
        file_formatter = logging.Formatter(formatter)
        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)

    return logger


def generate_manifest(root_path):
    """
    Generate a manifest	of the directory structure and files.

    :param root_path: Path to the root directory
    :return: A nested dictionary representing the directory	structure and files
    """

    manifest = {}
    for root, dirs, files in os.walk(root_path):
        # Get the relative path	from the root directory
        relative_path = os.path.relpath(root, root_path)
        # Normalize	"."	as the root
        if relative_path == ".":
            relative_path = ""

        # Build	the	nested dictionary structure
        current = manifest
        if relative_path:
            for part in relative_path.split(os.sep):
                current = current.setdefault(part, {})

        # Add files	to the current level
        for file in files:
            if "files" not in current:
                current["files"] = []
            full_path = os.path.join(root, file)
            current["files"].append(full_path)

    return manifest


def resize_until_threshold(image_path, max_size=400, output_format="JPEG"):
    """
    Resizes	an image repeatedly	until both dimensions are under	the	specified max size.
    Then converts it to	a Base64 string.

    :param image_path: Path	to the input image
    :param max_size: Maximum width or height allowed
    :param output_format: Output format	for	the	image (default is JPEG)
    :return: Base64	encoded	string of the resized image
    """
    # Open the image
    with Image.open(image_path) as img:
        # Ensure the image is in RGB mode for formats like JPEG
        if img.mode != "RGB":
            img = img.convert("RGB")

        # Resize repeatedly	until both dimensions are under	max_size
        while img.width > max_size or img.height > max_size:
            img = img.resize(
                (img.width // 2, img.height // 2),
                Image.Resampling.LANCZOS,  # Updated from ANTIALIAS
            )

        # Save the resized image to	a buffer
        buffer = BytesIO()
        img.save(buffer, format=output_format, quality=85)  # Adjust quality as	needed
        buffer.seek(0)

        # Encode the image to Base64
        base64_string = base64.b64encode(buffer.read()).decode("utf-8")

        return base64_string

#!/usr/bin/env python3

import getpass
import json
import logging
import time
from typing import Any, Dict, Optional
from urllib.parse import urljoin

import requests


class RecipeSageAPI:
    """RecipeSage API client."""
    
    def __init__(self):
        self.base_url = "https://api.beta.recipesage.com"
        self.session = requests.Session()
        self.token: Optional[str] = None
        
        # Set default headers
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Origin': 'https://recipesage.com',
            'Referer': 'https://recipesage.com/'
        })

    def login(self, email: str, password: str) -> bool:
        """
        Authenticate with RecipeSage.
        
        Args:
            email: User's email
            password: User's password
            
        Returns:
            bool: True if login successful, False otherwise
        """
        login_url = urljoin(self.base_url, "/trpc/auth.login")
        
        try:
            # Construct login payload
            payload = {
                "json": {
                    "email": email,
                    "password": password
                }
            }
            
            logger.debug(f"Attempting login for {email}")
            response = self.session.post(login_url, json=payload)
            
            # Check response
            if response.status_code == 200:
                data = response.json()
                # Extract token from response
                if 'result' in data:
                    self.token = data['result'].get('token')
                    if self.token:
                        logger.info("Login successful")
                        # Update session headers with token
                        self.session.headers.update({
                            'Authorization': f'Bearer {self.token}'
                        })
                        return True
            
            logger.error(f"Login failed: {response.status_code} - {response.text}")
            return False
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Login request failed: {e}")
            return False

    def start_export_job(self) -> Optional[str]:
        """
        Start a new export job.
        
        Returns:
            str: Job ID if successful, None otherwise
        """
        if not self.token:
            logger.error("Not authenticated. Please login first.")
            return None
            
        export_url = urljoin(self.base_url, "/trpc/jobs.startExportJob")
        
        try:
            payload = {
                "json": {
                    "format": "jsonld"
                }
            }
            
            response = self.session.post(export_url, json=payload)
            
            if response.status_code == 200:
                data = response.json()
                job_id = data.get('result', {}).get('jobId')
                if job_id:
                    logger.info(f"Export job started: {job_id}")
                    return job_id
                    
            logger.error(f"Failed to start export job: {response.status_code} - {response.text}")
            return None
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Export job request failed: {e}")
            return None

    def get_jobs(self) -> Optional[Dict[str, Any]]:
        """
        Get list of export jobs.
        
        Returns:
            dict: Jobs data if successful, None otherwise
        """
        if not self.token:
            logger.error("Not authenticated. Please login first.")
            return None
            
        jobs_url = urljoin(self.base_url, "/trpc/jobs.getJobs")
        
        try:
            response = self.session.get(jobs_url)
            
            if response.status_code == 200:
                return response.json()
                
            logger.error(f"Failed to get jobs: {response.status_code} - {response.text}")
            return None
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Get jobs request failed: {e}")
            return None

    def wait_for_export(self, job_id: str, timeout: int = 300, interval: int = 5) -> Optional[Dict[str, Any]]:
        """
        Wait for export job to complete.
        
        Args:
            job_id: Export job ID to wait for
            timeout: Maximum time to wait in seconds
            interval: Time between checks in seconds
            
        Returns:
            dict: Export data if successful, None otherwise
        """
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            jobs = self.get_jobs()
            if not jobs:
                return None
                
            # Find our job
            for job in jobs.get('result', []):
                if job.get('jobId') == job_id:
                    status = job.get('status')
                    if status == 'completed':
                        logger.info("Export completed successfully")
                        return job.get('result')
                    elif status == 'failed':
                        logger.error("Export job failed")
                        return None
                        
            logger.debug(f"Export in progress, waiting {interval} seconds...")
            time.sleep(interval)
            
        logger.error(f"Export timed out after {timeout} seconds")
        return None


def fetch_export_file(output_dir):
    """
    Export recipes from RecipeSage by authenticating, starting an export job,
    and retrieving the list of jobs.
    """

    filename = None

    try:
        logger.info("Attempting to download your RecipeSage export file")

        api = RecipeSageAPI()
        # Get credentials (in practice, use environment variables or secure input)
        email = os.environ.get("SAGE_USER")
        if not email:
            email = input("Enter your RecipeSage email: ")
        password = os.environ.get("SAGE_PASSWORD")
        if not password:
            password = getpass.getpass("Enter your RecipeSage password: ")

        if not api.login(email, password):
            raise Exception("Failed to authenticate")
        
        # Start export
        job_id = api.start_export_job()
        if not job_id:
            raise Exception("Failed to start export")
        
        # Wait for export to complete
        result = api.wait_for_export(job_id)
        if result:
            json_data = result.json()
        else:
            raise Exception("Export failed")
        
        # Write JSON to file in output dir to scoop up
        filename = f"recipesage-data-{int(time.time() * 1000)}.json-ld.json"
        filepath = os.path.join(output_dir, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(json.dumps(json_data, indent=4))
        return filename

    except RuntimeError as e:
        raise RuntimeError("Failed to fetch export jobs: %s", e)


def download_and_base64(image_url):
    """
    Downloads an image from a given URL and converts it to a Base64 string.

    :param image_url: URL of the image to download.
    :return: Base64 string of the image or an error message.
    """

    try:
        logger.debug("Attempting to download %s", image_url)
        # Send a GET request to download the image
        response = requests.get(image_url, stream=True)
        response.raise_for_status()  # Raise an HTTPError for bad responses (4xx, 5xx)

        # Encode the image content to Base64
        image_base64 = base64.b64encode(response.content).decode("utf-8")
        logger.debug("Successfully downloaded and encoded %s", image_url)
        return f"data:image/jpeg;base64,{image_base64}"
    except Exception as e:
        return f"Error downloading or encoding the image: {e}"


def iso_to_human_readable(iso_time):
    """
    Converts ISO 8601 duration to a human-readable string, omitting seconds and truncating unnecessary parts.
    """

    try:
        # Parse the ISO 8601 duration
        duration = isodate.parse_duration(iso_time)
        # Convert to total seconds and calculate hours and minutes
        hours, remainder = divmod(duration.total_seconds(), 3600)
        minutes, _ = divmod(remainder, 60)
        # Build the human-readable string, omitting parts with 0 values
        readable_time = []
        if hours > 0:
            readable_time.append(f"{int(hours)}h")
        if (
            minutes > 0 or not readable_time
        ):  # Always show minutes, even if 0 (e.g., "0m")
            readable_time.append(f"{int(minutes)}m")
        return " ".join(readable_time)
    except Exception:
        return iso_time


def recipe_to_markdown(recipe):
    """
    Converts a single recipe from JSON to Markdown format.
    """

    markdown = f"# {recipe.get('name', 'Untitled Recipe')}\n\n"

    # Convert ISO times
    prep_time = iso_to_human_readable(recipe.get("prepTime", "N/A"))
    total_time = iso_to_human_readable(recipe.get("totalTime", "N/A"))

    # Add image	if available
    # Float image/text
    if "image" in recipe and recipe["image"]:
        image_base64 = download_and_base64(recipe["image"][0])
        markdown += '<div style="float: left; margin-right: 20px;">\n\n'
        markdown += f"![Recipe Photo]({image_base64})\n"
        markdown += "</div>\n\n"

    # Top summary info
    servings = recipe.get("recipeYield", "N/A")
    categories = ",".join(recipe.get("recipeCategory", "None"))
    credit_text = recipe.get("creditText", "")
    source_url = recipe.get("isBasedOn", "")
    source_url_formatted = f'<a href="{source_url}">{credit_text}</a>'

    markdown += '<div style="float: left;">\n\n'
    markdown += f"Categories: {categories}<br>\n"
    markdown += f"Source: {source_url_formatted}<br>\n"
    markdown += f"Prep time: {prep_time}<br>\n"
    markdown += f"Cook time: {total_time}<br>\n"
    if credit_text:
        markdown += f"Credit: {credit_text}<br>\n"
    if total_time:
        markdown += f"Total time: {total_time}<br>\n"
    markdown += f"Servings: {servings}\n"
    markdown += "</div>\n\n"

    # Clear the floats
    markdown += '<div style="clear: both;"></div>\n\n'

    # Basic	recipe information
    markdown += f"**Description:** \n{recipe.get('description', 'No description available.')}\n\n"

    # Ingredients
    markdown += "##	Ingredients\n\n"
    # Handle ingredients list
    ingredients = recipe.get("recipeIngredient", [])
    formatted_ingredients = []
    for ingredient in ingredients:
        if ingredient.strip():
            # If ingredient starts with an uppercase word, chances are it's a ingredient sub-header
            if ingredient[0].isupper():
                formatted_ingredients.append(f"\n{ingredient}\n")

            elif ingredient.endswith(":"):
                formatted_ingredients.append(f"\n{ingredient}\n")

            else:
                # Regular ingredient - add bullet point
                formatted_ingredients.append(f"- {ingredient}")

    markdown += "\n".join(formatted_ingredients)
    markdown += "\n\n"

    # Instructions
    markdown += "##	Instructions\n\n"
    if "recipeInstructions" in recipe:
        for step in recipe["recipeInstructions"]:
            markdown += f"1. {step.get('text', 'No step	description.')}\n"
    else:
        markdown += "No	instructions provided."
    markdown += "\n"

    # Comments or notes
    if "comment" in recipe:
        markdown += "##	Notes\n\n"
        for comment in recipe["comment"]:
            if comment.get("text", "").strip():
                markdown += f"-	{comment.get('text', '')}\n"

    return markdown


def export_recipes_to_markdown(json_file, output_dir, sync):
    """
    Exports recipes from JSON data to Markdown files.
    """

    processed_files = set()

    # Load JSON from file
    with open(json_file, "r", encoding="utf-8") as f:
        json_data = json.load(f)

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for recipe in json_data:
        # Use recipe name or identifier	as the filename
        filename = (
            recipe.get("name", recipe.get("identifier", "recipe"))
            .replace(" ", "-")
            .replace("/", "-")
            .replace("'", "")
            .replace("|", "")
            .lower()
        )
        # Convert all to lowercase
        filepath = os.path.join(output_dir, f"{filename}.md")

        # Convert recipe to	Markdown and save
        markdown = recipe_to_markdown(recipe)

        # Make an output_dir sub_dir based on preset categories I set
        # This is first-come-first serve processing to place recipes until I
        # have a better solution
        sub_folder_name = None
        categories = ",".join(recipe.get("recipeCategory", "None"))
        if len(categories) == 1:
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

        # Create the subfolder path
        file_output_dir = os.path.join(output_dir, sub_folder_name)
        os.makedirs(file_output_dir, exist_ok=True)
        output_file = os.path.join(file_output_dir, f"{filename}.md")

        with open(output_file, "w", encoding="utf-8") as md_file:
            md_file.write(markdown)

        processed_files.add(output_file)
        logger.info(f"Exported: {output_file}")

    if sync:
        sync_markdown_files(output_dir, processed_files)

def sync_markdown_files(extract_dir, processed_files):
    """
    Sync markdown files	by removing	duplicates and old recipes.
    Also removes corresponding JSON	files that are no longer needed.

    Args:
            extract_dir	(str): Base	directory containing markdown files
            processed_files	(set): Set of processed	file paths

    Returns:
            int: Number	of files removed during	sync
    """
    logging.warning("Syncing: Removing duplicates and old recipes...")
    removed_count = 0
    json_dir = os.path.join(extract_dir, "json")

    # First	find all markdown files
    all_markdown_files = {}
    for root, _, files in os.walk(extract_dir):
        if "json" in root:
            continue
        for file in files:
            if file.endswith(".md"):
                full_path = os.path.join(root, file)
                # Group	by filename
                if file not in all_markdown_files:
                    all_markdown_files[file] = [full_path]
                else:
                    all_markdown_files[file].append(full_path)

    # Now check	each file
    for filename, paths in all_markdown_files.items():
        # Get the correct path from	processed_files	if it exists
        correct_path = None
        for processed_path in processed_files:
            if os.path.basename(processed_path) == filename:
                correct_path = processed_path
                break

        if correct_path:
            # Remove any paths that	don't match	the	correct	one
            for path in paths:
                if path != correct_path:
                    logger.info(
                        "Removing duplicate	recipe:	%s (keeping	%s)", path, correct_path
                    )
                    os.remove(path)

                    # Remove corresponding JSON	file
                    json_filename = (
                        os.path.splitext(os.path.basename(path))[0] + ".json"
                    )
                    json_path = os.path.join(json_dir, json_filename)
                    if os.path.exists(json_path):
                        logger.info("Removing corresponding JSON file:	%s", json_path)
                        os.remove(json_path)

                    removed_count += 1
        else:
            # File doesn't exist in	source anymore,	remove all instances
            for path in paths:
                logger.info(
                    "Removing old recipe that no longer exists in source: %s", path
                )
                os.remove(path)

                # Remove corresponding JSON	file
                json_filename = os.path.splitext(os.path.basename(path))[0] + ".json"
                json_path = os.path.join(json_dir, json_filename)
                if os.path.exists(json_path):
                    logger.info("Removing corresponding JSON file:	%s", json_path)
                    os.remove(json_path)

                removed_count += 1

    logger.info("Sync complete. Removed %d files.", removed_count)
    return removed_count


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Convert RecipeSage	recipes	to Markdown."
    )
    parser.add_argument(
        "--debug", action="store_true", default=False, help="Enable	debug logging"
    )
    parser.add_argument("-a", "--auto-import", action='store_true', help=
                        "Automatically fetch export file from RecipeSage. Requires "
                        "SAGE_USER and SAGE_PASSWORD be set in the environment"
                        )
    parser.add_argument("-f", "--file", help="Path to the .recipekeeperrecipes file.")
    parser.add_argument(
        "-i",
        "--input-dir",
        help="Input	directory. This	will export	the	latest file	found.",
    )
    parser.add_argument("-o", "--output-dir", required=True, help="Output directory.")
    parser.add_argument(
        "-u",
        "--update",
        action="store_true",
        default=False,
        help="Overwrite/update existing	markdown files",
    )
    parser.add_argument(
        "-s",
        "--sync",
        action="store_true",
        default=False,
        help="Remove recipes in	output directory that don't	exist in source",
    )
    args = parser.parse_args()

    # logging
    if args.debug:
        logger = initialize_logger(log_level=logging.DEBUG)
    else:
        logger = initialize_logger()

    if args.auto_import:
        args.file = fetch_export_file(args.output_dir)
    else:
        if not args.file and not args.input_dir:
            logger.info("Please provide eithera file or an input directory.")
            exit(1)
        os.makedirs(args.output_dir, exist_ok=True)

    if args.input_dir:
        # Find the latest file in the directory	that matches:
        regex = re.compile(r"recipesage-data-\d+\.json-ld\.json")
        latest_file = None
        for input_file in os.listdir(args.input_dir):
            if regex.match(input_file):
                file_path = os.path.join(args.input_dir, input_file)
                if not latest_file or os.path.getmtime(file_path) > os.path.getmtime(
                    latest_file
                ):
                    latest_file = file_path

        if not latest_file:
            logging.error(
                "No	matching files found in	the	directory. Pattern:	recipesage-data-<ID>.json-ld.json"
            )
            exit(1)
        logger.info("Found	latest file: %s", latest_file)
        args.file = latest_file

    if not os.path.exists(args.file):
        logger.info("Error: File %s does not exist.", args.file)
    else:
        export_recipes_to_markdown(args.file, args.output_dir, args.sync)

    # Save a copy of the JSON file in the output directory
    logger.info("Saving a copy of the input JSON file in the output directory")
    data_dir = os.path.join(args.output_dir, "data")
    if not os.path.exists(data_dir):
        os.makedirs(data_dir)
    shutil.copy(args.file, data_dir)

    # Copy log to output dir
    shutil.copy(log_file, data_dir)
    logger.info("Done.	Log: %s", log_file)

    logger.info("See output directory: %s", args.output_dir)
        
