#!/usr/bin/env ruby

require "json"
require "nokogiri"
require "pathname"
require "uri"

root = Pathname.new(__dir__).parent.expand_path
html_files = Dir[root.join("**/*.html")].sort.map { |path| Pathname.new(path) }
errors = []
canonicals = {}
descriptions = {}

def local_target(root, value)
  path = value.split(/[?#]/, 2).first
  return nil unless path.start_with?("/")
  return root.join("index.html") if path == "/"

  relative = path.delete_prefix("/")
  candidate = root.join(relative)
  path.end_with?("/") ? candidate.join("index.html") : candidate
end

html_files.each do |file|
  relative = file.relative_path_from(root).to_s
  document = Nokogiri::HTML5.parse(file.read)
  is_404 = relative == "404.html"

  parse_errors = document.errors.reject { |error| error.message.include?("htmlParseEntityRef") }
  parse_errors.each { |error| errors << "#{relative}: #{error.message.strip}" }

  titles = document.css("head > title")
  errors << "#{relative}: expected one non-empty title" unless titles.length == 1 && !titles.first.text.strip.empty?

  headings = document.css("h1")
  errors << "#{relative}: expected exactly one h1, found #{headings.length}" unless headings.length == 1

  ids = document.css("[id]").map { |node| node["id"] }
  ids.group_by(&:itself).select { |_id, group| group.length > 1 }.each_key do |id|
    errors << "#{relative}: duplicate id ##{id}"
  end

  if is_404
    robots = document.at_css('meta[name="robots"]')&.[]("content").to_s
    errors << "#{relative}: missing noindex directive" unless robots.downcase.include?("noindex")
  else
    description = document.at_css('meta[name="description"]')&.[]("content").to_s.strip
    errors << "#{relative}: missing meta description" if description.empty?
    if descriptions.key?(description)
      errors << "#{relative}: duplicate meta description also used by #{descriptions[description]}"
    else
      descriptions[description] = relative
    end

    canonical_nodes = document.css('link[rel="canonical"]')
    canonical = canonical_nodes.first&.[]("href").to_s
    errors << "#{relative}: expected one HTTPS canonical" unless canonical_nodes.length == 1 && canonical.start_with?("https://www.nocturnaldevs.com/")
    if canonicals.key?(canonical)
      errors << "#{relative}: duplicate canonical also used by #{canonicals[canonical]}"
    else
      canonicals[canonical] = relative
    end

    %w[og:title og:description og:url og:image].each do |property|
      errors << "#{relative}: missing #{property}" unless document.at_css(%(meta[property="#{property}"]))
    end
    errors << "#{relative}: missing Twitter card metadata" unless document.at_css('meta[name="twitter:card"]')
  end

  document.css('script[type="application/ld+json"]').each_with_index do |script, index|
    begin
      JSON.parse(script.text)
    rescue JSON::ParserError => error
      errors << "#{relative}: invalid JSON-LD block #{index + 1}: #{error.message}"
    end
  end

  document.css("img").each do |image|
    errors << "#{relative}: image missing alt (#{image['src']})" if image["alt"].nil?
    errors << "#{relative}: image missing width/height (#{image['src']})" unless image["width"] && image["height"]
  end

  document.css("a[href], link[href], script[src], img[src]").each do |node|
    value = node["href"] || node["src"]
    target = local_target(root, value)
    next unless target
    errors << "#{relative}: missing local target #{value}" unless target.exist?
  end
end

sitemap = Nokogiri::XML(root.join("sitemap.xml").read) { |config| config.strict }
sitemap.remove_namespaces!
sitemap_urls = sitemap.css("url > loc").map(&:text)
expected_urls = canonicals.keys.sort
errors << "sitemap.xml: URL set does not match canonical pages" unless sitemap_urls.sort == expected_urls

if errors.empty?
  puts "Validated #{html_files.length} HTML pages, #{canonicals.length} canonical URLs, JSON-LD, local assets, and sitemap coverage."
  exit 0
end

warn errors.join("\n")
exit 1
