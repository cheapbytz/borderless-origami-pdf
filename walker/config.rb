=begin

= File
	config.rb

= Info
	This file is part of Origami, PDF manipulation framework for Ruby
	Copyright (C) 2010	Guillaume Delugr� <guillaume@security-labs.org>
	All right reserved.
	
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

require 'yaml'

module PDFWalker
  
  class Walker < Window
    
    class Config
      
      DEFAULT_CONFIG = 
      { 
        "Debug" => {"Profiling" => false, "ProfilingOutputDir" => "prof", "Verbosity" => Parser::VERBOSE_INSANE, "IgnoreFileHeader" => true}, 
        "UI" => { "LastOpenedDocuments" => [] } 
      }
      
      NLOG_RECENT_FILES = 5
      
      def initialize(configfile = "#{File.dirname($0)}/walker.conf")
        
        begin
          @conf = YAML.load(File.open(configfile)) or DEFAULT_CONFIG
        rescue Exception
        ensure 
          @filename = configfile
          set_missing_values
        end
        
      end
      
      def last_opened_file(filepath)
        
        @conf["UI"]['LastOpenedDocuments'].push(filepath).uniq!
        @conf["UI"]['LastOpenedDocuments'].delete_at(0) while @conf["UI"]['LastOpenedDocuments'].size > NLOG_RECENT_FILES
        
        save
        
      end
      
      def recent_files(n = NLOG_RECENT_FILES)
        
        @conf["UI"]['LastOpenedDocuments'].last(n).reverse
        
      end
      
      def set_profiling(bool)
        
        @conf["Debug"]['Profiling'] = bool
        save
      
      end
      
      def profile?
        @conf["Debug"]['Profiling']
      end

      def profile_output_dir
        @conf["Debug"]['ProfilingOutputDir']
      end
      
      def set_ignore_header(bool)
        
        @conf["Debug"]['IgnoreFileHeader'] = bool
        save
        
      end
      
      def ignore_header?
        @conf["Debug"]['IgnoreFileHeader']
      end
      
      def set_verbosity(level)
        
        @conf["Debug"]['Verbosity'] = level
        save
        
      end
      
      def verbosity
        
        @conf["Debug"]['Verbosity']
        
      end
      
      def save
        
        File.open(@filename, "w").write(@conf.to_yaml)
        
      end
      
      private
      
      def set_missing_values
        
        @conf ||= {}
        
        DEFAULT_CONFIG.each_key { |cat|
          
          @conf[cat] = {} unless @conf.include?(cat)
          
          DEFAULT_CONFIG[cat].each_pair { |key, value|
            @conf[cat][key] = value unless @conf[cat].include?(key)
          }
        }
        
      end
    
    end
    
  end
  
end
