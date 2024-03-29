=begin

= File
	header.rb

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

module Origami
  
  class PDF

    class InvalidHeaderError < Exception #:nodoc:
    end

    #
    # Class representing a PDF Header.
    #
    class Header
    
      MINVERSION = 0
      MAXVERSION = 7

      MAGIC = /%PDF-(\d+)\.(\d+)/
    
      attr_accessor :majorversion, :minorversion
    
      #
      # Creates a file header, with the given major and minor versions.
      # _majorversion_:: Major PDF version, must be 1.
      # _minorversion_:: Minor PDF version, must be between 0 and 7.
      #
      def initialize(majorversion = 1, minorversion = 4)
      
        #if majorversion.to_i != 1 || ! ((MINVERSION..MAXVERSION) === minorversion.to_i)
        #  colorprint("[info ] Warning: Invalid file version : #{majorversion}.#{minorversion}\n", Colors::YELLOW, false, STDERR) 
        #end
      
        @majorversion, @minorversion = majorversion, minorversion
      end
    
      def self.parse(stream) #:nodoc:
      
        if not stream.scan(MAGIC).nil?
          maj = stream[1].to_i
          min = stream[2].to_i
        else
          raise InvalidHeaderError, "Invalid header format : #{stream.peek(15).inspect}"
        end
     
        PDF::Header.new(maj,min)
      end
    
      #
      # Outputs self into PDF code.
      #
      def to_s
        "%PDF-#{@majorversion}.#{@minorversion}" + EOL
      end
    
      def to_sym #:nodoc:
        "#{@majorversion}.#{@minorversion}".to_sym
      end
    
      def to_f #:nodoc:
        to_sym.to_s.to_f
      end
  
    end

  end
  
end
