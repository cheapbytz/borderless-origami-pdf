#!/usr/bin/env ruby

=begin

= Author: 
  Guillaume Delugré <guillaume/at/security-labs.org>

= Info:
  Prints out the metadata contained in a PDF document.

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
Usage: #{$0} [<PDF-file>] [-i] [-x]
Prints out the metadata contained in a PDF document.
Bug reports or feature requests at: http://origami-pdf.googlecode.com/

Options:
USAGE

  def self.parser(options)
    OptionParser.new do |opts|
      opts.banner = BANNER

      opts.on("-i", "Extracts document info metadata") do |i|
        options[:doc_info] = true
      end

      opts.on("-x", "Extracts XMP document metadata stream") do |i|
        options[:doc_stream] = true
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

  unless @options[:doc_info] or @options[:doc_stream]
    @options[:doc_info] = @options[:doc_stream] = true
  end

  target = (ARGV.empty?) ? STDIN : ARGV.shift
  params = 
  {
    :verbosity => Parser::VERBOSE_QUIET,
  }

  pdf = PDF.read(target, params)

  if @options[:doc_info]
    if pdf.has_document_info?
      colorprint "[*] Document information dictionary:\n", Colors::MAGENTA

      docinfo = pdf.get_document_info
      docinfo.each_pair do |name, item|
        puts "#{colorize(name.value.to_s.ljust(20,' '), Colors::GREEN)}: #{item.solve.value}"
      end
      puts
    end
  end

  if @options[:doc_stream]
    if pdf.has_metadata?
      colorprint "[*] Metadata stream:\n", Colors::MAGENTA

      metadata = pdf.get_metadata
      metadata.each_pair do |name, item|
        puts "#{colorize(name.ljust(20,' '), Colors::GREEN)}: #{item}"
      end
    end
  end

rescue SystemExit
rescue Exception => e
  STDERR.puts "#{e.class}: #{e.message}"
  exit 1
end

