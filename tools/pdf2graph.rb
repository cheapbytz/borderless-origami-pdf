#!/usr/bin/env ruby 

=begin

= Author: 
  Guillaume Delugré <guillaume/at/security-labs.org>

= Info:
  Generates a Graphviz DOT or GraphML file out of a PDF document.

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
Usage: #{$0} <PDF-file> [-f <format>] [-o <output-file>]
Generates a Graphviz DOT file out of a PDF document.
Bug reports or feature requests at: http://origami-pdf.googlecode.com/

Options:
USAGE

  def self.parser(options)
    OptionParser.new do |opts|
      opts.banner = BANNER

      opts.on("-o", "--output FILE", "Output PDF file") do |o|
        options[:output] = o
      end

      opts.on("-f", "--format FORMAT", "File format for the generated graph, dot or graphml (Default: dot).") do |f|
        options[:format] = f
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
      :format => 'DOT'
    }

    self.parser(options).parse!(args)

    options
  end
end

begin
  @options = OptParser.parse(ARGV)

  if ARGV.empty?
    STDERR.puts "Error: No filename was specified. #{$0} --help for details."
    exit 1
  else
    target = ARGV.shift
  end

  unless ['DOT', 'GRAPHML'].include? @options[:format].upcase
    STDERR.puts "Error: Invalid format `#{format}'. #{0} --help for details."
  end

  if @options[:outfile].nil?
    @options[:outfile] = File.basename(target, '.pdf') +
      case @options[:format].upcase
        when 'DOT' then
          '.dot'
        when 'GRAPHML' then
          '.graphml'
      end
  end

  params = 
  {
    :verbosity => Parser::VERBOSE_QUIET,
  }

  pdf = PDF.read(target, params)
  case @options[:format].upcase
    when 'DOT' then
      pdf.export_to_graph(@options[:outfile])
    
    when 'GRAPHML' then
      pdf.export_to_graphml(@options[:outfile])
  end

rescue SystemExit
rescue Exception => e
  STDERR.puts "#{e.class}: #{e.message}"
  exit 1
end

