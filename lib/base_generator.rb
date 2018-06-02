require 'stringio'

module Assembler

  class MeritDocument
    
    def gen_folder(folder)
      @gen_folder = folder

      # Initialization that cannot be done in initialize
      @buffer = StringIO.new
    end

    def all_labelled_elements
      @merits.map { |m| [m] + m.docs + m.items }.flatten
    end

    def all_ordered_merits
      @merits.map { |m| [m] + m.items }.flatten
    end

    def section_merits
      @merits
    end
    
    def println(str)
      @buffer << str + $/
    end

    def clean
      @buffer = StringIO.new
    end

    def dump(file)
      File.open(File.join(@gen_folder, file), "w") do |f|
        f.write( @buffer.string )
      end
    end

  end
end
