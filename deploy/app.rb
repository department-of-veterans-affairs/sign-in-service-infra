require "sinatra"
require "json"

get "/" do
  content_type :json
  { message: "Hi, I am an Ingress point and I have created an ALB for you to use.", timestamp: Time.now.to_i }.to_json
end

set :bind, "0.0.0.0"
set :port, 5000
