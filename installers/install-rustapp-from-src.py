import os
import subprocess
import shutil
import stat
import sys
import platform
import argparse
import glob

from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Install Rust application binaries from GitHub source",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s cooklang/cookcli                 # Install from main branch
  %(prog)s cooklang/cookcli --branch dev    # Install from dev branch
  %(prog)s cooklang/cookcli --binary cook   # Install specific binary
  %(prog)s cooklang/cookcli --no-cleanup-source  # Keep source after building
        """,
    )
    parser.add_argument(
        "repository", help="GitHub repository path (e.g., cooklang/cookcli)"
    )
    parser.add_argument(
        "--binary",
        help="Name of the binary to look for (optional if only one binary exists)",
        default=None,
    )
    parser.add_argument(
        "--branch", help="Specific branch or tag to clone", default="main"
    )
    parser.add_argument(
        "--cleanup-source",
        help="Remove source code after successful installation (default: True)",
        action="store_true",
        default=True,
    )
    parser.add_argument(
        "--no-cleanup-source",
        help=argparse.SUPPRESS,  # Hide from help since it's just the inverse
        dest="cleanup_source",
        action="store_false",
    )
    return parser.parse_args()


def handle_multiple_binaries(binaries):
    """
    Prompt user to select which binary to install when multiple are found.

    Args:
        binaries (list): List of binary paths/names found

    Returns:
        str: Selected binary path/name or None if user cancels
    """
    print("\nMultiple binaries found. Please select which one to install:")

    for idx, binary in enumerate(binaries, 1):
        print(f"{idx}. {binary}")

    while True:
        try:
            choice = input("\nEnter number (or 'q' to quit): ")

            if choice.lower() == "q":
                return None

            choice_idx = int(choice) - 1
            if 0 <= choice_idx < len(binaries):
                return binaries[choice_idx]
            else:
                print(f"Please enter a number between 1 and {len(binaries)}")
        except ValueError:
            print("Please enter a valid number or 'q' to quit")


def install_binary(source_path, binary_name, target_dir):
    """
    Install binary to target directory
    """
    source = source_path / binary_name
    target = target_dir / binary_name

    if not source.exists():
        print(f"Error: Source binary {source} does not exist")
        return False

    try:
        shutil.copy2(source, target)
        # Ensure the copied file is executable
        target.chmod(target.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        print(f"Successfully installed {binary_name} to {target}")
        return True
    except Exception as e:
        print(f"Error installing binary: {e}")
        return False


def ensure_local_bin():
    """
    Ensure ~/.local/bin exists and is in PATH
    """
    local_bin = Path.home() / ".local/bin"
    local_bin.mkdir(parents=True, exist_ok=True)

    if str(local_bin) not in os.environ["PATH"].split(os.pathsep):
        print(f"Warning: {local_bin} is not in PATH")
        print("Consider adding this line to your shell profile:")
        print(f'export PATH="$PATH:{local_bin}"')

    return local_bin


def check_dependencies():
    """Check if required tools are installed"""
    dependencies = {
        "git": "git --version",
        "rust": "rustc --version",
        "node": "node --version",
        "npm": "npm --version",
    }

    missing = []
    for dep, command in dependencies.items():
        try:
            subprocess.run(command, shell=True, check=True, capture_output=True)
        except subprocess.CalledProcessError:
            missing.append(dep)

    return missing


def clone_repository(repo_path):
    """Clone the GitHub repository"""
    try:
        subprocess.run(["git", "clone", f"https://github.com/{repo_path}"], check=True)
        return repo_path.split("/")[-1]
    except subprocess.CalledProcessError as e:
        print(f"Error cloning repository: {e}")
        sys.exit(1)


def is_binary(file_path):
    """
    Check if a file is a binary executable.
    """
    if not Path(file_path).is_file():
        return False

    # Check if file has execute permission
    return bool(os.stat(file_path).st_mode & stat.S_IXUSR)


def build_ui(project_dir):
    """Build the UI component if it exists"""
    ui_dir = os.path.join(project_dir, "ui")
    if not os.path.exists(ui_dir):
        print("No UI directory found, skipping UI build...")
        return

    try:
        os.chdir(ui_dir)
        subprocess.run(["npm", "install"], check=True)
        subprocess.run(["npm", "run", "build"], check=True)
        os.chdir("..")
    except subprocess.CalledProcessError as e:
        print(f"Error building UI: {e}")
        sys.exit(1)


def build_rust_project():
    """Build the Rust project"""
    try:
        subprocess.run(["cargo", "build", "--release"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error building Rust project: {e}")
        sys.exit(1)


def find_binary(project_dir, binary_name=None):
    """Find the binary in target/release directory"""
    release_dir = os.path.join(project_dir, "target", "release")
    if not os.path.exists(release_dir):
        print("Release directory not found!")
        return None

    # Get all executables in the release directory
    system = platform.system()
    if system == "Windows":
        binaries = glob.glob(os.path.join(release_dir, "*.exe"))
    else:
        # On Unix-like systems, we need to check file permissions
        binaries = [
            f
            for f in glob.glob(os.path.join(release_dir, "*"))
            if os.path.isfile(f) and os.access(f, os.X_OK)
        ]

    if not binaries:
        print("No binaries found in release directory!")
        return None

    if binary_name:
        # Look for specific binary
        binary_pattern = f"{binary_name}.exe" if system == "Windows" else binary_name
        matching_binaries = [
            b for b in binaries if os.path.basename(b).startswith(binary_pattern)
        ]
        if matching_binaries:
            return matching_binaries[0]
        print(f"Specified binary '{binary_name}' not found!")
        return None

    if len(binaries) == 1:
        return binaries[0]
    else:
        print("\nMultiple binaries found:")
        for idx, binary in enumerate(binaries, 1):
            print(f"{idx}. {os.path.basename(binary)}")
        while True:
            try:
                choice = int(input("\nSelect binary number (or 0 to exit): "))
                if choice == 0:
                    return None
                if 1 <= choice <= len(binaries):
                    return binaries[choice - 1]
                print("Invalid selection!")
            except ValueError:
                print("Please enter a valid number!")


def clone_and_build(repo, branch):
    """
    Clone repository and build the Rust project
    """
    # Create and use ~/cargo-install-source directory
    work_dir = Path.home() / "cargo-install-source"
    work_dir.mkdir(parents=True, exist_ok=True)

    # Create subdirectory for this specific repo
    repo_name = repo.split("/")[-1]
    repo_dir = work_dir / repo_name

    # Remove existing directory if it exists
    if repo_dir.exists():
        shutil.rmtree(repo_dir)

    print(f"Cloning repository {repo}...")
    clone_url = f"https://github.com/{repo}.git"

    try:
        # Stream git clone output directly to terminal
        process = subprocess.Popen(
            ["git", "clone", "--depth", "1", "-b", branch, clone_url, str(repo_dir)],
            stdout=None,  # This will use parent's stdout/stderr
            stderr=None,  # This will use parent's stdout/stderr
        )
        process.wait()

        if process.returncode != 0:
            print(f"Error: Failed to clone repository {repo}")
            return None

    except Exception as e:
        print(f"Error cloning repository: {e}")
        return None

    print("\nBuilding project...")
    try:
        # Stream cargo build output directly to terminal
        process = subprocess.Popen(
            ["cargo", "build", "--release"],
            cwd=repo_dir,
            stdout=None,  # This will use parent's stdout/stderr
            stderr=None,  # This will use parent's stdout/stderr
        )
        process.wait()

        if process.returncode != 0:
            print("Error: Build failed")
            return None

    except Exception as e:
        print(f"Error building project: {e}")
        return None

    target_dir = repo_dir / "target" / "release"
    if not target_dir.exists():
        print("Error: Build directory not found")
        return None

    return target_dir


def main():
    args = parse_args()

    # Check if cargo is available
    try:
        subprocess.run(["cargo", "--version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Error: Rust's cargo is not installed or not in PATH")
        return 1

    # Ensure ~/.local/bin exists and is in PATH
    target_dir = ensure_local_bin()

    # Clone and build the project
    release_dir = clone_and_build(args.repository, args.branch)
    if not release_dir:
        return 1

    # Find all executable files in the release directory
    binaries = []
    for item in release_dir.iterdir():
        if is_binary(item):
            binaries.append(item.name)

    if not binaries:
        print("No binary executables found in release directory")
        return 1

    # Handle binary selection
    if args.binary:
        if args.binary not in binaries:
            print(
                f"Error: Specified binary '{args.binary}' not found in release directory"
            )
            return 1
        selected_binary = args.binary
    elif len(binaries) == 1:
        selected_binary = binaries[0]
    else:
        selected_binary = handle_multiple_binaries(binaries)
        if not selected_binary:
            print("Installation cancelled")
            return 1

    # Install the selected binary
    install_success = install_binary(release_dir, selected_binary, target_dir)

    # Clean up source code if requested and installation was successful
    if install_success and args.cleanup_source:
        source_dir = release_dir.parent.parent  # Go up from target/release to root
        try:
            shutil.rmtree(source_dir)
            print(f"Cleaned up source directory: {source_dir}")
        except Exception as e:
            print(f"Warning: Could not clean up source directory: {e}")

    return 0 if install_success else 1


if __name__ == "__main__":
    sys.exit(main())
