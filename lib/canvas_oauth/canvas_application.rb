module CanvasOauth
  module CanvasApplication
    extend ActiveSupport::Concern

    module ClassMethods
    end

    included do
      helper_method :canvas

      rescue_from CanvasApi::Authenticate, with: :reauthenticate
      rescue_from CanvasApi::Unauthorized, with: :unauthorized_canvas_access

      before_action :request_canvas_authentication
    end

    protected
    def initialize_canvas
      tool_detail = LtiProviderTool.where(uuid: session[:key]).first
      organization_id = tool_detail.organization_id
      @canvas = ::CanvasOauth::CanvasApiExtensions.build(canvas_url, user_id, tool_consumer_instance_guid, organization_id, session[:key])
    end

    def canvas
      @canvas || initialize_canvas
    end

    def canvas_token
      CanvasOauthAuthorization.authorize_an_user(user_id, tool_consumer_instance_guid, session[:key])
    end

    def request_canvas_authentication
      if !params[:code].present? && !canvas_token.present?
        session[:oauth2_state] = SecureRandom.urlsafe_base64(24)
        # Form redirect uri
        redirect_url = canvas_oauth_url + "?redirect_to=#{response.request.fullpath}"
        redirect_to canvas.auth_url(redirect_url, session[:oauth2_state])
      end
    end

    def not_acceptable
      render text: "Unable to process request", status: 406
    end

    def unauthorized_canvas_access
      render text: "Your Canvas Developer Key is not authorized to access this data.", status: 401
    end

    def reauthenticate
      ::CanvasOauth::Authorization.clear_tokens(user_id, tool_consumer_instance_guid)
      request_canvas_authentication
    end

    # these next three methods rely on external session data and either need to
    # be overridden or the session data needs to be set up by the time the
    # oauth filter runs (like with the lti_provider_engine)

    def canvas_url
      session[:canvas_url]
    end

    def user_id
      session[:user_id]
    end

    def tool_consumer_instance_guid
      session[:tool_consumer_instance_guid]
    end
  end
end
