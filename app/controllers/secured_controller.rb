class SecuredController < ApplicationController

  before_action :logged_in_using_omniauth?

  private

  def logged_in_using_omniauth?
    ap session[:userinfo]
    unless session[:userinfo].present?
      redirect_to '/'
    end
  end

end
