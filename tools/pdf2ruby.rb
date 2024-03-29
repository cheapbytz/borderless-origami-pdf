#!/usr/bin/env ruby

=begin

= Info 
  Convert a PDF document to an Origami script.
  Experimental.

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

= Author
  Guillaume Delugré

=end

require 'optparse'
require 'ftools'
begin
  require 'origami'
rescue LoadError
  ORIGAMIDIR = "#{File.dirname(__FILE__)}/.."
  $: << ORIGAMIDIR
  require 'origami'
end
include Origami

@var_hash = {}
@code_hash = {}
@obj_route = []
@current_idx = nil

class OptParser
  def self.parse(args)
    options = {}
    options[:verbose] = 
    options[:xstreams] = false

    opts = OptionParser.new do |opts|
      opts.banner = <<BANNER
Usage: #{$0} [-v] [-x] <PDF-file>
Convert a PDF document to an Origami script (experimental).

Options:
BANNER
      
      opts.on("-v", "--verbose", "Verbose mode") do
        options[:verbose] = true
      end

      opts.on("-x", "--extract-streams", "Extract PDF streams to separate files") do
        options[:xstreams] = true
      end

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
    opts.parse!(args)

    options
  end
end

@options = OptParser.parse(ARGV)

if ARGV.empty?
  STDERR.puts "Error: No filename was specified. #{$0} --help for details."
  exit 1
else
  TARGET = ARGV.shift
end
      
TARGET_DIR = File.basename(TARGET, '.pdf')
TARGET_FILE = "#{TARGET_DIR}/#{TARGET_DIR}.rb"
STREAM_DIR = "streams"

def objectToRuby(obj, inclevel = 0, internalname = nil, do_convert = false)
  code = ""

  code <<
  case obj
    when Origami::Null
      "Null.new"
    when Origami::Boolean, Origami::Number
      obj.value.to_s
    when Origami::String
      "'#{obj.value.gsub("'","\\\\'")}'"
    when Origami::Dictionary
      customtype = nil
      if obj[:Type] and @@dict_special_types.include?(obj[:Type].value)
        customtype = @@dict_special_types[obj[:Type].value]
      end
      dictionaryToRuby(obj, inclevel, internalname, customtype)
    when Origami::Array
      arrayToRuby(obj, inclevel, internalname)
    when Origami::Stream
      streamToRuby(obj, internalname)
    when Origami::Name
      nameToRuby(obj)
    when Origami::Reference
      referenceToRuby(obj, internalname)
    else
      raise RuntimeError, "Unknown object type: #{obj.class}"
  end

  case obj
    when Origami::String, Origami::Dictionary, Origami::Array, Origami::Name
      code << ".to_o" if do_convert
  end

  code
end

def referenceToRuby(ref, internalname)
  varname = @var_hash[ref]

  if varname.nil?
    "nil"
  elsif @obj_route[0..@current_idx].include?(varname)
    @code_hash[varname] ||= {}
    @code_hash[varname][:afterDecl] ||= []
    @code_hash[varname][:afterDecl] << "#{internalname} = #{varname}"#.to_o.set_indirect(true)"

    "nil"
  else
    @obj_route.push(varname) unless @obj_route.include?(varname)
    varname
  end
end

def nameToRuby(name)
  code = ':'
  valid = (name.value.to_s =~ /[+.:-]/).nil?

  code << '"' unless valid
  code << name.value.to_s
  code << '"' unless valid

  code
end

def arrayToRuby(arr, inclevel, internalname)
  i = 0
  code = "\n" + "  " * inclevel + "["
  arr.each do |obj|
    subintname = "#{internalname}[#{i}]"
    
    code << "#{objectToRuby(obj, inclevel + 1, subintname)}"
    code << ", " unless i == arr.length - 1
    i = i + 1
  end
  code << "]"

  code
end

def dictionaryToRuby(dict, inclevel, internalname, customtype = nil)
  i = 0
  code = "\n" + "  " * inclevel
  
  if customtype
    code << "#{customtype}.new(#{dictionaryToHashMap(dict, inclevel, internalname)}"
    code << "  " * inclevel + ")"
  else
    code << "{\n"
    dict.each_pair do |key, val|
      rubyname = nameToRuby(key)
      subintname = "#{internalname}[#{rubyname}]"

      if val.is_a?(Origami::Reference) and @var_hash[val] and @var_hash[val][0,3] == "obj"
        oldname = @var_hash[val]
        newname = (key.value.to_s.downcase + "_" + @var_hash[val][4..-1]).gsub('.','_')

        if not @obj_route.include?(oldname)
          @var_hash[val] = newname
          @code_hash[newname] = @code_hash[oldname]
          @code_hash.delete(oldname)
        end
      end

      code << "  " * (inclevel + 1) + 
        "#{rubyname} => #{objectToRuby(val, inclevel + 2, subintname)}"
      code << ", " unless i == dict.length - 1
      
      i = i + 1
      code << "\n"
    end
    code << "  " * inclevel + "}"
  end

  code 
end

def dictionaryToHashMap(dict, inclevel, internalname)
  i = 0
  code = "\n"
  dict.each_pair do |key, val|
    rubyname = nameToRuby(key)
    subintname = "#{internalname}[#{rubyname}]"

    if val.is_a?(Origami::Reference) and @var_hash[val] and @var_hash[val][0,3] == "obj"
      oldname = @var_hash[val]
      newname = (key.value.to_s.downcase + "_" + @var_hash[val][4..-1]).gsub('.','_')

      if not @obj_route.include?(oldname)
        @var_hash[val] = newname
        @code_hash[newname] = @code_hash[oldname]
        @code_hash.delete(oldname)
      end
    end

    code << "  " * (inclevel + 1) + 
      "#{rubyname} => #{objectToRuby(val, inclevel + 2, subintname)}"
    code << ", " unless i == dict.length - 1
    i = i + 1
    code << "\n"
  end

  code 
end

def streamToRuby(stm, internalname)
  dict = stm.dictionary.dup.delete_if{|k,v| k == :Length or k == :Filter}

  code = "Stream.new("
  
  if @options[:xstreams]
    stmdir = "#{TARGET_DIR}/#{STREAM_DIR}"
    Dir::mkdir(stmdir) unless File.directory? stmdir
    stmfile = "#{stmdir}/stm_#{stm.reference.refno}.data"
    File.open(stmfile, "w") do |stmfd|
      stmfd.write stm.data
    end

    code << "File.read('#{STREAM_DIR}/stm_#{stm.reference.refno}.data')"
  else
    code << stm.data.inspect
  end
  
  code << ", #{dictionaryToHashMap(dict, 1, internalname)}" unless dict.empty?
  code << ")"
  if stm.dictionary.has_key? :Filter
    code << ".setFilter(#{objectToRuby(stm.Filter, 1, internalname)})" 
  end

  code
end

colorprint "[*] ", Colors::RED
puts "Loading document '#{TARGET}'"
verbosity = @options[:verbose] ? Parser::VERBOSE_INSANE : Parser::VERBOSE_QUIET
target = PDF.read(TARGET, :verbosity => verbosity)
colorprint "[*] ", Colors::RED
puts "Document successfully loaded into Origami"

Dir::mkdir(TARGET_DIR) unless File.directory? TARGET_DIR
fd = File.open(TARGET_FILE, 'w', 0700)

DOCREF = "pdf"
ORIGAMI_PATH = ORIGAMIDIR[0,1] == '/' ? 
  ORIGAMIDIR : 
  "../#{ORIGAMIDIR}"

fd.puts <<RUBY
#!/usr/bin/env ruby

begin
  require 'origami'
rescue LoadError
  ORIGAMIDIR = "#{ORIGAMI_PATH}"
  $: << ORIGAMIDIR
  require 'origami'
end
include Origami

OUTPUT = "\#{File.basename(__FILE__, '.rb')}.pdf"

#
# Creates the PDF object.
#
#{DOCREF} = PDF.new

RUBY

colorprint "[*] ", Colors::RED
puts "Retrieving all indirect objects..."
roots = target.root_objects
roots.each do |obj|
  varname = "obj_" + obj.no.to_s
  @var_hash[obj.reference] = varname
end

colorprint "[*] ", Colors::RED
puts "Retrieving the document Catalog..."
catalog = target.Catalog

@var_hash[catalog.reference] = "#{DOCREF}.Catalog"
@obj_route.push "#{DOCREF}.Catalog"

colorprint "[*] ", Colors::RED
puts "Processing the object hierarchy..."
@current_idx = 0
while @current_idx != @obj_route.size
  varname = @obj_route[@current_idx]
  obj = target[@var_hash.index(varname)]
  
  @code_hash[varname] ||= {}
  @code_hash[varname][:body] = objectToRuby(obj, 0, varname, true)

  @current_idx = @current_idx + 1
end

@obj_route.reverse.each do |varname|
  fd.puts "#{varname} = #{@code_hash[varname][:body]}"
  if @code_hash[varname][:afterDecl]
    @code_hash[varname][:afterDecl].each do |decl|
      fd.puts decl
    end
  end
  fd.puts
end

@obj_route.each do |varname|
  fd.puts "#{DOCREF}.insert(#{varname})" unless varname == "#{DOCREF}.Catalog"
end
fd.puts

fd.puts <<RUBY
#
# Saves the document.
#
#{DOCREF}.save(OUTPUT)

RUBY

colorprint "[*] ", Colors::RED
puts "Successfully generated script '#{TARGET_FILE}'"
fd.close
exit

