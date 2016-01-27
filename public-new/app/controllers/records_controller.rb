class RecordsController < ApplicationController
  before_filter :get_repository


  def resource
    resource = JSONModel(:resource).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects", "container_locations", "digital_object", "linked_agents", "related_accessions", "repository", "repository::agent_representation"])
    raise RecordNotFound.new if (!resource || !resource.publish)

    render :json => resource.to_json
  end


  def archival_object
    archival_object = JSONModel(:archival_object).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects", "container_locations", "digital_object", "linked_agents"])
    raise RecordNotFound.new if (!archival_object || archival_object.has_unpublished_ancestor || !archival_object.publish)

    render :json => archival_object.to_json
  end


  def accession
    accession = JSONModel(:accession).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects", "linked_agents", "container_locations", "digital_object", "related_resources"])

    raise RecordNotFound.new if (!accession || !accession.publish)


    render :json => accession.to_json
  end


  def digital_object
    digital_object = JSONModel(:digital_object).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects", "linked_instances", "linked_agents"])
    raise RecordNotFound.new if (!digital_object || !digital_object.publish)

    render :json => digital_object.to_json
  end


  def get_repository
    @repository = @repositories.select{|repo| JSONModel(:repository).id_for(repo.uri).to_s === params[:repo_id]}.first
  end
end
