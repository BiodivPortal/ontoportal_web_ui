require "uri"

class SearchController < ApplicationController
  skip_before_action :verify_authenticity_token

  layout :determine_layout

  def index
    @search_query = params[:query] || params[:q] || ''
    params[:query] = nil
    @advanced_options_open = false
    @search_results = []
    @json_url = json_link("#{rest_url}/search", {})

    return if @search_query.empty?

    params[:pagesize] = "150"
    results = LinkedData::Client::Models::Class.search(@search_query, params).collection

    @advanced_options_open = !search_params_empty?
    @search_results = aggregate_results(@search_query, results)
    @json_url = json_link("#{rest_url}/search", params.permit!.to_h)
  end

  def json_search
    if params[:q].nil?
      render :text => t('search.no_search_class_provided')
      return
    end
    check_params_query(params)
    check_params_ontologies(params)  # Filter on ontology_id
    if params["id"]&.eql?('All')
      params.delete("id")
      params.delete("ontologies")
    end
    search_page = LinkedData::Client::Models::Class.search(params[:q], params)
    @results = search_page.collection

    response = ""
    obsolete_response = ""
    separator = (params[:separator].nil?) ? "~!~" : params[:separator]

    for result in Array(@results)
      # TODO_REV: Format the response with type information, target information
      # record_type = format_record_type(result[:recordType], result[:obsolete])
      record_type = ""

      label = search_concept_label(result.prefLabel)
      target_value = label

      case params[:target]
      when "name"
        target_value = label
      when "shortid"
        target_value = result.id
      when "uri"
        target_value = result.id
      end

      acronym =  result.links["ontology"].split('/').last
      json = []
      json << "#{target_value}"
      json << " [obsolete]" if result.obsolete? # used by JS in ontologies/visualize to markup obsolete classes
      json << "|#{result.id}"
      json << "|#{record_type}"
      json << "|#{acronym}"
      json << "|#{result.id}" # Duplicated because we used to have shortId and fullId
      json << "|#{target_value}"
      # This is nasty, but hard to workaround unless we rewrite everything (form_autocomplete, jump_to, crossdomain_autocomplete)
      # to use JSON from the bottom up. To avoid this, we pass a tab separated column list
      # Columns: synonym
      json << "|#{(result.synonym || []).join(";")}"
      if params[:id] && params[:id].split(",").length == 1
        json << "|#{CGI.escape((result.definition || []).join(". "))}#{separator}"
      else
        json << "|#{acronym}"
        json << "|#{acronym}"
        json << "|#{CGI.escape((result.definition || []).join(". "))}#{separator}"
      end

      # Obsolete results go at the end
      if result.obsolete?
        obsolete_response << json.join
      else
        response << json.join
      end
    end

    # Obsolete results merge
    response << obsolete_response

    content_type = "text/html"
    if params[:response].eql?("json")
      response = response.gsub("\"", "'")
      response = "#{params[:callback]}({data:\"#{response}\"})"
      content_type = "application/javascript"
    end

    render plain: response, content_type: content_type
  end

  private

  def check_params_query(params)
    params[:q] = params[:q].strip
    params[:q] = params[:q] + "*" unless params[:q].end_with?("*") # Add wildcard
  end

  def check_params_ontologies(params)
    params[:ontologies] ||= params[:id]
    if params[:ontologies]
      if params[:ontologies].include?(",")
        params[:ontologies] = params[:ontologies].split(",")
      else
        params[:ontologies] = [params[:ontologies]]
      end
      if params[:ontologies].first.to_i > 0
        params[:ontologies].map! { |o| BpidResolver.id_to_acronym(o) }
      end
      params[:ontologies] = params[:ontologies].join(",")
    end
  end

  def format_record_type(record_type, obsolete = false)
    case record_type
    when "apreferredname"
      record_text = "Preferred Name"
    when "bconceptid"
      record_text = "Class ID"
    when "csynonym"
      record_text = "Synonym"
    when "dproperty"
      record_text = "Property"
    else
      record_text = ""
    end
    record_text = "Obsolete Class" if obsolete
    record_text
  end
end
