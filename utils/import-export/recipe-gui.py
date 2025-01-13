#!/usr/bin/env python3

import argparse
import base64
import json
import os
import re
import sys
import tempfile

import markdown
from markdown_it import MarkdownIt
from PyQt5.QtCore import QDir, Qt
from PyQt5.QtGui import QStandardItem, QStandardItemModel
from PyQt5.QtWebEngineWidgets import QWebEngineView
from PyQt5.QtWidgets import (
    QAbstractItemView,
    QApplication,
    QMainWindow,
    QSplitter,
    QTreeView,
    QVBoxLayout,
    QWidget,
)


class ManifestTreeView(QTreeView):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setHeaderHidden(True)
        self.setSelectionMode(QAbstractItemView.SingleSelection)
        self.setSelectionBehavior(QAbstractItemView.SelectRows)

        # Disable editing in the tree
        self.setEditTriggers(QTreeView.NoEditTriggers)

        # To store the mapping from the tree structure to file paths
        self.path_mapping = {}

    def add_manifest_items(self, parent, data, path=""):
        for key, value in data.items():
            if isinstance(value, dict):
                if "files" in value:
                    # Add directory as a tree item
                    dir_item = QStandardItem(key)
                    parent_item = dir_item
                    parent.appendRow(dir_item)
                    for file_path in value["files"]:
                        # Add files as child items of the directory
                        file_item = QStandardItem(file_path)
                        parent_item.appendRow(file_item)
                        self.path_mapping[file_path] = file_path
                else:
                    # Add nested folder structure
                    parent_item = QStandardItem(key)
                    parent.appendRow(parent_item)
                self.add_manifest_items(parent_item, value, path)

        # Ensure the column has enough width based on content size
        self.adjust_column_width()

    def adjust_column_width(self):
        def calculate_item_width(item, depth=0):
            """
            Recursively calculate the width of the text and add padding for tree depth.
            """
            text_width = item.sizeHint().width() if item else 0
            # Add padding for indentation based on depth
            total_width = text_width + (depth * 20)  # 20px per level of indentation
            max_width = total_width

            # Recursively check child items
            for row in range(item.rowCount()):
                child_item = item.child(row)
                max_width = max(max_width, calculate_item_width(child_item, depth + 1))

            return max_width

        # Start calculation from the root item
        root_item = self.model().invisibleRootItem()
        column_width = calculate_item_width(root_item)

        # Add buffer to avoid clipping
        column_width += 30  # Add some extra buffer for visual comfort

        # Set the column width
        self.setColumnWidth(0, column_width)


from markdown_it import MarkdownIt


class MarkdownViewer(QMainWindow):
    def __init__(self, manifest):
        super().__init__()
        self.setWindowTitle("Manifest Viewer")
        self.setGeometry(100, 100, 800, 600)

        # WebEngine View for rendering HTML content
        self.browser = QWebEngineView(self)

        # CSS to style tables
        self.table_css = """
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 8px;
            text-align: left;
            border: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
        }
        """

        # Create a splitter to separate the tree view and markdown preview
        self.splitter = QSplitter(Qt.Horizontal)

        # Create the tree view widget for the manifest
        self.tree_view = ManifestTreeView(self)

        # Initialize the model
        self.model = QStandardItemModel()
        self.tree_view.setModel(self.model)

        # Add the files from the manifest
        self.tree_view.add_manifest_items(self.model.invisibleRootItem(), manifest)

        # Double-click to open the markdown file
        self.tree_view.doubleClicked.connect(self.open_file)

        # Add the tree view and markdown viewer to the splitter
        self.splitter.addWidget(self.tree_view)
        self.splitter.addWidget(self.browser)
        self.splitter.setSizes(
            [300, 600]
        )  # Set default split ratio for wider filenames

        # Set the splitter as the central widget
        self.setCentralWidget(self.splitter)

    def open_file(self, index):
        file_path = self.tree_view.path_mapping.get(index.data(), "")

        if file_path:
            print(f"Opening file: {file_path}")  # Debugging line
            # Read the markdown file
            with open(file_path, "r", encoding="utf-8") as f:
                markdown_content = f.read()

            # Use markdown-it-py to convert Markdown to HTML
            md = MarkdownIt()
            html_content = md.render(markdown_content)

            # Add custom CSS to the HTML content for proper table rendering
            html_content = self.apply_custom_css(html_content)

            # Handle base64 images in Markdown
            html_content = self.handle_base64_images(html_content, file_path)

            # Render HTML in the browser widget
            self.browser.setHtml(html_content)

    def apply_custom_css(self, html_content):
        """
        Apply custom CSS to the HTML content for proper table rendering.
        """
        style_tag = f"<style>{self.table_css}</style>"
        return style_tag + html_content

    def handle_base64_images(self, html_content, file_path):
        """
        Process base64 images in HTML content to ensure proper rendering with size constraints.
        """
        import re

        # Regex to find image patterns in Markdown
        img_pattern = r"!\[.*?\]\((data:image\/.*?;base64,.*?)\)"

        # Replace the Markdown image syntax with an HTML image tag
        def replace_img_tag(match):
            base64_data = match.group(1)
            return f'<img src="{base64_data}" alt="Image" style="max-width:80%; height:auto;"/>'

        processed_html = re.sub(img_pattern, replace_img_tag, html_content)
        return processed_html


def main(manifest_file):
    try:
        with open(manifest_file, "r") as f:
            manifest = json.load(f)
    except Exception as e:
        print(f"Error loading manifest: {e}")
        return

    app = QApplication(sys.argv)
    viewer = MarkdownViewer(manifest)
    viewer.show()
    sys.exit(app.exec_())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Display a JSON manifest in a GUI.")
    parser.add_argument(
        "manifest_file",
        metavar="FILE",
        type=str,
        help="Path to the manifest JSON file.",
    )
    args = parser.parse_args()

    main(args.manifest_file)
