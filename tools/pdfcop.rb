#!/usr/bin/env ruby

=begin

= Author: 
  Guillaume Delugré <guillaume/at/security-labs.org>

= Info:
  This is a PDF document filtering engine using Origami.
  Security policies are based on a white list of PDF features.
  Default policies details can be found in the default configuration file.
  You can also add your own policy and activate it using the -p switch.

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
require 'yaml'
require 'rexml/document'
require 'digest/md5'

DEFAULT_CONFIG_FILE = 'config/pdfcop.conf.yaml'
DEFAULT_POLICY = "standard"
SECURITY_POLICIES = {}

def load_config_file(path)
  SECURITY_POLICIES.update(Hash.new(false).update YAML.load(File.read(path)))
end

class OptParser
  BANNER = <<USAGE
Usage: #{$0} [options] <PDF-file>
The PDF filtering engine. Scans PDF documents for malicious structures.
Bug reports or feature requests at: http://origami-pdf.googlecode.com/

Options:
USAGE

  def self.parse(args)
    options = {:colors => true}

    opts = OptionParser.new do |opts|
      opts.banner = BANNER

      opts.on("-o", "--output LOG_FILE", "Output log file (default STDOUT)") do |o|
        options[:output_log] = o
      end

      opts.on("-c", "--config CONFIG_FILE", "Load security policies from given configuration file") do |cf|
        options[:config_file] = cf
      end

      opts.on("-p", "--policy POLICY_NAME", "Specify applied policy. Predefined policies: 'none', 'standard', 'strong', 'paranoid'") do |p|
        options[:policy] = p
      end

      opts.on("-n", "--no-color", "Suppress colored output") do
        options[:colors] = false
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
if @options.has_key?(:output_log)
  LOGGER = File.open(@options[:output_log], "a+")
else
  LOGGER = STDOUT
end

if not @options.has_key?(:policy)
  @options[:policy] = DEFAULT_POLICY
end

load_config_file(@options[:config_file] || DEFAULT_CONFIG_FILE)
unless SECURITY_POLICIES.has_key?("POLICY_#{@options[:policy].upcase}")
  STDERR.puts "Undeclared policy `#{@options[:policy]}'"
  exit(1)
end

if ARGV.empty?
  STDERR.puts "Error: No filename was specified. #{$0} --help for details."
  exit 1
else
  TARGET = ARGV.shift 
end

def log(str, color = Colors::GREY)
  if @options[:colors]
    colorprint("[#{Time.now}] ", Colors::CYAN, LOGGER)
    colorprint(str, color, LOGGER)
  else
    LOGGER.print("[#{Time.now}] #{str}")
  end

  LOGGER.puts
end

def reject(cause)
  log("Document rejected by policy `#{@options[:policy]}', caused by #{cause.inspect}.", Colors::RED)
  exit(1)
end

def check_rights(*required_rights)
  current_rights = SECURITY_POLICIES["POLICY_#{@options[:policy].upcase}"]

  reject(required_rights) if required_rights.any?{|right| current_rights[right.to_s] == false}
end

def analyze_xfa_forms(xfa)
  case xfa
    when Array then
      xml = ""
      i = 0
      xfa.each do |packet|
        if i % 2 == 1
          xml << packet.solve.data
        end

        i = i + 1
      end
    when Stream then
      xml = xfa.data
    else
      reject("Malformed XFA dictionary")
  end

  xfadoc = REXML::Document.new(xml)
  REXML::XPath.match(xfadoc, "//script").each do |script|
    case script.attributes["contentType"]
      when "application/x-formcalc" then
        check_rights(:allowFormCalc)
      else
        check_rights(:allowJS)
    end
  end
end

def analyze_annotation(annot, level = 0)
  check_rights(:allowAnnotations) 
  
  if annot.is_a?(Dictionary) and annot.has_key?(:Subtype)
    case annot[:Subtype].solve.value
      when :FileAttachment then 
        check_rights(:allowAttachments, :allowFileAttachmentAnnotation)

      when :Sound then 
        check_rights(:allowSoundAnnotation)
      
      when :Movie then 
        check_rights(:allowMovieAnnotation)
      
      when :Screen then 
        check_rights(:allowScreenAnnotation)

      when :Widget then
        check_rights(:allowAcroforms)
      
      when :"3D" then 
        check_rights(:allow3DAnnotation)

        # 3D annotation might pull in JavaScript for real-time driven behavior.
        if annot.has_key?(:"3DD")
          dd = annot[:"3DD"].solve
          u3dstream = nil

          case dd
            when Stream then
              u3dstream = dd
            when Dictionary then
              u3dstream = dd[:"3DD"]
          end

          if u3dstream and u3dstream.has_field?(:OnInstantiate)
            check_rights(:allowJS)
            
            if annot.has_key?(:"3DA") # is 3d view instantiated automatically?
              u3dactiv = annot[:"3DA"].solve
              
              check_rights(:allowJSAtOpening) if u3dactiv.is_a?(Dictionary) and (u3dactiv[:A] == :PO or u3dactiv[:A] == :PV)
            end
          end
        end

      when :RichMedia then 
        check_rights(:allowRichMediaAnnotation)
    end
  end
end

def analyze_page(page, level = 0)
  section_prefix = " " * 2 * level + ">" * (level + 1)
  log(section_prefix + " Inspecting page...") 

  text_prefix = " " * 2 * (level + 1) + "." * (level + 1)
  if page.is_a?(Dictionary)
    
    #
    # Checking page additional actions.
    #
    if page.has_key?(:AA)
      if page.AA.is_a?(Dictionary)
        log(text_prefix + " Page has an action dictionary.")
        
        aa = PageAdditionalActions.new(page.AA); aa.parent = page.AA.parent
        analyze_action(aa.O, true, level + 1) if aa.has_key?(:O)
        analyze_action(aa.C, false, level + 1) if aa.has_key?(:C)
      end
    end

    #
    # Looking for page annotations.
    #
    page.each_annot do |annot|
      analyze_annotation(annot, level + 1)
    end
  end
end

def analyze_action(action, triggered_at_opening, level = 0)
  section_prefix = " " * 2 * level + ">" * (level + 1)
  log(section_prefix + " Inspecting action...") 
  
  text_prefix = " " * 2 * (level + 1) + "." * (level + 1)
  if action.is_a?(Dictionary)
    log(text_prefix + " Found #{action[:S]} action.")
    type = action[:S].is_a?(Reference) ? action[:S].solve : action[:S]

    case type.value
      when :JavaScript
        check_rights(:allowJS)
        check_rights(:allowJSAtOpening) if triggered_at_opening

      when :Launch
        check_rights(:allowLaunchAction)

      when :Named
        check_rights(:allowNamedAction)

      when :GoTo
        check_rights(:allowGoToAction)
        dest = action[:D].is_a?(Reference) ? action[:D].solve : action[:D]
        if dest.is_a?(Array) and dest.length > 0 and dest.first.is_a?(Reference)
          dest_page = dest.first.solve
          if dest_page.is_a?(Page)
            log(text_prefix + " Destination page found.")
            analyze_page(dest_page, level + 1)
          end
        end

      when :GoToE
        check_rights(:allowAttachments,:allowGoToEAction) 
      
      when :GoToR
        check_rights(:allowGoToRAction)

      when :Thread
        check_rights(:allowGoToRAction) if action.has_key?(:F)

      when :URI
        check_rights(:allowURIAction)

      when :SubmitForm
        check_rights(:allowAcroForms,:allowSubmitFormAction)

      when :ImportData
        check_rights(:allowAcroForms,:allowImportDataAction)

      when :Rendition
        check_rights(:allowScreenAnnotation,:allowRenditionAction)

      when :Sound
        check_rights(:allowSoundAnnotation,:allowSoundAction)

      when :Movie
        check_rights(:allowMovieAnnotation,:allowMovieAction)

      when :RichMediaExecute
        check_rights(:allowRichMediaAnnotation,:allowRichMediaAction)

      when :GoTo3DView
        check_rights(:allow3DAnnotation,:allowGoTo3DAction)
    end

    if action.has_key?(:Next)
      log(text_prefix + "This action is chained to another action!")
      check_rights(:allowChainedActions)
      analyze_action(action.Next)
    end
  elsif action.is_a?(Array)
    dest = action
    if dest.length > 0 and dest.first.is_a?(Reference)
      dest_page = dest.first.solve
      if dest_page.is_a?(Page)
        log(text_prefix + " Destination page found.")
        check_rights(:allowGoToAction)
        analyze_page(dest_page, level + 1)
      end
    end
  end
end

begin
  log("PDFcop is running on target `#{TARGET}', policy = `#{@options[:policy]}'", Colors::GREEN)
  log("  File size: #{File.size(TARGET)} bytes", Colors::MAGENTA)
  log("  MD5: #{Digest::MD5.hexdigest(File.read(TARGET))}", Colors::MAGENTA)
 
  @pdf = PDF.read(TARGET,
    :verbosity => Parser::VERBOSE_QUIET, 
    :ignore_errors => SECURITY_POLICIES["POLICY_#{@options[:policy].upcase}"]['allowParserErrors']
  )

  log("> Inspecting document structure...", Colors::YELLOW)
  if @pdf.is_encrypted?
    log("  . Encryption = YES")
    check_rights(:allowEncryption)
  end

  log("> Inspecting document catalog...", Colors::YELLOW)
  catalog = @pdf.Catalog
  reject("Invalid document catalog") unless catalog.is_a?(Catalog)

  if catalog.has_key?(:OpenAction)
    log("  . OpenAction entry = YES")
    check_rights(:allowOpenAction)
    action = catalog.OpenAction
    analyze_action(action, true, 1) 
  end

  if catalog.has_key?(:AA)
    if catalog.AA.is_a?(Dictionary)
      aa = CatalogAdditionalActions.new(catalog.AA); aa.parent = catalog;
      log("  . Additional actions dictionary = YES")
      analyze_action(aa.WC, false, 1) if aa.has_key?(:WC)
      analyze_action(aa.WS, false, 1) if aa.has_key?(:WS)
      analyze_action(aa.DS, false, 1) if aa.has_key?(:DS)
      analyze_action(aa.WP, false, 1) if aa.has_key?(:WP)
      analyze_action(aa.DP, false, 1) if aa.has_key?(:DP)
    end
  end

  if catalog.has_key?(:AcroForm)
    acroform = catalog.AcroForm
    if acroform.is_a?(Dictionary)
      log("  . AcroForm = YES")
      check_rights(:allowAcroForms)
      if acroform.has_key?(:XFA)
        log("  . XFA = YES")
        check_rights(:allowXFAForms)

        analyze_xfa_forms(acroform[:XFA].solve)
      end
    end
  end

  log("> Inspecting JavaScript names directory...", Colors::YELLOW)
  unless @pdf.ls_names(Names::Root::JAVASCRIPT).empty?
    check_rights(:allowJS)
    check_rights(:allowJSAtOpening)
  end

  log("> Inspecting attachment names directory...", Colors::YELLOW)
  unless @pdf.ls_names(Names::Root::EMBEDDEDFILES).empty?
    check_rights(:allowAttachments)
  end

  log("> Inspecting document pages...", Colors::YELLOW)
  @pdf.each_page do |page|
    analyze_page(page, 1)
  end

  log("> Inspecting document streams...", Colors::YELLOW)
  @pdf.indirect_objects.find_all{|obj| obj.is_a?(Stream)}.each do |stream|
    if stream.dictionary.has_key?(:Filter)
      filters = stream.Filter
      filters = [ filters ] if filters.is_a?(Name)

      if filters.is_a?(Array) 
        filters.each do |filter|
          case filter.value
            when :ASCIIHexDecode
              check_rights(:allowASCIIHexFilter)
            when :ASCII85Decode
              check_rights(:allowASCII85Filter)
            when :LZWDecode
              check_rights(:allowLZWFilter)
            when :FlateDecode
              check_rights(:allowFlateDecode)
            when :RunLengthDecode
              check_rights(:allowRunLengthFilter)
            when :CCITTFaxDecode
              check_rights(:allowCCITTFaxFilter)
            when :JBIG2Decode
              check_rights(:allowJBIG2Filter)
            when :DCTDecode
              check_rights(:allowDCTFilter)
            when :JPXDecode
              check_rights(:allowJPXFilter)
            when :Crypt
              check_rights(:allowCryptFilter)
          end 
        end
      end
    end
  end

  #
  # TODO: Detect JS at opening in XFA (check event tag)
  #       Check image encoding in XFA ?
  #       Only allow valid signed documents ?
  #       Recursively scan attached files.
  #       On-the-fly injection of prerun JS code to hook vulnerable methods (dynamic exploit detection) ???
  #       ...
  #

  log("Document accepted by policy `#{@options[:policy]}'.", Colors::GREEN)

rescue SystemExit
rescue Exception => e
  log("An error occured during analysis : #{e.class} (#{e.message})")
  reject("Analysis failure")
ensure
  LOGGER.close
end

