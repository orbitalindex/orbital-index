#!/usr/bin/env ruby

begin
  require 'nokogiri'
rescue LoadError
  puts "Run 'gem install nokogiri'"
  exit 1
end

def split_header(data)
  header, body = nil, nil
  if data =~ /\A\s*---/
    _, header, *rest = data.split('---')
    body = rest.join('---')
  else
    body = data
  end

  [header, body]
end

def process(data, force_header: nil, format_for_frontpage: false)
  header, body = split_header(data)

  doc = Nokogiri::HTML::DocumentFragment.parse(body)

  # Grab footer image for social media previews
  if !format_for_frontpage && header !~ /^image:/i
    image = doc.css("img.mcnImage").last
    image_url = image['src']
    header = header + "image: #{image_url}\n"
  end

  # Add 'highlight' class to tables because it bypasses our template's default formatting.
  doc.css("table").each do |node|
    node['class'] = (node['class'] || '') + ' highlight' unless (node['class'] || '') =~ /highlight/
  end

  # Set colors.
  doc.css("[style]").each do |node|
    node['style'] = node['style'].gsub(/#\w{6}/) { |m|
      case m
      when '#ffffff','#fafafa'
        'var(--body-bg)'
      when '#5f5f5f'
        'var(--gray-text)'
      when '#202020'
        'var(--body-color)'
      when '#2f767f'
        'var(--mc-link-color)'
      else
        m
      end
    }
  end

  # Links should open in a new tab.
  doc.css("a").each do |node|
    node['target'] = "_blank"
  end

  # Guest contribution text blocks should have white backgrounds.
  doc.css("table.mcnBoxedTextContentContainer.highlight td.mcnTextContent").each do |node|
    if node['style'] !~ /background-color: white/
      node['style'] = (node['style'] || '') + '; background-color: white;'
      puts "  Adding white background to guest contribution header"
    end
  end

  # Sponsored icon section
  doc.css('[style*="border: 5px double"]').each do |possible_sponsor_block|
    if possible_sponsor_block.text =~ /made possible|generous|sponsor/i
      # possible_sponsor_block.remove

      if possible_sponsor_block['style'] !~ /background-color: white/
        possible_sponsor_block['style'] = (possible_sponsor_block['style'] || '') + '; background-color: white;'
        puts "  Adding white background to sponsor block"
      end
      possible_sponsor_block.css('a').each do |logo|
        if logo['style'] !~ /inline-block/
          logo['style'] = (logo['style'] || '') + '; display: inline-block;'
          puts "  Centering sponsor logo"
        end
      end
    end
  end

  # Strong areas are section titles and should have internal anchors for linking to them.
  doc.css("a.para").each(&:remove)

  doc.css("td.mcnTextContent > strong:nth-child(1), td.mcnTextContent > p:not([style*=center]) > strong:nth-child(1)").each do |node|
    if node.content !~ /[\w\d]+/
      node.remove
    end
  end

  doc.css("td.mcnTextContent > strong:nth-child(1), td.mcnTextContent > p:not([style*=center]) > strong:nth-child(1)").each do |node|
    id = node.content.downcase.gsub(/[^a-z0-9-]+/, '-').gsub(/^-|-$/, '')
    if id.length > 1 && id !~ /support-us/
      node["id"] = id

      anchor_link = "<a href=\"##{id}\" style=\"position: absolute; left: -20px; color: var(--menu-text); text-decoration: none;\" class=\"para\">&para;</a>"

      if !node.parent[:style] || node.parent[:style] !~ /position: relative/
        node.parent[:style] = [node.parent[:style], "position: relative;"].compact.join(";").squeeze(";")
      end

      unless format_for_frontpage
        node.add_previous_sibling(anchor_link)
      end
    end
  end

  # Remove any footer and old subscribe regions.
  doc.css('#templateFooter, #subscribe-footer').each(&:remove)

  # Hr tags should not have huge spacing.
  doc.css('hr').each do |node|
    if node['style'] !~ /margin:/
      node['style'] = (node['style'] || '') + '; margin: 12px 0 10px 0;'
      puts "  Adding margin to HR tag"
    end
  end

  if format_for_frontpage
    # Remove the email header text, if any.
    doc.css('#templatePreheader').each(&:remove)
  end

  if force_header || header
    '---' + (force_header || header) + '---' + doc.to_html
  else
    doc.to_html
  end
end

# Update the archive

greatest_issue_number, greatest_issue_file = -1, nil
files = Dir['archive/_posts/*.html']
files.each do |file|
  issue_number = file[/Issue-(\d+)/, 1].to_i
  puts "Processing #{file} (#{issue_number})"
  processed = process(File.read(file))
  File.open(file, 'w') do |file|
    file.print processed
  end

  if issue_number > greatest_issue_number
    greatest_issue_number = issue_number
    greatest_issue_file = file
  end
end

# Update the latest post on the frontpage
existing_header, _ = split_header(File.read('index.md'))
File.open('index.md', 'w') do |file|
  file.print process(File.read(greatest_issue_file), force_header: existing_header, format_for_frontpage: true)
end
