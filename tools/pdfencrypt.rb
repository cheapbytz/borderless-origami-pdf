#!/usr/bin/env ruby 

=begin

= Author: 
  Guillaume Delugré <guillaume/at/security-labs.org>

= Info:
  Encrypts a PDF document.

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
Usage: #{$0} [<PDF-file>] [-p <password>] [-c <cipher>] [-s <key-size>] [-o <output-file>]
Encrypts a PDF document. Supports RC4 40 to 128 bits, AES128, AES256.
Bug reports or feature requests at: http://origami-pdf.googlecode.com/

Options:
USAGE

  def self.parser(options)
    OptionParser.new do |opts|
      opts.banner = BANNER

      opts.on("-o", "--output FILE", "Output PDF file (stdout by default)") do |o|
        options[:output] = o
      end

      opts.on("-p", "--password PASSWORD", "Password of the document") do |p|
        options[:password] = p
      end

      opts.on("-c", "--cipher CIPHER", "Cipher used to encrypt the document (Default: AES)") do |c|
        options[:cipher] = c
      end

      opts.on("-s", "--key-size KEYSIZE", "Key size in bits (Default: 128)") do |s|
        options[:key_size] = s.to_i
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
      :password => '',
      :cipher => 'aes',
      :key_size => 128
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
  pdf.encrypt(
    :user_password  => @options[:password], 
    :owner_password => @options[:password], 
    :cipher         => @options[:cipher], 
    :key_size       => @options[:key_size]
  )
  pdf.save(@options[:output], :noindent => true)

rescue SystemExit
rescue Exception => e
  STDERR.puts "#{e.class}: #{e.message}"
  exit 1
end

