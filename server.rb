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

def ctapi
  @ctapi ||= begin
    @ctapi_class = CtApi(api_key: ENV['CLOUDTRUTH_API_KEY'])
    @ctapi_class.new(environment: environment)
  end
end

def live_config
  begin
    params = ctapi.parameters(project: ENV['CLOUDTRUTH_PROJECT'])
    return Hash[params.collect {|p| [p.key, p.value] }]
  rescue Exception => e
    return {"live_config_error" => "#{e.class}: #{e.message}"}
  end
end

get '/' do
  name = ENV['SVC_NAME']
  env = ENV['SVC_ENV']
  my_env_config = ENV.to_h.merge(live_config).select {|k, v| k =~ /^#{name.upcase}/ }

  data = my_env_config.merge ({
      name: name,
      env: env
  })

  json(data)
end
