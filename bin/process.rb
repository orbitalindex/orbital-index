#!/usr/bin/env ruby

require 'open-uri'
require 'date'

begin
  require 'nokogiri'
rescue LoadError
  puts "Run 'gem install nokogiri'"
  exit 1
end

print "URL for mailchimp email: "
STDOUT.flush

url = gets.chomp
html = URI.open(url).read
doc = Nokogiri::HTML.parse(html)
body = doc.css(".templateContainer").first

issue = body.css("#templateHeader").text
if issue && !issue.empty? && (matcher = issue.match(/Issue[[:space:]]+No\.[[:space:]]+(\d+)[[:space:]]+\|[[:space:]]+(\w+[[:space:]]+\d+,[[:space:]]+\d+)?/))
  issue = matcher[1]
  date = matcher[2]

  print "Issue (#{issue}): "
  STDOUT.flush
  input_issue = gets.chomp
  input_issue = issue if input_issue.empty?

  print "Date (#{date}): "
  STDOUT.flush
  input_date = gets.chomp
  input_date = date if input_date.empty?

  # convert input_date to YYYY-MM-DD format
  formatted_date = Date.parse(input_date).strftime("%Y-%m-%d")
else
  puts "Unable to detect issue number and date from HTML, please make sure that \#templateHeader is still the correct containing element."
  exit 1
end

file_name = "archive/_posts/#{formatted_date}-Issue-#{input_issue}.html"
if File.exists?(file_name)
  puts "File #{file_name}.md already exists."
  exit 1
end

print "Is #{file_name} correct? (y/n) "
STDOUT.flush

if gets.chomp.match(/y/i)
  File.open(file_name, "w") do |f|
    f.puts "---"
    f.puts "layout: archive"
    f.puts "title: Issue No. #{input_issue}"
    f.puts "---"
    f.puts
    f.puts body.to_html
  end

  system "bin/filter.rb"
else
  puts "Aborting."
  exit 1
end
