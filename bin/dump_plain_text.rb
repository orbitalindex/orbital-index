#!/usr/bin/env ruby

require 'fileutils'
require 'shellwords'

# Ensure the output directory exists
output_dir = './plain_text/files'
combined_file = './plain_text/output.txt'
FileUtils.mkdir_p(output_dir)

# Directory containing the HTML files
input_dir = './archive/_posts'

# Loop over each HTML file in the input directory
Dir.glob(File.join(input_dir, '*.html')).each do |html_file|
  # Construct the output file path
  txt_file = File.join(output_dir, File.basename(html_file, '.html') + '.txt')
  
  # Properly escape filenames for shell command
  safe_html_file = Shellwords.escape(html_file)
  safe_txt_file = Shellwords.escape(txt_file)

  # Run the 'links' command and redirect output to the text file
  system("links -dump -codepage UTF-8 #{safe_html_file} | sed -n '/The Orbital Index/,$p' > #{safe_txt_file}")
end

# Ensure the output file is empty or create it if it doesn't exist
File.open(combined_file, 'w') {}

# Loop over each .txt file in the directory
Dir.glob(File.join(output_dir, '*.txt')).each do |file_path|
  # Read the content of the current file
  content = File.read(file_path)

  # Open the output file in append mode
  File.open(combined_file, 'a') do |file|
    file.puts "\n\n"
    file.puts content
    file.puts "\n\n"
  end
end
