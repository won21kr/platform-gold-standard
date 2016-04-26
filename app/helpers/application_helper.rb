module ApplicationHelper
  require 'json'

  def alert_class_for(flash_type)
    {
      :success => 'alert-success',
      :error => 'alert-danger',
      :alert => 'alert-warning',
      :notice => 'alert-info'
    }[flash_type.to_sym] || flash_type.to_s
  end

  def alt_text(text)
    return text if session[:alt_text_hash].nil?

    if session[:alt_text_hash].has_key? text
      session[:alt_text_hash][text]
    else
      text
    end
  end
end
