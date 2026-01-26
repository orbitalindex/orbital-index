#!/usr/bin/env ruby
# frozen_string_literal: true

# Archive Images Script
# Downloads all Mailchimp-hosted images and resolves redirect URLs
# Usage: ruby bin/archive_images.rb [--dry-run]

require 'net/http'
require 'uri'
require 'fileutils'
require 'set'

DRY_RUN = ARGV.include?('--dry-run')
ARCHIVE_DIR = File.expand_path('../archive/_posts', __dir__)
IMAGE_DIR = File.expand_path('../assets/img/archive', __dir__)

# Mailchimp image URL patterns
MAILCHIMP_IMAGE_PATTERNS = [
  /https?:\/\/gallery\.mailchimp\.com\/[^\/]+\/images\/[^\s"'<>]+/,
  /https?:\/\/mcusercontent\.com\/[^\/]+\/images\/[^\s"'<>]+/,
  /https?:\/\/mcusercontent\.com\/[^\/]+\/_compresseds\/[^\s"'<>]+/
]

# Mailchimp redirect URL patterns
MAILCHIMP_REDIRECT_PATTERNS = [
  /https?:\/\/[^\/]*\.list-manage\.com\/track\/click\?[^\s"'<>]+/,
  /https?:\/\/click\.mailchimp\.com\/[^\s"'<>]+/
]

def log(msg)
  puts "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
end

def download_image(url, dest_path)
  return true if DRY_RUN

  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.open_timeout = 10
  http.read_timeout = 30

  request = Net::HTTP::Get.new(uri.request_uri)
  request['User-Agent'] = 'Mozilla/5.0 (compatible; OrbitalIndex/1.0)'

  response = http.request(request)

  case response
  when Net::HTTPSuccess
    File.open(dest_path, 'wb') { |f| f.write(response.body) }
    true
  when Net::HTTPRedirection
    # Follow redirect
    new_url = response['location']
    if new_url
      log "  Redirected to: #{new_url}"
      download_image(new_url, dest_path)
    else
      false
    end
  else
    log "  Failed: #{response.code} #{response.message}"
    false
  end
rescue StandardError => e
  log "  Error: #{e.message}"
  false
end

def resolve_redirect(url, max_redirects = 5)
  return url if max_redirects <= 0

  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.open_timeout = 10
  http.read_timeout = 10

  request = Net::HTTP::Head.new(uri.request_uri)
  request['User-Agent'] = 'Mozilla/5.0 (compatible; OrbitalIndex/1.0)'

  response = http.request(request)

  case response
  when Net::HTTPRedirection
    new_url = response['location']
    if new_url
      # Handle relative redirects
      new_url = URI.join(url, new_url).to_s if new_url.start_with?('/')
      resolve_redirect(new_url, max_redirects - 1)
    else
      url
    end
  else
    url
  end
rescue StandardError => e
  log "  Error resolving #{url}: #{e.message}"
  url
end

def extract_filename_from_url(url)
  # Extract UUID and extension from Mailchimp URLs
  # Example: https://mcusercontent.com/e215b9e6f9a105b2c34f627a3/images/abc123-def4-5678.jpg
  # Example: https://mcusercontent.com/e215b9e6f9a105b2c34f627a3/_compresseds/abc123-def4-5678.jpg
  if url =~ /\/(?:images|_compresseds)\/([a-f0-9-]+\.[a-z]+)/i
    $1
  else
    # Fallback: use last path segment
    URI.parse(url).path.split('/').last
  end
end

def find_all_mailchimp_urls(content)
  image_urls = Set.new
  redirect_urls = Set.new

  # Force UTF-8 encoding
  content = content.encode('UTF-8', invalid: :replace, undef: :replace)

  MAILCHIMP_IMAGE_PATTERNS.each do |pattern|
    content.scan(pattern).each { |url| image_urls.add(url) }
  end

  MAILCHIMP_REDIRECT_PATTERNS.each do |pattern|
    content.scan(pattern).each { |url| redirect_urls.add(url) }
  end

  [image_urls, redirect_urls]
end

def process_archive_files
  FileUtils.mkdir_p(IMAGE_DIR) unless DRY_RUN

  archive_files = Dir.glob(File.join(ARCHIVE_DIR, '*.html')).sort
  log "Found #{archive_files.length} archive files"

  all_image_urls = Set.new
  all_redirect_urls = Set.new
  url_to_local = {}
  redirect_resolutions = {}

  # First pass: collect all URLs
  log "\n=== Pass 1: Collecting URLs ==="
  archive_files.each do |file|
    content = File.read(file, encoding: 'UTF-8')
    image_urls, redirect_urls = find_all_mailchimp_urls(content)
    all_image_urls.merge(image_urls)
    all_redirect_urls.merge(redirect_urls)
  end

  log "Found #{all_image_urls.length} unique Mailchimp image URLs"
  log "Found #{all_redirect_urls.length} unique Mailchimp redirect URLs"

  # Second pass: download images
  log "\n=== Pass 2: Downloading Images ==="
  downloaded = 0
  failed = 0
  skipped = 0

  all_image_urls.each_with_index do |url, idx|
    filename = extract_filename_from_url(url)
    local_path = File.join(IMAGE_DIR, filename)
    relative_path = "/assets/img/archive/#{filename}"

    if File.exist?(local_path)
      log "[#{idx + 1}/#{all_image_urls.length}] Skipping (exists): #{filename}"
      skipped += 1
      url_to_local[url] = relative_path
    else
      log "[#{idx + 1}/#{all_image_urls.length}] Downloading: #{url}"
      if download_image(url, local_path)
        downloaded += 1
        url_to_local[url] = relative_path
      else
        failed += 1
        # Keep original URL if download fails
        url_to_local[url] = url
      end
    end
  end

  log "\nImages: #{downloaded} downloaded, #{skipped} skipped, #{failed} failed"

  # Third pass: resolve redirects
  log "\n=== Pass 3: Resolving Redirect URLs ==="
  all_redirect_urls.each_with_index do |url, idx|
    log "[#{idx + 1}/#{all_redirect_urls.length}] Resolving: #{url[0..60]}..."
    resolved = resolve_redirect(url)
    if resolved != url
      log "  -> #{resolved[0..60]}..."
      redirect_resolutions[url] = resolved
    else
      log "  (unchanged)"
      redirect_resolutions[url] = url
    end
  end

  # Fourth pass: update files
  log "\n=== Pass 4: Updating Archive Files ==="
  files_updated = 0

  archive_files.each do |file|
    content = File.read(file, encoding: 'UTF-8')
    original_content = content.dup

    # Replace image URLs
    url_to_local.each do |old_url, new_path|
      content.gsub!(old_url, new_path)
    end

    # Replace redirect URLs
    redirect_resolutions.each do |old_url, new_url|
      content.gsub!(old_url, new_url) if old_url != new_url
    end

    if content != original_content
      files_updated += 1
      basename = File.basename(file)
      log "Updating: #{basename}"
      File.write(file, content) unless DRY_RUN
    end
  end

  log "\n=== Summary ==="
  log "Files updated: #{files_updated}"
  log "Images downloaded: #{downloaded}"
  log "Images skipped (already exist): #{skipped}"
  log "Images failed: #{failed}"
  log "Redirects resolved: #{redirect_resolutions.count { |k, v| k != v }}"
  log "\nDone!#{DRY_RUN ? ' (DRY RUN - no changes made)' : ''}"
end

# Main
if __FILE__ == $PROGRAM_NAME
  log "Orbital Index Image Archiver"
  log "Archive dir: #{ARCHIVE_DIR}"
  log "Image dir: #{IMAGE_DIR}"
  log "Mode: #{DRY_RUN ? 'DRY RUN' : 'LIVE'}"
  log ""

  process_archive_files
end
