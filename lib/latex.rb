# -*- coding: utf-8 -*-
require 'lib/base_generator'
#require 'fileutils'

module Assembler

  class PrintContext
    attr_reader :doc
    def initialize(doc)
      @doc = doc
      @generated_declared_docs = []
    end
    
    attr_reader :current_merit
    attr_reader :section_merit
    
    def in_merit(merit)
      @current_merit = merit
      if merit.respond_to?(:parent)
        @section_merit = merit.parent
      else
        @section_merit = merit
      end

    end

    def was_generated?(doc_name)
      @generated_declared_docs.include?(doc_name)
    end

    def mark_generated(doc_name)
      @generated_declared_docs << doc_name
    end
    
    attr_accessor :is_first_file
  end

  module FileFinder
    def find_dir_fuzzy(path, name)
      entry = Dir.entries(path).find { |e|
        e =~ Regexp.new(name.to_s, Regexp::IGNORECASE)
      }
      raise "No directory for #{path}/#{name}" unless entry
      "#{path}/#{entry}"
    end
  end

  #
  # MeritDocument
  #
  class MeritDocument
    def latex()
      context = PrintContext.new(self)
      
      preamble

      # generate counters

      # uniq is needed because as_label may use a merit item to
      # generate the label, an this produces duplicates
      all_labelled_elements.map { |m|
         "\\newcounter{includepdfpage#{m.as_label}}"
      }.uniq.each { |s|
        println s
      }

      # @categories.each { |c|
      #   println ' \begin{table}\begin{tabular}{lll}'
       
      #   rows = ordered_merits.select { |m| m.category == c }.
      #   map { |m|
      #     "~ & #{m.latex_longname} & \\pageref{#{m.as_label}.1} \\\\"
      #   }.join($/)
        
      #   println rows
      #   println '\end{tabular}\end{table}'
      # }

      

      println '\newpage'

      @categories.each { |c|
        println "\\vspace*{0.5cm}"
        header = "\\lhead{}\\chead{}\\rhead{\\thepage}"
        println "#{header}\\section{#{c.long_descriptive_name}}"

        
        # Table with the list of documents associated to the section
        println '\renewcommand{\arraystretch}{1.5}'
        #        println '\begin{tabular}{lll}'
        println '\begin{longtable}[l]{lp{15cm}l}'
       
        rows = section_merits.select { |m| m.category == c }.
        map { |m|
          r1 = "~ & #{m.latex_longname} & \\pageref{#{m.as_label}.1} \\\\"
          r2 = m.items.map { |i|
            "~ & ~~~ #{i.latex_longname} & \\pageref{#{i.as_label}.1} \\\\"
          }.join($/)

          # This might be naturally solved with a new type of .item
          #description = ''
          #if m.text then
          #  description = "~ & ~~~ #{m.text.title} & \\pageref{#{m.as_label}.text} \\\\"
          #end
          
          r1 + r2
        }.join($/)
        
        println rows
        #println '\end{tabular}'
        println '\end{longtable}'
        
        println '\newpage'
        # End-of-table
        
        merit_pages = all_ordered_merits.select { |m| m.category == c }.
        map { |m|
          m.latex(context)
        }.join($/)

        println merit_pages
        
      }

      epilog
    end
    
    def print_packages
      println '\usepackage[utf8]{inputenc}'
      println '\usepackage[spanish,es-tabla]{babel}'
      println '\selectlanguage{spanish}'

      println '\usepackage{graphicx}'
      if root_dir
        println "\\graphicspath{{#{root_dir}}}"
      end
      println ''
      println '\usepackage{pdfpages}'
      #println '\newcounter{includepdfpage}'


      println '\usepackage[top=1.5cm, bottom=1.5cm, left=1cm, right=1cm]{geometry}'
      println '\setlength{\headsep}{0.5cm}'
  
      println '\usepackage{fancyhdr}'
      println '\pagestyle{fancy}'

      println '\usepackage[linktoc=all]{hyperref}'
      println '\usepackage{longtable}'

      println '\renewcommand{\tablename}{Tabla}'
      #println '\hypersetup{
    #colorlinks,
    #citecolor=black,
    #filecolor=black,
    #linkcolor=black,
    #urlcolor=black
#}'

      println '\usepackage{changepage}'
    end

    def title_or_default
      @title || 'Justificación de méritos'
    end

    def subtitle_or_default
      @subtitle || ''
    end

    def fullname_or_default
      @fullname || 'Jesús Sánchez Cuadrado'
    end

    def preamble
      println '
\documentclass{article}
% \pagestyle{headings}
'
      print_packages
      
      println '\begin{document}
\title{\textbf{' + self.title_or_default + '}
\\\\
' + self.subtitle_or_default + '
}
\author{' + self.fullname_or_default + '}
\maketitle
\newpage

\lhead{' + self.title_or_default + '}\chead{}\rhead{}
\vspace*{0.5cm}
\tableofcontents
\newpage
'
    end
    
    def epilog
      println '
\end{document}
'
    end

  end

  #
  # Merit
  #
  class Merit
    def latex(context)
      # subsection = "\\subsection{#{self.latex_longname}}"
      desc = self.category.short_descriptive_name
      ltext = desc + " - " + self.latex_longname 
      header = "\\lhead{#{ltext}}\\chead{}\\rhead{\\thepage}"
      
      # header = header + "\\label{#{self.name}}"

      push_merit(context)
      # I could change header here

      context.is_first_file = true
      result = header + $/ + @included.map { |i| 
        text = i.latex(context) 
        context.is_first_file = false
        text
      }.join($/)


      if not self.used_doc.nil?
        unless context.was_generated?(self.used_doc.name)
          puts "Generating" + self.used_doc.name.to_s
          result = result + self.used_doc.latex(context)
          context.mark_generated(self.used_doc.name)
          context.is_first_file = false
        end
      end
      
      result
    end

    def push_merit(context)
      context.in_merit(self)
    end
    
    def as_label
      if not self.used_doc.nil?
        self.used_doc.as_label
      elsif @included.empty?# and not self.items.empty?
        self.items.first.as_label
      else
        Merit.label_from_name(self.name)
      end
    end

    def latex_longname
      self.longname #.gsub('ó', "\\'{o}")
    end

    def self.label_from_name(name)
      v = name.to_s.gsub('.', '').
          gsub('_', '').
          gsub('-', '').
          gsub('ó', 'o').
          gsub('á', 'a').
          gsub('í', 'i').
          gsub('ú', 'u').
          gsub('é', 'e').
          gsub(',', '').
          gsub('\'', '').
          gsub('(', '').
          gsub('ñ', 'nh').
          gsub(')', '')
      v = v + self.object_id.to_s
      (0..9).to_a.inject(v) { |tmp, i| tmp.gsub(i.to_s, (65 + i).chr) }
    end
    
  end

  class DocDefinition
    def as_label
      Merit.label_from_name(self.name)
    end

    def latex(context)
      @external_file.latex(context)
    end
  end
  
  class IncludedFile
    def find_path(context)
      
      merit  = context.section_merit
      path = if @options[:external] == true
               File.join(context.doc.root_dir, @filename)
             else
               folder = File.join(context.doc.root_dir, merit.category.folder_text)
               folder = find_dir_fuzzy(folder, merit.name)
               "#{folder}/#{@filename}"
             end
      path
    end

  end

  # JPG files
  class JPG
    include FileFinder
    def latex(context)
      abs_path = find_path(context) 
      
      graphic_options = '[width=0.85\textwidth]'
      if @options[:fit] == false
        graphic_options = ''
      end

      label = ''
      if context.is_first_file
        label = "\\phantomsection\\label{#{context.current_merit.as_label}.1}"
      end

 
      label + "\\includegraphics#{graphic_options}{#{abs_path}}\\newpage"
    end
  end

  class PNG
    include FileFinder
    def latex(context)
      abs_path = find_path(context) 
      
      graphic_options = '[width=0.85\textwidth]'
      if @options[:fit] == false
        graphic_options = ''
      end

      label = ''
      if context.is_first_file
        label = "\\phantomsection\\label{#{context.current_merit.as_label}.1}"
      end

 
      label + "\\includegraphics#{graphic_options}{#{abs_path}}\\newpage"
    end
  end

  
  # JPG files
  class PDF
    include FileFinder
    def latex(context)
      abs_path = find_path(context)
      pages = if @options[:pages]
                "{" + @options[:pages].join(',') + "}"
              else
                "-"
              end

      command = ''
      if context.is_first_file
        command = "{\\refstepcounter{includepdfpage#{context.current_merit.as_label}}\\label{#{context.current_merit.as_label}.\\theincludepdfpage#{context.current_merit.as_label}}}"
      end
      
      
      #      toc_option = "addtotoc={1,section,1,#{context.current_merit.latex_longname}, #{context.current_merit.as_label}}"
      #command = "\\addtotoc{\\thepage,}"
      #addtotoc={ page number , section , level , heading , label }

 
      # This creates an extra page sometimes

      "\\includepdf[pages=#{pages},pagecommand={#{command}},offset=0mm -5mm]{#{abs_path}}"

#      "\\includepdf[pages=#{pages},#{toc_option},pagecommand={#{command}},offset=0mm -5mm]{#{abs_path}}"
    end
  end

  class Text
    def latex(context)
      label = ''
      if context.is_first_file
        label = "\\phantomsection\\label{#{context.current_merit.as_label}.1}"
      end
      
      contents = "\\section*{#{context.section_merit.latex_longname}}\\subsection*{#{@title}}\n#{@text}"
      more_contents = label + "\\begin{adjustwidth}{1cm}{1cm}\n" + contents + "\n \\end{adjustwidth}"
      #more_contents = contents
      #"\\newgeometry{bottom=1.5cm}"
      #+
      "\\large" + more_contents + "\\normalsize \\newpage"
      #+
      #"\\restoregeometry  \\newpage"
    end
  end
    
  
  class Category
    def folder_text
      if @folder then "#{@folder}/" else '' end
    end
  end
  
end













# To generate the list...
module Assembler
  class MeritDocument
    def latex2
      println '\documentclass{article}'
      println '\usepackage[utf8]{inputenc}'
      println '\usepackage[spanish,es-tabla]{babel}'
      println '\selectlanguage{spanish}'

      println '\usepackage[top=2cm, bottom=2cm, left=2cm, right=2cm]{geometry}'      
      println '\begin{document}'
      println '\subsection*{Listado de documentos aportados}'
      println '\begin{itemize}'
      
      @categories.each { |c|
        println "\\item #{c.long_descriptive_name}"
        println '\begin{itemize}'
        rows = section_merits.select { |m| m.category == c }.
        map { |m|
          "\\item #{m.latex_longname}" + gen_items(m)
        }.join($/)
        
        println rows
        println '\end{itemize}'
      }
      
      println '\end{itemize}'
      println '\end{document}'
      
    end

    def gen_items(m)
      if m.items.empty?
        ''
      else
        "\\begin{itemize}" +
          m.items.map { |i| "\\item #{i.latex_longname}"}.join($/) +
          "\\end{itemize}"
      end
    end
  end
end
