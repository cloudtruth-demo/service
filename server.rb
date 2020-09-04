require 'sinatra'
require 'sinatra/json'
require "sinatra/cors"
require "sinatra/reloader" if development?
require 'dotenv'
require 'open-uri'

Dotenv.load('.env.local', '.env')

set :allow_origin, "*"
set :allow_methods, "GET,HEAD,POST"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

def config_tid
  ENV['CONFIG_TID']
end

def environment
  ENV['SVC_ENV']
end

def live_config
  begin
    url = "https://ctcaas-graph.cloudtruth.com/t/#{config_tid}/#{environment}"
    return JSON.parse(open(url).read)
  rescue Exception => e
    return {"live_config_error" => "#{e.class}: #{e.message}"}
  end
end

get '/' do
  name = ENV['SVC_NAME']
  env = ENV['SVC_ENV']
  my_env_config = ENV.select {|k, v| k =~ /^#{name.upcase}/ }

  data = my_env_config.merge ({
      name: name,
      env: env
  })

  data = data.merge(live_config)

  json(data)
end
