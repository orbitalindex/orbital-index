# Claude Code Project Guide

## Project Overview
The Orbital Index is a Jekyll-based static site hosting the archive of a weekly space newsletter (350 issues from Feb 2019 to Jan 2026).

## Build Commands
```bash
# Build the site
./bin/jekyll build

# Serve locally
./bin/jekyll serve
```

## Key Directories
- `archive/_posts/` - 350 newsletter HTML files (one per issue)
- `assets/img/` - Local images
- `assets/img/archive/` - Archived newsletter images from Mailchimp
- `bin/` - Processing scripts (Ruby)
- `_layouts/` - Jekyll layout templates
- `_includes/` - HTML includes/components
- `_plugins/` - Jekyll plugins (image lazy-loading)

## Archive File Format
Each issue is an HTML file with YAML front matter:
```yaml
---
layout: archive
title: Issue No. 123
image: /assets/img/archive/uuid.jpg  # Social preview image
---
```

## Image Hosting
- Images are stored locally in `assets/img/archive/`
- Images were originally hosted on Mailchimp (`mcusercontent.com` and `gallery.mailchimp.com`)
- Run `ruby bin/archive_images.rb` to re-download/re-archive images if needed

## Processing Scripts
- `bin/process.rb` - Import new newsletter from Mailchimp
- `bin/filter.rb` - Post-processing for archive files
- `bin/archive_images.rb` - Download and localize Mailchimp images
- `bin/token_archive.py` - Archive analysis tool
