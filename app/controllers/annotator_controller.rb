require "json"
require "cgi"

class AnnotatorController < ApplicationController
  layout :determine_layout
  include ApplicationHelper

  ANNOTATOR_URI = $ANNOTATOR_URL
  ANNOTATOR_PLUS_URI = $ANNOTATOR_URL+"/annotatorplus"
  NCBO_ANNOTATOR_PLUS_URI = $NCBO_ANNOTATOR_URL

  before_action :initialize_options, only: [:index, :annotator_plus, :ncbo_annotator_plus]
  def index
    set_annotator_info('/annotator', 'Annotator', ANNOTATOR_URI)
  end

  def annotator_plus
    set_annotator_info('/annotatorplus', 'Annotator +', ANNOTATOR_PLUS_URI)
    render 'index'
  end

  def ncbo_annotator_plus
    params[:apikey] = $NCBO_API_KEY
    set_annotator_info('/ncbo_annotatorplus', 'NCBO Annotator +', NCBO_ANNOTATOR_PLUS_URI)
    render 'index'
  end

  private
  def set_annotator_info(url, page_name, uri)
    @form_url = url
    @page_name = page_name
    annotator_results(uri)
  end
  def annotator_results(uri)
    @advanced_options_open = false
    @annotator_ontologies = LinkedData::Client::Models::Ontology.all
    if params[:text] && !params[:text].empty?
      @init_whole_word_only = true
      api_params = {
        text: remove_special_chars(params[:text]),
        ontologies: params[:ontologies],
        semantic_types: params[:semantic_types],
        semantic_groups: params[:semantic_groups],
        whole_word_only: params[:whole_word_only],
        longest_only: params[:longest_only],
        expand_mappings: params[:expand_mappings],
        exclude_numbers: params[:exclude_numbers],
        exclude_synonyms: params[:exclude_synonyms],
        semantic_types: params[:semantic_types],
        semantic_groups: params[:semantic_groups],
        class_hierarchy_max_level: params[:class_hierarchy_max_level],
        score_threshold: params[:score_threshold],
        confidence_threshold: params[:confidence_threshold],
        fast_context: params[:fast_context],
        lemmatize: params[:lemmatize]
      }
      unless params[:score].eql?('none')
        api_params[:score] = params[:score]
      end
      @json_link = json_link(uri, api_params)
      @rdf_link = "#{@json_link}&format=rdf"
      @results_table_header = [
        t('annotator.class'), t('annotator.ontology'), t('annotator.context')
      ]
      if params[:fast_context]
        @results_table_header += [t('annotator.negation'), t('annotator.experiencer'), t('annotator.temporality'), t('annotator.certainty')]
      end
      @direct_results = 0
      @parents_results = 0
      if params[:score].nil? || params[:score].eql?('none')
        params[:score] = nil
      else
        @results_table_header.push(t('annotator.score'))
      end

      # if we are in a slice, pass the ontologies of this slice in the params
      
      if at_slice?
        slice_ontologies_acronyms = @subdomain_filter[:ontologies].map{ |id| link_last_part(id)}
        if api_params[:ontologies]
          selected_ontolgies = api_params[:ontologies].split(',')
          filtred_ontologies = selected_ontolgies.select{ |ontology| slice_ontologies_acronyms.include?(ontology) }
        else
          filtred_ontologies = slice_ontologies_acronyms
        end
        api_params[:ontologies] = filtred_ontologies.join(',')
      end

      annotations = LinkedData::Client::HTTP.get(uri, api_params)
      @ontologies = LinkedData::Client::Models::Ontology.all({:include_views => true}).map{ |o| [o.id.to_s, o]}.to_h

      @semantic_types = get_semantic_types 
      @results = []
      annotations.each do |annotation|
        if annotation.annotations.empty?
          row = {
            class: annotation_class_info(annotation.annotatedClass),
            ontology: annotation_ontology_info(annotation.annotatedClass.links),
            context: "",
            type: 'direct'
          }
          unless params[:score].eql?('none')
            row[:score] = annotation.score.nil? ? '' : sprintf("%.2f", annotation.score)
          end
          @direct_results = @direct_results + 1
          @results.push(row)
        else
          row = {
              class: annotation_class_info(annotation.annotatedClass),
              ontology: annotation_ontology_info(annotation.annotatedClass.links["ontology"]),
              context: [],
              type: 'direct'
          }
          unless params[:score].eql?('none')
            row[:score] = annotation.score.nil? ? '' : sprintf("%.2f", annotation.score)
          end
          annotation.annotations.each do |a|
            row[:context].push(a)
            if params[:fast_context]
              row[:negation] = a.negationContext
              row[:experiencer] = a.experiencerContext
              row[:temporality] = a.temporalityContext
              row[:certainty] = a.certaintyContext
            end
          end
          index = @results.find_index { |result| result[:class] == row[:class] }
          if index
            @results[index][:context].unshift(*row[:context])
            @results[index][:score] = @results[index][:score].to_i + row[:score].to_i
          else
            @results.push(row)
          end
          @direct_results = @direct_results + 1
        end
        annotation.hierarchy.each do |parent|
            row = {
              class: annotation_class_info(parent.annotatedClass),
              ontology: annotation_ontology_info(parent.annotatedClass.links["ontology"]),
              context: [{child: annotation_class_info(annotation.annotatedClass), level: parent.distance}],
              type: 'parent'
            }
            unless params[:score].eql?('none')
              row[:score] = parent.score.nil? ? '' : sprintf("%.2f", parent.score)
            end
            index = @results.find_index { |result| result[:class] == row[:class] }
            if index
              @results[index][:context] += row[:context]
              @results[index][:score] = @results[index][:score].to_i + row[:score].to_i
            else
              if params[:fast_context]
                row[:negation] = annotation.annotations[0].negationContext
                row[:experiencer] = annotation.annotations[0].experiencerContext
                row[:temporality] = annotation.annotations[0].temporalityContext
                row[:certainty] = annotation.annotations[0].certaintyContext
              end
              @results.push(row)
            end
            @parents_results = @parents_results + 1
        end
      end
      @advanced_options_open = !empty_advanced_options
    end
  end

  def get_semantic_types
    semantic_types = {}
    sty_ont = LinkedData::Client::Models::Ontology.find_by_acronym('STY').first
    return semantic_types if sty_ont.nil?
    # The first 500 items should be more than sufficient to get all semantic types.
    sty_classes = sty_ont.explore.classes({'pagesize'=>500, include: 'prefLabel'})
    Array(sty_classes.collection).each do |cls|
      code = cls.id.split("/").last
      semantic_types[ code ] = cls.prefLabel
    end
    semantic_types
  end

  def annotation_class_info(cls)
    {
      text: cls.prefLabel,
      link: url_to_endpoint(cls.links["self"])
    }
  end
  def annotation_ontology_info(ontology_url)
    {
      text: @ontologies[ontology_url].name,
      link: url_to_endpoint(ontology_url)
    }
  end

  def initialize_options
    @semantic_types_for_select = []
    @semantic_groups_for_select = []
    @semantic_types ||= get_semantic_types
    @sem_type_ont = LinkedData::Client::Models::Ontology.find_by_acronym("STY").first
    @semantic_groups ||= { "ACTI" => "Activities & Behaviors", "ANAT" => "Anatomy", "CHEM" => "Chemicals & Drugs", "CONC" => "Concepts & Ideas", "DEVI" => "Devices", "DISO" => "Disorders", "GENE" => "Genes & Molecular Sequences", "GEOG" => "Geographic Areas", "LIVB" => "Living Beings", "OBJC" => "Objects", "OCCU" => "Occupations", "ORGA" => "Organizations", "PHEN" => "Phenomena", "PHYS" => "Physiology", "PROC" => "Procedures" }
    @semantic_types.each_pair do |code, label|
      @semantic_types_for_select << ["#{label} (#{code})", code]
    end
    @semantic_groups.each_pair do |group, label|
      @semantic_groups_for_select << ["#{label} (#{group})", group]
    end
    @semantic_types_for_select.sort! { |a, b| a[0] <=> b[0] }
    @semantic_groups_for_select.sort! { |a, b| a[0] <=> b[0] }
    if !$MULTIPLE_RECOGNIZERS.nil? && $MULTIPLE_RECOGNIZERS == true
      # Get recognizers from ontologies_api only if asked
      @recognizers = parse_json(REST_URI + "/annotator/recognizers")
    else
      @recognizers = []
    end
    @annotator_ontologies = LinkedData::Client::Models::Ontology.all
  end

  def create
    params[:mappings] ||= []
    params[:max_level] ||= 0
    params[:ontologies] ||= []
    params[:semantic_types] ||= []
    params[:semantic_groups] ||= []
    text_to_annotate = params[:text].strip.gsub("\r\n", " ").gsub("\n", " ")

    options = { :ontologies => params[:ontologies],
                :class_hierarchy_max_level => params[:class_hierarchy_max_level].to_i,
                :expand_class_hierarchy => params[:class_hierarchy_max_level].to_i > 0,
                :semantic_types => params[:semantic_types],
                :semantic_groups => params[:semantic_groups],
                :expand_mappings => params[:expand_mappings],
                :longest_only => params[:longest_only],
                :exclude_numbers => params[:exclude_numbers] ||= "false",  # service default is false
                :whole_word_only => params[:whole_word_only] ||= "true", # service default is true
                :exclude_synonyms => params[:exclude_synonyms] ||= "false",  # service default is false
                :fast_context => params[:fast_context] ||= "false",  # service default is false
                :score => params[:score],
                :score_threshold => params[:score_threshold] ||= -1,
                :confidence_threshold => params[:confidence_threshold] ||= -1,
                :lemmatize => params[:lemmatize] ||= "false",
                :ncbo_slice => params[:ncbo_slice] || "" }

    start = Time.now
    query = ANNOTATOR_URI
    query += "?text=" + CGI.escape(text_to_annotate)
    #query += "&apikey=" + annotator_apikey
    #query += "&include=prefLabel"
    # Include= prefLabel causes an internal error when retrieving mappings
    query += "&expand_class_hierarchy=true" if options[:class_hierarchy_max_level] > 0
    query += "&class_hierarchy_max_level=" + options[:class_hierarchy_max_level].to_s if options[:class_hierarchy_max_level] > 0
    query += "&score=" + options[:score] unless options[:score] == ""
    query += "&score_threshold=" + options[:score_threshold] unless options[:score] == "" or options[:score_threshold] == -1
    query += "&confidence_threshold=" + options[:confidence_threshold] unless options[:score] == "" or options[:confidence_threshold] == -1
    query += "&fast_context=" + options[:fast_context] unless options[:fast_context].empty?
    query += "&ontologies=" + CGI.escape(options[:ontologies].join(",")) unless options[:ontologies].empty?
    query += "&semantic_types=" + options[:semantic_types].join(",") unless options[:semantic_types].empty?
    query += "&semantic_groups=" + options[:semantic_groups].join(",") unless options[:semantic_groups].empty?
    query += "&expand_mappings=" + options[:expand_mappings].to_s unless options[:expand_mappings].empty?
    query += "&longest_only=#{options[:longest_only]}"
    query += "&recognizer=#{params[:recognizer]}"
    query += "&exclude_numbers=" + options[:exclude_numbers].to_s unless options[:exclude_numbers].empty?
    query += "&lemmatize=" + options[:lemmatize].to_s unless options[:lemmatize].empty?
    query += "&whole_word_only=" + options[:whole_word_only].to_s unless options[:whole_word_only].empty?
    query += "&exclude_synonyms=" + options[:exclude_synonyms].to_s unless options[:exclude_synonyms].empty?
    query += "&ncbo_slice=" + options[:ncbo_slice].to_s unless options[:ncbo_slice].empty?

    annotations = parse_json(query) # See application_controller.rb
    #annotations = LinkedData::Client::HTTP.get(query)
    LOG.add :debug, "Query: #{query}"
    LOG.add :debug, "Retrieved #{annotations.length} annotations: #{Time.now - start}s"
    if annotations.empty? || params[:raw] == "true"
      # TODO: if params contains select ontologies and/or semantic types, only return those selected.
      response = {
        annotations: annotations,
        ontologies: get_simplified_ontologies_hash,  # application_controller
        semantic_types: get_semantic_types,           # application_controller
      }
    else
      massage_annotated_classes(annotations, options)
      response = {
        annotations: annotations,
        ontologies: {},        # ontology data are in annotations already.
        semantic_types: {},     # semantic types are in annotations already.
      }
    end

    render :json => response
  end
  

  private

  def get_semantic_types
    semantic_types = {}
    sty_ont = LinkedData::Client::Models::Ontology.find_by_acronym("STY").first
    return semantic_types if sty_ont.nil?
    # The first 500 items should be more than sufficient to get all semantic types.
    sty_classes = sty_ont.explore.classes({ "pagesize" => 500, include: "prefLabel" })
    sty_classes.collection.each do |cls|
      code = cls.id.split("/").last
      semantic_types[code] = cls.prefLabel
    end
    semantic_types
  end

  def massage_annotated_classes(annotations, options)
    # Get the class details required for display, assume this is necessary
    # for every element of the annotations array because the API returns a set.
    # Use the batch REST API to get all the annotated class prefLabels.
    start = Time.now
    semantic_types = options[:semantic_types] || []
    class_details = get_annotated_classes(annotations, semantic_types)
    simplify_annotated_classes(annotations, class_details)
    # repeat the simplification for any annotation hierarchy or mappings.
    hierarchy = annotations.map { |a| a if a.keys.include? "hierarchy" }.compact
    hierarchy.each do |a|
      simplify_annotated_classes(a["hierarchy"], class_details) if not a["hierarchy"].empty?
    end
    mappings = annotations.map { |a| a if a.keys.include? "mappings" }.compact
    mappings.each do |a|
      simplify_annotated_classes(a["mappings"], class_details) if not a["mappings"].empty?
    end
    LOG.add :debug, "Completed massage for annotated classes: #{Time.now - start}s"
  end

  def simplify_annotated_classes(annotations, class_details)
    annotations2delete = []
    annotations.each do |a|
      cls_id = a["annotatedClass"]["@id"]
      details = class_details[cls_id]
      if details.nil?
        LOG.add :debug, "Failed to get class details for: #{a["annotatedClass"]["links"]["self"]}"
        annotations2delete.push(cls_id)
      else
        # Replace the annotated class with simplified details.
        a["annotatedClass"] = details
      end
    end
    # Remove any annotations that fail to resolve details.
    annotations.delete_if { |a| annotations2delete.include? a["annotatedClass"]["@id"] }
  end

  def get_annotated_class_hash(a)
    return {
             :class => a["annotatedClass"]["@id"],
             :ontology => a["annotatedClass"]["links"]["ontology"],
           }
  end

  def get_annotated_classes(annotations, semantic_types = [])
    # Use batch service to get class prefLabels
    class_list = []
    annotations.each { |a| class_list << get_annotated_class_hash(a) }
    hierarchy = annotations.map { |a| a if a.keys.include? "hierarchy" }.compact
    hierarchy.each do |a|
      a["hierarchy"].each { |h| class_list << get_annotated_class_hash(h) }
    end
    mappings = annotations.map { |a| a if a.keys.include? "mappings" }.compact
    mappings.each do |a|
      a["mappings"].each { |m| class_list << get_annotated_class_hash(m) }
    end
    classes_simple = {}
    return classes_simple if class_list.empty?
    # remove duplicates
    class_set = class_list.to_set # get unique class:ontology set
    class_list = class_set.to_a   # collection requires a list in batch call
    # make the batch call
    properties = "prefLabel"
    properties = "prefLabel,semanticType" if not semantic_types.empty?
    call_params = { "http://www.w3.org/2002/07/owl#Class" => { "collection" => class_list, "include" => properties } }
    classes_json = get_batch_results(call_params)
    # Simplify the response data for the UI
    @ontologies_hash ||= get_simplified_ontologies_hash # application_controller
    classes_data = JSON.parse(classes_json)
    classes_data["http://www.w3.org/2002/07/owl#Class"].each do |cls|
      c = simplify_class_model(cls)
      ont_details = @ontologies_hash[c[:ontology]]
      next if ont_details.nil? # NO DISPLAY FOR ANNOTATIONS ON ANY CLASS OUTSIDE THE BIOPORTAL ONTOLOGY SET.
      c[:ontology] = ont_details
      unless semantic_types.empty? || cls["semanticType"].nil?
        @semantic_types ||= get_semantic_types   # application_controller
        # Extract the semantic type descriptions that are requested.
        semanticTypeURI = "http://bioportal.bioontology.org/ontologies/umls/sty/"
        semanticCodes = cls["semanticType"].map { |t| t.sub(semanticTypeURI, "") }
        requestedCodes = semanticCodes.map { |code| (semantic_types.include? code and code) || nil }.compact
        requestedDescriptions = requestedCodes.map { |code| @semantic_types[code] }.compact
        c[:semantic_types] = requestedDescriptions
      else
        c[:semantic_types] = []
      end
      classes_simple[c[:id]] = c
    end
    return classes_simple
  end
end
