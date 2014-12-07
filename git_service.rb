require 'webmachine'
require 'webrick'
require 'multi_json'
require 'git'
require 'open-uri'
require_relative "git_action"
# require_relative "diff_parser"

BASE_GIT_DIR="/tmp"

class GitCreationService
  attr_reader :git_provider, :resource, :error, :response

  def initialize(resource)
    puts "Initializing GitCreationService"
    @git_provider = git_provider
    @resource = resource
  end

  def call # body in resource
    body = MultiJson.load(resource.request.body.to_s)
    params ||= resource.request.params
    puts "Calling GitCreationService.call"
    case resource.request.method
    when "GET"
      puts "Calling GET"
      @response = GitAction.new(params['project']).diff(params['head'], params['compare_to'])
    when "POST"
      puts "Calling POST"
      @response = GitAction.new(body['project']).diff(body['head'], body['compare_to'])
    else
      @response = {error: "Bad request"}
    end
  end
end


class ResourceCreator
  attr_accessor :error
  def call(route, request, response)
    resource = route.resource.new(request, response)
    service = GitCreationService.new(resource)
    resource.git_creation_service = service
    resource
  end
end

class GitResource < Webmachine::Resource
  attr_accessor :diff, :rendered_data, :git_creation_service, :request, :params, :resource, :error

  def allowed_methods
    %w(GET POST)
  end

  def content_types_accepted
    [['application/json', :accept_resource]]
  end

  def content_types_provided
    [['application/json', :render_resource]]
  end

  def accept_resource
    # body = MultiJson.load(request.body.to_s)
    puts "Request: #{request.inspect}"
    puts "Request body: #{request.body.inspect}"
    puts "PARAMS: #{params}"
    puts "Calling creation service with params: #{request.params.inspect}"
    # git_creation_service.call #(URI::encode(params))
  end

  def sgs_unknown_error(sgs)
    self.rendered_data = MultiJson.dump(message: "UNKNOWN_ERROR",
                                        inspect: sgs.inspect)
  end

  def sgs_data_invalid(reason)
    self.rendered_data = MultiJson.dump(message: "DATA_INVALID",
                                        reason: reason)
  end

  def process_post
    response.headers['Content-Type'] = 'application/json'
    response.body = MultiJson.dump git_creation_service.call
    # must end truthy
    true
  end

  def sgs_successful(id)
    self.rendered_data = MultiJson.dump(message: "SUCCESS",
                                        uuid: id)
  end

  def render_resource
    puts "Called render resource"
    git_creation_service.call
    true
  end
end

@webmachine = Webmachine::Application.new do |app|
  app.routes do
    add ['sgs'], GitResource
  end

  app.configure do |config|
    config.ip = '127.0.0.1'
    config.port = 5555
    config.adapter = :WEBrick
  end

  app.dispatcher.resource_creator = ResourceCreator.new
end

@webmachine.run