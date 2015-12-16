class ConfigController < ApplicationController
  skip_before_filter :verify_authenticity_token
  # before_action :check_config


  def show

    puts "config page get..."

    # check if the tabs have been configured yet
    started = true

    if session[:vault].nil?
      session[:vault] = 'on'
      started = false
    end

    if(started == false)
      session[:vault] = 'on'
      session[:resources] = 'on'
      session[:onboarding] = 'on'
      session[:catalog] = 'on'

      # NEW BETA FEATURES
      session[:medical_credentialing] = "off"
      session[:loan_docs] = "off"

    end

    config_url
  end

  def post_config

    puts 'posting configuration page....'

    # check if new branding parameters were saved
    if !params[:message].nil? and params[:message] != ""
      session[:home_message] = params[:message]
    end
    if !params[:logo].nil? and params[:logo] != ""
      session[:logo] = params[:logo]
    end
    if !params[:backgroud].nil? and params[:background] != ""
      session[:background] = params[:background]
    end
    if !params[:navbar_color].nil? and params[:navbar_color] != ""
      session[:navbar_color] = '#' + params[:navbar_color]
    end
    # if !params[:catalog_file].nil? and params[:catalog_file] !=""
    #   session[:catalog_file] = params[:catalog_file]
    # end

    # check feature tab configuration
    if !params[:resources].nil?
      session[:resources] = 'on'
    else
      session[:resources] = 'off'
    end
    if !params[:onboarding].nil?
      session[:onboarding] = 'on'
    else
      session[:onboarding] = 'off'
    end
    if !params[:catalog].nil?
      session[:catalog] = 'on'
    else
      session[:catalog] = 'off'
    end
    if !params[:medical_credentialing].nil?
      session[:medical_credentialing] = 'on'
    else
      session[:medical_credentialing] = 'off'
    end
    if !params[:loan_docs].nil?
      session[:loan_docs] = 'on'
    else
      session[:loan_docs] = 'off'
    end


    redirect_to config_path
  end

  # clear session
  def reset_config
    session.clear
    redirect_to config_path
  end

  private

  # def set_gon
  #   gon.push
  #     puts "In GON............"
  #     current_catalog_file = session[:catalog_file]
  #     ap gon.current_catalog_file
  #
  # end


end
