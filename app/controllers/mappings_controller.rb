require 'cgi'

class MappingsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include MappingStatistics

  layout :determine_layout
  before_action :authorize_and_redirect, :only=>[:create,:new,:destroy]



  EXTERNAL_URL_PARAM_STR = "mappings:external"
  INTERPORTAL_URL_PARAM_STR = "interportal:"

  INTERPORTAL_HASH = $INTERPORTAL_HASH ||= {}

  def index
    ontology_list = LinkedData::Client::Models::Ontology.all.select {|o| !o.summaryOnly}
    ontologies_mapping_count = LinkedData::Client::HTTP.get("#{MAPPINGS_URL}/statistics/ontologies")
    ontologies_hash = {}
    ontology_list.each do |ontology|
      ontologies_hash[ontology.acronym] = ontology
    end

    # TODO_REV: Views support for mappings
    # views_list.each do |view|
    #   ontologies_hash[view.ontologyId] = view
    # end

    @options = {}
    if ontologies_mapping_count
      ontologies_mapping_count.members.each do |ontology_acronym|
        # Adding external and interportal mappings to the dropdown list
        if ontology_acronym.to_s == EXTERNAL_MAPPINGS_GRAPH
          mapping_count = ontologies_mapping_count[ontology_acronym.to_s] || 0
          select_text = "External Mappings (#{number_with_delimiter(mapping_count, delimiter: ',')})" if mapping_count >= 0
          ontology_acronym = EXTERNAL_URL_PARAM_STR
        elsif ontology_acronym.to_s.start_with?(INTERPORTAL_MAPPINGS_GRAPH)
          mapping_count = ontologies_mapping_count[ontology_acronym.to_s] || 0
          select_text = "Interportal Mappings - #{ontology_acronym.to_s.split("/")[-1].upcase} (#{number_with_delimiter(mapping_count, delimiter: ',')})" if mapping_count >= 0
          ontology_acronym = INTERPORTAL_URL_PARAM_STR + ontology_acronym.to_s.split("/")[-1]
        else
          ontology = ontologies_hash[ontology_acronym.to_s]
          mapping_count = ontologies_mapping_count[ontology_acronym] || 0
          next unless ontology && mapping_count > 0
          select_text = "#{ontology.name} - #{ontology.acronym} (#{number_with_delimiter(mapping_count, delimiter: ',')})"
        end
        @options[select_text] = ontology_acronym
      end
    end

    @options = @options.sort
  end

  def count
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    @ontology_acronym = @ontology&.acronym || params[:id]
    @mapping_counts = mapping_counts(@ontology_acronym)
    render partial: 'count'
  end

  def show
    page = params[:page] || 1
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    @target_ontology = LinkedData::Client::Models::Ontology.find(params[:target])

    # Cases if ontology or target are interportal or external
    if @ontology.nil?
      ontology_acronym = params[:id]
      if params[:id] == EXTERNAL_URL_PARAM_STR
        @ontology_name = "External Mappings"
      elsif params[:id].start_with?(INTERPORTAL_URL_PARAM_STR)
        @ontology_name = params[:id].sub(":", " - ")
      end
    else
      ontology_acronym = @ontology.acronym
      @ontology_name = @ontology.name
    end
    if @target_ontology.nil?
      if params[:target] == EXTERNAL_MAPPINGS_GRAPH
        target_acronym = EXTERNAL_URL_PARAM_STR
        @target_ontology_name = "External Mappings"
      elsif params[:target].start_with?(INTERPORTAL_MAPPINGS_GRAPH)
        target_acronym = "#{INTERPORTAL_URL_PARAM_STR}:#{params[:target].split("/")[-1]}"
        @target_ontology_name = "Interportal - #{params[:target].split("/")[-1].upcase}"
      end
    else
      target_acronym = @target_ontology.acronym
      @target_ontology_name = @target_ontology.name
    end

    ontologies = [ontology_acronym, target_acronym]

    @mapping_pages = LinkedData::Client::HTTP.get(MAPPINGS_URL, {page: page, ontologies: ontologies.join(",")})
    @mappings = @mapping_pages.collection
    @delete_mapping_permission = check_delete_mapping_permission(@mappings)

    if @mapping_pages.nil? || @mapping_pages.collection.empty?
      @mapping_pages = MappingPage.new
      @mapping_pages.page = 1
      @mapping_pages.pageCount = 1
      @mapping_pages.collection = []
    end

    total_results = @mapping_pages.pageCount * @mapping_pages.collection.length

    # This converts the mappings into an object that can be used with the pagination plugin
    @page_results = WillPaginate::Collection.create(@mapping_pages.page, @mapping_pages.collection.length, total_results) do |pager|
       pager.replace(@mapping_pages.collection)
    end

    render :partial => 'show'
  end

  def get_concept_table
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontologyid]).first
    @concept = @ontology.explore.single_class({full: true}, params[:conceptid])

    @mappings = @concept.explore.mappings

    @delete_mapping_permission = check_delete_mapping_permission(@mappings)

    render :partial => "mapping_table"
  end

  def new
    @ontology_from = LinkedData::Client::Models::Ontology.find(params[:ontology_from])
    @ontology_to = LinkedData::Client::Models::Ontology.find(params[:ontology_to])
    @concept_from = @ontology_from.explore.single_class({full: true}, params[:conceptid_from]) if @ontology_from
    @concept_to = @ontology_to.explore.single_class({full: true}, params[:conceptid_to]) if @ontology_to

    # Defaults just in case nothing gets provided
    @ontology_from ||= LinkedData::Client::Models::Ontology.new
    @ontology_to ||= LinkedData::Client::Models::Ontology.new
    @concept_from ||= LinkedData::Client::Models::Class.new
    @concept_to ||= LinkedData::Client::Models::Class.new

    @mapping_relation_options = [
      ["Identical (skos:exactMatch)", "http://www.w3.org/2004/02/skos/core#exactMatch"],
      ["Similar (skos:closeMatch)",   "http://www.w3.org/2004/02/skos/core#closeMatch"],
      ["Related (skos:relatedMatch)", "http://www.w3.org/2004/02/skos/core#relatedMatch"],
      ["Broader (skos:broadMatch)",   "http://www.w3.org/2004/02/skos/core#broadMatch"],
      ["Narrower (skos:narrowMatch)", "http://www.w3.org/2004/02/skos/core#narrowMatch"],
      ["Translation (gold:translation)", "http://purl.org/linguistics/gold/translation"],
      ["Free Translation (gold:freeTranslation)", "http://purl.org/linguistics/gold/freeTranslation"]
    ]

    respond_to do |format|
      format.html
    end    
  end

  def new_external
    @ontology_from = LinkedData::Client::Models::Ontology.find(params[:ontology_from])
    @ontology_to = LinkedData::Client::Models::Ontology.find(params[:ontology_to])
    @concept_from = @ontology_from.explore.single_class({full: true}, params[:conceptid_from]) if @ontology_from
    @concept_to = @ontology_to.explore.single_class({full: true}, params[:conceptid_to]) if @ontology_to

    @interportal_options = []
    INTERPORTAL_HASH.each do |key, value|
      @interportal_options.push([key, key])
    end

    # Defaults just in case nothing gets provided
    @ontology_from ||= LinkedData::Client::Models::Ontology.new
    @ontology_to ||= LinkedData::Client::Models::Ontology.new
    @concept_from ||= LinkedData::Client::Models::Class.new
    @concept_to ||= LinkedData::Client::Models::Class.new

    @mapping_relation_options = [
      ["Identical (skos:exactMatch)", "http://www.w3.org/2004/02/skos/core#exactMatch"],
      ["Similar (skos:closeMatch)",   "http://www.w3.org/2004/02/skos/core#closeMatch"],
      ["Related (skos:relatedMatch)", "http://www.w3.org/2004/02/skos/core#relatedMatch"],
      ["Broader (skos:broadMatch)",   "http://www.w3.org/2004/02/skos/core#broadMatch"],
      ["Narrower (skos:narrowMatch)", "http://www.w3.org/2004/02/skos/core#narrowMatch"],
      ["Translation (gold:translation)", "http://purl.org/linguistics/gold/translation"],
      ["Free Translation (gold:freeTranslation)", "http://purl.org/linguistics/gold/freeTranslation"]
    ]

    respond_to do |format|
      format.html
    end
  end

  # POST /mappings
  # POST /mappings.xml
  def create
    if params.has_key?(:mapping_type)
      # Means its an external or interportal mapping
      target_ontology = params[:map_to_bioportal_ontology_id]
      target = params[:map_to_bioportal_full_id]
    else
      # Means it's a regular internal mapping
      target_ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:map_to_bioportal_ontology_id]).first
      target = target_ontology.explore.single_class(params[:map_to_bioportal_full_id]).id
      target_ontology = target_ontology.id
    end
    source_ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:map_from_bioportal_ontology_id]).first
    source = source_ontology.explore.single_class(params[:map_from_bioportal_full_id])
    values = {
      classes: {
        source.id => source_ontology.id,
        target => target_ontology
      },
      creator: session[:user].id,
      relation: params[:mapping_relation],
      comment: params[:mapping_comment]
    }
    @mapping = LinkedData::Client::Models::Mapping.new(values: values)
    @mapping_saved = @mapping.save
    if @mapping_saved.errors
      render text: @mapping_saved.errors[0], status: :bad_request
    else
      @delete_mapping_permission = check_delete_mapping_permission(@mapping_saved)
      render :json => @mapping_saved
    end
  end

  def destroy
    errors = []
    successes = []
    mapping_ids = params[:mappingids].split(",")
    mapping_ids.each do |map_id|
      begin
        map_uri = "#{MAPPINGS_URL}/#{CGI.escape(map_id)}"
        result = LinkedData::Client::HTTP.delete(map_uri)
        raise Exception if !result.nil? #&& result["errorCode"]
        successes << map_id
      rescue Exception => e
        errors << map_id
      end
    end
    render :json => { :success => successes, :error => errors }
  end

end
