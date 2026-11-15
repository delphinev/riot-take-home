# Request bodies are read only through StrictJson. Rails would otherwise parse
# JSON bodies into params as well, and reject some of them (invalid UTF-8)
# before the controller, in its own format and logging the offending value.
ActionDispatch::Request.parameter_parsers = ActionDispatch::Request.parameter_parsers.except(:json)
