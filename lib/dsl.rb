

module Assembler
  class MeritDocument
    attr_accessor :root_dir
    attr_reader :merits
    attr_reader :categories
    attr_accessor :fullname, :title, :subtitle
    
    def initialize
      @merits = []
      @categories = []
    end
  end
  
  class Merit
    attr_accessor :longname
    attr_reader :category
    attr_reader :items
    attr_reader :docs
    attr_reader :used_doc
    
    def initialize(name)
      @name = name
      @included = []
      @items = []
      @docs = []
    end

    def check
      if @longname.nil?
        raise "Expected name for merit #{@name}"
      end
    end
    
    # Returns a latex normalized name
    def name
      @name.to_s.gsub(' ', '')
    end

    def category=(c)
      @category = c
      @items.each { |i| i.category = c }
    end
    
    def include_jpg(filename, options)
      @included << JPG.new(filename, options)
    end

    def include_pdf(filename, options)
      @included << PDF.new(filename, options)
    end

    def add_item(item)
      @items << item
    end

    def add_doc_definition(doc)
      @docs << doc
    end

    def find_doc(name)
      name = name.intern
      d = @docs.find { |d| d.name == name }
      raise "Document #{name} not found" unless d
      d
    end
    
    def use_referenced_doc(doc)
      @used_doc = doc
    end
    
  end

  class DocDefinition
    attr_reader :name
    attr_reader :external_file

    # external_file is an IncludedFile object
    def initialize(name, external_file)
      @name = name.intern
      @external_file = external_file
    end

    
  end
  
  class Item < Merit
    attr_reader :parent
    
    def initialize(parent, str)
      super(str)
      @parent = parent
      @category = parent.category
    end
  end
  
  class IncludedFile
    def initialize(filename, options)
      @filename = filename
      @options  = options
    end
  end

  class JPG < IncludedFile
  end

  class PDF < IncludedFile
  end

  class Category
    attr_reader :name
    attr_accessor :description
    attr_accessor :short_description
    attr_accessor :folder

    def initialize(name)
      @name = name
    end    
    
    def short_descriptive_name
      self.short_description ||
        self.description || 
        self.name.to_s
    end

    def long_descriptive_name
      self.description || 
      self.short_description ||
        self.name.to_s
    end


  end

  module DSL
    class Root
      attr_reader :doc

      def initialize
        @doc = MeritDocument.new
      end

      def root_dir(dir)
        @doc.root_dir = dir
      end

      def fullname(name)
        @doc.fullname = name
      end

      def title(title)
        @doc.title = title
      end

      def subtitle(subtitle)
        @doc.subtitle = subtitle
      end
      
      def category(name, &block)
        @doc.categories << c = Category.new(name)
        CategoryKeyword.new(c).instance_eval(&block)

        new_method =  "def #{name}(v, &b); " +
          "m = self.merit(v, &b);"  +
          "m.category = @doc.categories[#{@doc.categories.size - 1}]; " + 
          "m;" +
          "end"
        
        self.instance_eval(new_method)
      end
      
      def merit(name, &block)
        @doc.merits << merit = Merit.new(name)
        MeritKeyword.new(merit).instance_eval(&block)
        merit.check
        merit
      end
      
    end

    class CategoryKeyword
      def initialize(category)
        @category = category
      end

      def folder(str)
        @category.folder = str
      end

      def description(str)
        @category.description = str
      end
      
      def short_description(str)
        @category.short_description = str
      end
    end

    module IncludeKeywords
      def include(filename, options = {})
        if filename =~ /\.jpg$/
          @merit.include_jpg(filename, options)
        elsif filename =~ /\.pdf$/
          @merit.include_pdf(filename, options)
        end
      end

      def include_external(filename, options = {})
        options[:external] = true
        include(filename, options)
      end

      def reference_doc(name)
        # Should be defined in upper scope
        doc = @merit.parent.find_doc(name)
        @merit.use_referenced_doc(doc)
      end
    end
    
    class MeritKeyword
      include ::Assembler::DSL::IncludeKeywords
      
      def initialize(merit)
        @merit = merit
      end

      def name(str)
        @merit.longname = str
      end

      def define_doc(name, filename) 
        file = if filename =~ /\.jpg$/
                 JPG.new(filename, :external => true)
               elsif filename =~ /\.pdf$/
                 PDF.new(filename, :external => true)
               end
        
        doc = DocDefinition.new(name, file)
        @merit.add_doc_definition(doc)
        doc
      end
      
      def item(str, &block)
        item = Item.new(@merit, str)
        item.longname = str
        @merit.add_item item
        ItemKeyword.new(item).instance_eval(&block)
        item
      end
    end
  end

  class ItemKeyword
    include ::Assembler::DSL::IncludeKeywords
      
    def initialize(item)
      @merit = item # This is to make IncludeKeywords work as expected
    end

  end
  
  def self.create_merits(&block)
    root = DSL::Root.new
    root.instance_eval(&block)
    root.doc
  end
end


class ::String
  def quote; '"' + self +'"'; end
end
