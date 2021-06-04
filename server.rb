$stdout.sync = true

require 'sinatra'
require 'sinatra/json'
require "sinatra/cors"
require "sinatra/reloader" if development?
require 'dotenv'
require 'open-uri'

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'ctapi'

Dotenv.load('.env.local', '.env')

set :allow_origin, "*"
set :allow_methods, "GET,HEAD,POST"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

def environment
  ENV['SVC_ENV']
end

def project
  ENV['CLOUDTRUTH_PROJECT']
end

def ctapi
  @ctapi ||= begin
    @ctapi_class = CtApi(api_key: ENV['CLOUDTRUTH_API_KEY'])
    @ctapi_class.new(environment: environment)
  end
end

def live_config
  begin
    puts "Fetching config from cloudtruth project '#{project}' for environment '#{environment}'"
    params = ctapi.parameters(project: project)
    return Hash[params.collect {|p| [p.key, p.value] }]
  rescue Exception => e
    msg = "#{e.class}: #{e.message}"
    $stderr.puts "Failure fetching config: #{msg}"
    return {"live_config_error" => msg}
  end
end

get '/' do
  my_env_config = ENV.to_h.select {|k, v| k =~ /^#{project.upcase}/ }.merge(live_config)
  data = my_env_config.merge ({
      name: project,
      env: environment
  })

  json(data)
end

get '/health_check' do
  "OK"
end
