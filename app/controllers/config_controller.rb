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
      session[:catalog] = 'off'

      # NEW FEATURES
      session[:medical_credentialing] = "off"
      session[:loan_docs] = "off"
      session[:upload_sign] = "off"
      session[:tax_return] = "off"
      session[:create_claim] = "off"
      session[:dicom_viewer] = "off"

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
      if (params[:navbar_color][0] == '#')
        session[:navbar_color] = params[:navbar_color]
      else
        session[:navbar_color] = '#' + params[:navbar_color]
      end
    end
    if !params[:catalog_file].nil? and params[:catalog_file] !=""
      session[:catalog_file] = params[:catalog_file]
    end

    # check feature tab configuration
    session[:resources] = !params[:resources].nil? ? 'on' : 'off'
    session[:onboarding] = !params[:onboarding].nil? ? 'on' : 'off'
    session[:medical_credentialing] = !params[:medical_credentialing].nil? ? 'on' : 'off'
    session[:loan_docs] = !params[:loan_docs].nil? ? 'on' : 'off'
    session[:upload_sign] = !params[:uploadsign].nil? ? 'on' : 'off'
    session[:tax_return] = !params[:taxreturn].nil? ? 'on' : 'off'
    session[:create_claim] = !params[:createclaim].nil? ? 'on' : 'off'
    # session[:dicom_viewer] = !params[:dicom_viewer].nil? ? 'on' : 'off'

    redirect_to config_path
  end

  # clear session
  def reset_config
    session.clear
    redirect_to config_path
  end

  private

  # construct configuration URL
  def config_url
    session[:config_url] = "#{ENV['ACTIVE_URL']}/"
    session[:config_url] << "?message=#{session[:home_message]}"
    session[:config_url] << "&logo=#{session[:logo]}"
    if(!session[:navbar_color].nil? && session[:navbar_color] != "")
      session[:config_url] << "&back_color=#{session[:navbar_color][1..-1]}"
    end
    session[:config_url] << "&vault=#{session[:vault]}"
    session[:config_url] << "&resources=#{session[:resources]}"
    session[:config_url] << "&onboarding=#{session[:onboarding]}"

    session[:config_url] << "&med_credentialing=#{session[:medical_credentialing]}"
    session[:config_url] << "&loan_docs=#{session[:loan_docs]}"
    session[:config_url] << "&background=#{session[:background]}"


    session[:config_url] << "&tax_return=#{session[:tax_return]}"
    session[:config_url] << "&upload_sign=#{session[:upload_sign]}"
    session[:config_url] << "&create_claim=#{session[:create_claim]}"
    # session[:config_url] << "&dicom_viewer=#{session[:dicom_viewer]}"


  end

end
