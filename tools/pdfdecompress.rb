#!/usr/bin/env ruby

=begin

= Author: 
  Guillaume Delugré <guillaume/at/security-labs.org>

= Info:
  Uncompresses all binary streams of a PDF document.

= License:
	Origami is free software: you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Origami is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with Origami.  If not, see <http://www.gnu.org/licenses/>.

=end

begin
  require 'origami'
rescue LoadError
  ORIGAMIDIR = "#{File.dirname(__FILE__)}/.."
  $: << ORIGAMIDIR
  require 'origami'
end
include Origami

require 'optparse'

class OptParser
  BANNER = <<USAGE
Usage: #{$0} [<PDF-file>] [-p <password>] [-o <output-file>]
Uncompresses all binary streams of a PDF document.
Bug reports or feature requests at: http://origami-pdf.googlecode.com/

Options:
USAGE

  def self.parser(options)
    OptionParser.new do |opts|
      opts.banner = BANNER

      opts.on("-o", "--output FILE", "Output PDF file (stdout by default)") do |o|
        options[:output] = o
      end

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
  end

  def self.parse(args)
    options = 
    {
      :output => STDOUT,
    }

    self.parser(options).parse!(args)

    options
  end
end

begin
  @options = OptParser.parse(ARGV)

  target = (ARGV.empty?) ? STDIN : ARGV.shift
  params = 
  {
    :verbosity => Parser::VERBOSE_QUIET,
  }

  pdf = PDF.read(target, params)

  pdf.root_objects.find_all { |obj| 
    obj.is_a?(Stream)
  }.each { |stream|
    filters = stream.Filter
    filters = [ filters ] unless filters.is_a?(::Array)

    unless filters.any?{|filter| [ :JPXDecode, :DCTDecode, :JBIG2Decode ].include? filter}
      stream.rawdata = stream.data
      stream.dictionary.delete(:Filter)
    end
  }
  
  pdf.save(@options[:output], :noindent => true)

rescue SystemExit
rescue Exception => e
  STDERR.puts "#{e.class}: #{e.message}"
  exit 1
end

