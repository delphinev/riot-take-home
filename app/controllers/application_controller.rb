class ApplicationController < ActionController::API
  before_action :require_json_content_type

  rescue_from StrictJson::ParseError do |error|
    render_error :bad_request, "invalid_json", "request body #{error.message}"
  end

  private

  def require_json_content_type
    return if request.media_type == "application/json"

    render_error :unsupported_media_type, "unsupported_media_type", "Content-Type must be application/json"
  end

  def json_body
    @json_body ||= StrictJson.parse(request.raw_post)
  end

  def render_error(status, code, message)
    render status:, json: { error: { code:, message: } }
  end
end
