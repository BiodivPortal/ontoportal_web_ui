class SubmissionsController < ApplicationController

  layout 'ontology'
  before_action :authorize_and_redirect, :only=>[:edit,:update,:create,:new]

  def new
    @ontology = LinkedData::Client::Models::Ontology.get(CGI.unescape(params[:ontology_id])) rescue nil
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first unless @ontology
    @submission = @ontology.explore.latest_submission
    @submission ||= LinkedData::Client::Models::OntologySubmission.new
  end

  def create
    # Make the contacts an array
    params[:submission][:contact] = params[:submission][:contact].values

    @submission = LinkedData::Client::Models::OntologySubmission.new(values: params[:submission])
    @ontology = LinkedData::Client::Models::Ontology.find(@submission.ontology)
    @submission_saved = @submission.save
    if !@submission_saved || @submission_saved.errors
      @errors = response_errors(@submission_saved) # see application_controller::response_errors
      if @errors[:error][:uploadFilePath] && @errors[:error][:uploadFilePath].first[:options]
        @masterFileOptions = @errors[:error][:uploadFilePath].first[:options]
        @errors = ["Please select a main ontology file from your uploaded zip"]
      end
      render "new"
    else
      # Update summaryOnly on ontology object
      @ontology.summaryOnly = @submission.isRemote.eql?("3")
      @ontology.save
      redirect_to "/ontologies/success/#{@ontology.acronym}"
    end
  end

  def edit
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    submissions = @ontology.explore.submissions
    @submission = submissions.select {|o| o.submissionId == params["id"].to_i}.first
  end

  def update
    # Make the contacts an array
    params[:submission][:contact] = params[:submission][:contact].values

    @ontology = LinkedData::Client::Models::Ontology.get(params[:submission][:ontology])
    submissions = @ontology.explore.submissions
    @submission = submissions.select {|o| o.submissionId == params["id"].to_i}.first
    @submission.update_from_params(params[:submission])
    error_response = @submission.update

    # Update summaryOnly on ontology object
    @ontology.summaryOnly = @submission.isRemote.eql?("3")
    @ontology.save

    if error_response
      @errors = response_errors(error_response) # see application_controller::response_errors
    else
      redirect_to "/ontologies/#{@ontology.acronym}"
    end
  end

  ###
  # Controller of views/submission/edit_metadata.html.haml
  # When GET: retrieve metadata infos to display form
  # When POST: edit the submission metadata
  def edit_metadata

    if request.get?
      # Get the submission metadata from the REST API
      json_metadata = JSON.parse(Net::HTTP.get(URI.parse("#{REST_URI}/submission_metadata?apikey=#{API_KEY}")))
      @metadata = json_metadata

    elsif request.post?

      # For the moment just print in console and redirect to the same page
      puts "test in post_metadata"
      redirect_to "#{request.fullpath}"
    end
  end


end
