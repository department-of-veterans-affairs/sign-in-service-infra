require 'sinatra/base'
require "sinatra/reloader"

require 'tilt/redcarpet'
require 'tilt/haml'
require 'redis'
require 'pg'

if ENV["RACK_ENV"] == "production"
  require "rack-json-logs"
else
  require 'byebug'
end

class App < Sinatra::Base
  configure :production do
    set :raise_errors, true
    set :logging, false
    set :dump_errors, false
    use Rack::JsonLogs
  end

  configure :development do
    register Sinatra::Reloader
  end

  set :redis, Redis.new(url: ENV.fetch('REDIS_URL'))

  def redis_status
    settings.redis.set(:success, "true")
    if settings.redis.get(:success) == "true"
      "Connected"
    else
      "Not connected"
    end
  rescue => e
    "Not connected: #{e.message}"
  end

  def postgres_status
    connection = PG.connect(ENV.fetch('DATABASE_URL'))
    query = connection.exec( "SELECT count(*) FROM pg_stat_activity" )
    if query.first["count"].nil? || query.first["count"].empty?
      "Not connected"
    else
      "Connected"
    end
  rescue => e
    "Not connected: #{e.message}"
  end

  get "/" do
    haml :home, layout_engine: :haml
  end

  get "/health" do
    status 200
  end
end
