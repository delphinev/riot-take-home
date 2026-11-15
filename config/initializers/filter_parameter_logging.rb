# Be sure to restart your server when you modify this file.

# Every value is filtered from the logs: request bodies are the data this API
# encrypts and signs, so any key may hold something sensitive.
Rails.application.config.filter_parameters = [ /.*/ ]
