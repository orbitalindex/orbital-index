#!/usr/bin/env ruby

# Load .env for the TOKEN variable

begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  raise "Run 'bundle'"
end

token = ENV['AIRTABLE_TOKEN'] || raise("Missing AIRTABLE_TOKEN, did you create a .env file?")

require 'json'
require 'net/http'
require 'uri'

url = URI("https://api.airtable.com/v0/appjhx74xRL9xFMjy/Subscribers?maxRecords=1000&view=Grid%20view")

http = Net::HTTP.new(url.host, url.port)
http.use_ssl = true
request = Net::HTTP::Get.new(url)
request["Authorization"] = "Bearer #{token}"

response = http.request(request)
# puts JSON.pretty_generate(JSON.parse(response.read_body))

# {
#   "records": [
#     {
#       "id": "rech72ZIAlt7uEBS0",
#       "createdTime": "2023-07-27T07:04:14.000Z",
#       "fields": {
#         "Public": true,
#         "Name": "Bob Smith",
#         "Monthly": true,
#         "Email": "bob@example.com",
#         "Wants to be on website?": true,
#         "Have we reached out?": true,
#         "Mention name": "Bob",
#         "Last Update": "2023-07-27T08:39:00.000Z",
#         "Total": 10
#       }
#     },
#     ...

# Collect all the subscribers who have a field matching /Wants to be on website?/ and /Have we reached out?/ and add their /Mention name/s to an array.

records = JSON.parse(response.read_body)['records']
subscribers = records.select do |record|
  record['fields']['Wants to be on website?'] && record['fields']['Have we reached out?']
end

names = subscribers.map do |subscriber|
  subscriber['fields']['Mention name'] || subscriber['fields']['Name']
end

if names.empty?
  raise "No subscribers found, did field names change?"
end

# Open supporters.html and replace everything between /<!-- auto generated supporter list start -->/ and /<!-- auto generated supporter list end -->/ with the contents of the names array

supporters = File.read('supporters.html')
supporters.gsub!(/<!-- auto generated supporter list start -->.*<!-- auto generated supporter list end -->/m, "<!-- auto generated supporter list start -->\n#{names.map {|name| "<li>#{name}</li>"}.join("\n")}\n<!-- auto generated supporter list end -->")
File.write('supporters.html', supporters)

puts "Updated supporters.html now contains #{names.count} names."
