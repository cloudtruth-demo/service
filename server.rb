require 'sinatra'
require 'sinatra/json'
require "sinatra/cors"
require "sinatra/reloader" if development?
require 'dotenv'

Dotenv.load('.env.local', '.env')

set :allow_origin, "*"
set :allow_methods, "GET,HEAD,POST"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

get '/' do
  name = ENV['SVC_NAME']
  env = ENV['SVC_ENV']
  my_env_config = ENV.select {|k, v| k =~ /^#{name.upcase}/ }

  data = my_env_config.merge ({
      name: name,
      env: env
  })

  json(data)
end

get '/config' do
  # curl cloudtruth
end
