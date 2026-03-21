import Config

config :ex_gram,
  token: "replace_me"

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
