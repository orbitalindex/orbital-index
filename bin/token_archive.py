#!/usr/bin/env python3
"""
Minimal multi-format parser for HTML or Markdown files, with optional:
1) Reverse chronological order (newest first).
2) YAML front matter removal.
3) Deduplication among consecutive or all files.
4) Token limit enforcement (tiktoken if installed, else approximate).
"""

import os
import re
import sys
import argparse
from datetime import datetime
from html.parser import HTMLParser

# Attempt tiktoken import. If missing, we fallback to approximate counting.
try:
    import tiktoken
    HAS_TIKTOKEN = True
except ImportError:
    HAS_TIKTOKEN = False

def log(message, error=False):
    """Simple logger to stdout or stderr."""
    prefix = "[ERROR]" if error else "[INFO]"
    stream = sys.stderr if error else sys.stdout
    print(f"{prefix} {message}", file=stream)

# Regex for removing HTML comments, YAML front matter, etc.
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
FRONT_MATTER_RE = re.compile(r"^---\s*(.*?)\s*---", re.DOTALL | re.MULTILINE)
MULTISPACE_RE = re.compile(r"\s+")

def parse_front_matter(text):
    """
    If YAML front matter is present between the first '---' lines,
    remove it and return the stripped text. Return original text if none found.
    """
    match = FRONT_MATTER_RE.search(text)
    if not match:
        # No front matter, return as is
        return text
    # Everything after the front matter
    end_idx = match.end()
    return text[end_idx:].strip()

class MinimalHTMLParser(HTMLParser):
    """
    Parse minimal visible text from HTML:
    - Ignores <script> and <style> content
    - Replaces block tags with newlines
    - Collapses whitespace
    """
    def __init__(self):
        super().__init__()
        self.in_script = False
        self.in_style = False
        self.current_data = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "script":
            self.in_script = True
        elif tag.lower() == "style":
            self.in_style = True

        if tag.lower() in ("p","div","section","article","br","h1","h2","h3","h4","h5","h6","li"):
            self.current_data.append("\n")

    def handle_endtag(self, tag):
        if tag.lower() == "script":
            self.in_script = False
        elif tag.lower() == "style":
            self.in_style = False

        if tag.lower() in ("p","div","section","article","h1","h2","h3","h4","h5","h6","li"):
            self.current_data.append("\n")

    def handle_data(self, data):
        if self.in_script or self.in_style:
            return
        text = data.strip()
        if text:
            self.current_data.append(" " + text + " ")

    def get_text(self):
        joined = "".join(self.current_data)
        # Remove extra whitespace
        joined = re.sub(MULTISPACE_RE, " ", joined)
        # Merge multiple newlines
        joined = re.sub(r"\n\s*\n+", "\n\n", joined)
        final = joined.strip()
        lines = [ln.strip() for ln in final.splitlines() if ln.strip()]
        return lines

def approximate_token_count(text):
    """Fallback approximate method if tiktoken unavailable."""
    return len(text)//4

def real_token_count(text, model="gpt-4o"):
    """Use tiktoken if installed, else approximate."""
    if not HAS_TIKTOKEN:
        return approximate_token_count(text)
    enc = tiktoken.encoding_for_model(model)
    return len(enc.encode(text))

def parse_html_content(html_text):
    """Remove HTML comments, parse minimal text using MinimalHTMLParser."""
    no_comments = re.sub(COMMENT_RE, "", html_text)
    parser = MinimalHTMLParser()
    parser.feed(no_comments)
    return parser.get_text()

def parse_markdown(text):
    """
    For Markdown, we just split on lines, removing extra blank lines.
    You could do more advanced markdown parsing if you wish.
    """
    lines = text.splitlines()
    # Trim and remove empties
    lines = [ln.strip() for ln in lines if ln.strip()]
    return lines

def main():
    parser = argparse.ArgumentParser(description="Process .html or .md files, removing YAML front matter.")
    parser.add_argument("--input-dir", default="_posts",
                        help="Directory with .html/.md files (default _posts).")
    parser.add_argument("--output", default="text_archive.txt",
                        help="Output text file (default text_archive.txt).")
    parser.add_argument("--token-limit", type=int, default=0,
                        help="Stop after this token limit is reached (0=off).")
    parser.add_argument("--model", default="gpt-4o",
                        help="Model for tiktoken if installed (default gpt-4o).")
    parser.add_argument("--deduplicate-mode", choices=["none","consecutive","all"], default="none",
                        help="Line deduplication method (default: none).")
    parser.add_argument("--omit-filename", action="store_true",
                        help="Omit filename headers in the output.")
    args = parser.parse_args()

    in_dir = args.input_dir
    out_file = args.output
    token_limit = args.token_limit
    model_name = args.model
    dedup_mode = args.deduplicate_mode
    omit_filename = args.omit_filename

    # Warn if tiktoken not installed
    if not HAS_TIKTOKEN:
        log("tiktoken not installed. Using approximate token counting. Install with `pip install tiktoken`.")

    if not os.path.isdir(in_dir):
        log(f"Directory '{in_dir}' does not exist.", error=True)
        sys.exit(1)

    # We want to handle .html or .md
    # Reverse chronological order means we can just do sorted(..., reverse=True),
    # assuming filenames are date-based or otherwise sorted. If you have actual timestamps,
    # you might want to sort by file mod time, etc.
    all_files = [f for f in os.listdir(in_dir) if (f.lower().endswith(".html") or f.lower().endswith(".md"))]
    if not all_files:
        log("No .html or .md files found in the input directory.", error=True)
        sys.exit(1)

    # Sort descending => newest first (alphabetically, or date-based if your filenames are date stamped).
    all_files.sort(reverse=True)

    # Dedup sets
    used_lines_all = set()
    prev_file_lines = set()

    total_tokens = 0
    archive_lines = []

    for fname in all_files:
        path = os.path.join(in_dir, fname)
        log(f"Processing: {path}")
        try:
            with open(path, "r", encoding="utf-8") as f:
                raw = f.read()
        except Exception as e:
            log(f"Error reading file '{fname}': {e}", error=True)
            continue

        # 1) Remove YAML front matter if present
        stripped = parse_front_matter(raw)

        # 2) Parse based on extension
        if fname.lower().endswith(".html"):
            lines = parse_html_content(stripped)
        else:
            # Markdown
            lines = parse_markdown(stripped)

        # Dedup lines if requested
        if dedup_mode == "consecutive":
            filtered = [ln for ln in lines if ln not in prev_file_lines]
        elif dedup_mode == "all":
            filtered = [ln for ln in lines if ln not in used_lines_all]
        else:
            filtered = lines

        prev_file_lines = set(lines)
        used_lines_all.update(lines)

        # Optional file header
        if not omit_filename:
            header = [f"=== {fname} ===", ""]
        else:
            header = []

        # Combine
        chunk_lines = header + filtered + [""]

        # Check token usage
        chunk_text = "\n".join(chunk_lines)
        chunk_tokens = real_token_count(chunk_text, model=model_name)

        if token_limit > 0 and total_tokens + chunk_tokens > token_limit:
            # partial line-by-line
            for line in chunk_lines:
                line_tokens = real_token_count(line, model=model_name) + 1
                if total_tokens + line_tokens <= token_limit:
                    archive_lines.append(line)
                    total_tokens += line_tokens
                else:
                    log(f"Token limit {token_limit} reached. Stopping.", error=True)
                    break
            break
        else:
            archive_lines.extend(chunk_lines)
            total_tokens += chunk_tokens

    # Write final
    try:
        with open(out_file, "w", encoding="utf-8") as outf:
            outf.write("\n".join(archive_lines))
    except Exception as e:
        log(f"Error writing output '{out_file}': {e}", error=True)
        sys.exit(1)

    log(f"Archive created: {out_file}")
    log(f"Total tokens used: {total_tokens}")
    if token_limit > 0:
        remainder = max(0, token_limit - total_tokens)
        log(f"Token limit: {token_limit}, remaining: {remainder}")

if __name__ == "__main__":
    main()