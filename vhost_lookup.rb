#!/usr/bin/env ruby
['terminal-table', 'net/http', 'getopt/std'].each(&method(:require))

#################################################################
#                                                               #
# This ruby script simply uses Bing to grab domains which may   #
# be associated with a VirtualHost. This is extremely useful if #
# you have a single IP address and it answers for several       #
# domains. For further reference, research Apache VirtualHosts. #
#                                                               #
#################################################################

class VHostLookup
  def initialize(ipaddr, pages)
    @ipaddr = ipaddr
    @pages = pages
    @domains = []
  end

  # Submit the bing request and obtain all domains associated with IP.
  def begin
    cookies = ''
    url = URI("http://www.bing.com/search?q=ip:#{@ipaddr}")
    res = Net::HTTP.get_response(url)
    res.get_fields('set-cookie').each {|cookie| cookies << cookie.split('; ')[0] + '; '}

    http = Net::HTTP.new(url.host, url.port)
    headers = {
      'Cookie' => cookies
    }
    resp = http.get(url.request_uri, headers)
    parse_body(resp.body.scan(/<cite>(.*?)<\/cite>/))
  end
  
  def parse_body(domains)
    puts " [*] #{domains.length} domain(s) identified. Parsing results."
    domains.each {|domain|
      @domains << domain[0].gsub("<strong>","").gsub("</strong>","").gsub("https://", "").split("/")[0]
    }
    lookup_additional_ips
  end

  def lookup_additional_ips
    puts ' [*] Results parsed. Performing additional IP lookups on each domain.'
    @domain_matchings = []
    @domains.each do |domain|
      output = `dig @8.8.8.8 A #{domain}`.split("\n")
      hash = Hash[output.map.with_index.to_a]
      if output.include? ';; ANSWER SECTION:'
        results = output[hash[';; ANSWER SECTION:']+1..-6]
        results.each do |result|
          result = result.split("\t")
          a = result[0].split(" ")[0][0..-2]
          b = result[-2].split(" ")[-1] # DNS record.
          c = result[-1] # DNS entry.
          @domain_matchings << [domain, a, b, c]
        end
      end
    end
    stdout
  end

  def stdout
    puts " [*] Complete! Printing table.\n\n"
    table = Terminal::Table.new do |t|
      t << ['Query','Additional DNS Name','DNS Record Type','DNS Entry']
      t.add_separator
      @domain_matchings.each do |entry|
        t << entry
      end
    end
    puts table
  end
end

def help_menu
  puts %Q{
 ---------------------------------------------------
  VHost Lookup - Alton Johnson (alton.jx@gmail.com)
 ---------------------------------------------------

 Usage: #{$0} -i 199.83.134.95

 \t-i\tIP address to look up other domains (virtualhosts) for.
  }
  exit
end

# Begin things.
if $0 == __FILE__
  if ARGV.length == 0
    help_menu
  end

  opt = Getopt::Std.getopts("i:")
  fail "You forgot to provide an IP address." unless opt['i']
  s = VHostLookup.new(opt['i'], 5)
  s.begin
end
