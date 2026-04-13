module ClienteAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_cliente_authentication
    helper_method :cliente_authenticated?, :current_cliente
  end

  class_methods do
    def allow_unauthenticated_cliente_access(**options)
      skip_before_action :require_cliente_authentication, **options
    end
  end

  private

  def cliente_authenticated?
    resume_cliente_session
  end

  def current_cliente
    Current.cliente
  end

  def require_cliente_authentication
    resume_cliente_session || request_cliente_authentication
  end

  def resume_cliente_session
    Current.cliente_session ||= find_cliente_session_by_cookie
  end

  def find_cliente_session_by_cookie
    ClienteSession.find_by(id: cookies.signed[:cliente_session_id]) if cookies.signed[:cliente_session_id]
  end

  def request_cliente_authentication
    session[:return_to_after_cliente_authenticating] = request.url
    redirect_to new_session_path
  end

  def after_cliente_authentication_url
    session.delete(:return_to_after_cliente_authenticating) || cuenta_root_url
  end

  def start_new_cliente_session_for(cliente)
    cliente.cliente_sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |cs|
      Current.cliente_session = cs
      cookies.signed.permanent[:cliente_session_id] = { value: cs.id, httponly: true, same_site: :lax }
    end
  end

  def terminate_cliente_session
    Current.cliente_session.destroy
    cookies.delete(:cliente_session_id)
  end
end
