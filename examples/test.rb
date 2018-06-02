# -*- coding: utf-8 -*-
$: << './'
require 'lib/dsl'
require 'lib/latex'
require 'fileutils'

if ARGV.empty?
  puts "Not enough arguments"
  puts "Run with:"
  puts "  #{__FILE__} <document-dir>"
  exit
end

output_dir = "./gen"
if not File.exists?(output_dir)
  puts "Creating output dir... #{output_dir}"
  FileUtils.mkdir(output_dir)
end

root = ARGV[0]
puts root

doc = Assembler.create_merits do
  root_dir root
  fullname 'Jesús Sánchez Cuadrado'
  title 'Justificación de méritos'
  subtitle 'Plaza de investigador en ACME'


  #
  # Configuración de la estructura del CV
  #
  
  category :research_project do
    description 'Proyectos de I+D+i financiados en convocatorias competitivas de Administraciones o entidades públicas y privadas'
    short_description 'Proyectos de I+D+i competitivos'

    folder 'ParticipacionProyectos'
  end

  category :research_contract do
    description 'Contratos, convenios o proyectos de I+D+i no competitivos con Administraciones o entidades públicas o privadas'
    short_description 'Contratos de I+D+i'

    folder 'ContratosInvestigacion'
  end


  #
  # Instancia del curriculum
  #
  
  research_project :ip_proyectos do
    name 'IP en proyectos de investigación'
    # Estos ficheros deben estar en una carpeta que se llame ParticipacionProyectos/ip_proyectos
    include 'proyecto-grande.pdf'   
    include 'proyecto-peq.pdf'   
  end
 
  research_project :proyectos_no_ip do
    name 'Participación en proyectos de investigación (No IP)'
    # Este fichero estará en carpeta otros_proyectos/ directamente
    include_external 'otros_proyectos/proyectos-de-otros.pdf'
  end

  research_project :mis_contratos do
    name 'Participación en proyectos de investigación (No IP)'
    # Este fichero estará en carpeta otros_proyectos/ directamente
    include_external 'mis_contratos/lista_contratos.pdf', :pages => [1, 3]
  end

end

doc.gen_folder('gen')
doc.latex
doc.dump('doc.tex')

doc.clean
doc.latex2
doc.dump('list.tex')
