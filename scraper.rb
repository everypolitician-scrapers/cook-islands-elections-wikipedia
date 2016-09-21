#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_term(t)
  noko = noko_for(t[:source])
  section = noko.xpath('.//h3/span[@class="mw-headline" and contains(.,"%s")]' % t[:headline])
  section.xpath('.//following::table[.//th[contains(.,"Candidate")]]').each do |table|
    constituency = table.css('caption').first.text[/#{t[:year]}: (.*)/, 1]
    winner = table.xpath('.//tr[td]').map do |tr|
      tds = tr.css('td')
      next if tds.any? { |td| td.attr('colspan') }
      data = {
        name: tds[2].text.tidy,
        wikiname: tds[2].xpath('.//a[not(@class="new")]/@title').text,
        party: tds[1].text.tidy,
        constituency: constituency,
        votes: tds[3].text.to_i,
        term: t[:term],
      }
      # https://en.wikipedia.org/wiki/Mitiaro_by-election_2014
      data[:votes] -= 1 if t[:term] == '14' && data[:name] == 'Tuakeu Tangatapoto'
      data
    end.compact.sort_by { |d| d[:votes] }.reverse.first
    ScraperWiki.save_sqlite([:name, :term, :constituency], winner)
  end
end

terms = [
  {
    term: 14,
    year: 2014,
    headline: 'By constituency',
    source: 'https://en.wikipedia.org/wiki/Cook_Islands_general_election,_2014'
  },
  {
    term: 13,
    year: 2010,
    headline: 'Electorate Results',
    source: 'https://en.wikipedia.org/wiki/Cook_Islands_general_election,_2010'
  },
  {
    term: 12,
    year: 2006,
    headline: 'Electorate Results',
    source: 'https://en.wikipedia.org/wiki/Cook_Islands_general_election,_2006'
  }
]

terms.each { |t| scrape_term(t) }
