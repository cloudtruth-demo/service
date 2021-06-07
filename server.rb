$stdout.sync = true

require 'sinatra'
require 'sinatra/json'
require "sinatra/reloader" if development?
require 'dotenv'
require 'open-uri'

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'ctapi'

Dotenv.load('.env.local', '.env')

require 'rack/cors'
use Rack::Cors do
  allow do
    origins '*'
    resource '*',  headers: :any, methods: [:get, :options, :head]
  end
end
set :protection, :except => [:json_csrf]

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
    $stderr.puts e.backtrace
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
