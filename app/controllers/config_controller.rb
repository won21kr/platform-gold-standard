class ConfigController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_action :check_config


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
    end
    # ap session

    config_url

  end

  def post_config

    puts 'posting configuration page....'

    # check if reset
    if !params[:reset].nil?
      session.clear
    end


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
    if !params[:catalog_file].nil? and params[:catalog_file] !=""
      session[:catalog_file] = params[:catalog_file]
    end

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

    redirect_to config_path
  end


  def reset_config
    session.clear
    puts "session reset..."
    ap session
    redirect_to config_path
  end

  private

  def check_config
    # check if query string exists
    if(params != "")
      insert_query(params)
    end

  end

  # construct configuration URL
  def config_url
    session[:config_url] = "#{ENV['ACTIVE_URL']}/"
    session[:config_url] << "?message=#{session[:home_message]}"
    session[:config_url] << "&logo=#{session[:logo]}"
    session[:config_url] << "&catalog=#{session[:catalog_file]}"
    if(!session[:navbar_color].nil? && session[:navbar_color] != "")
      session[:config_url] << "&back_color=#{session[:navbar_color][1..-1]}"
    end
    session[:config_url] << "&vault=#{session[:vault]}"
    session[:config_url] << "&resources=#{session[:resources]}"
    session[:config_url] << "&onboarding=#{session[:onboarding]}"
    session[:config_url] << "&catalog=#{session[:catalog]}"
    session[:config_url] << "&background=#{session[:background]}"

  end

  # fetches config query from encoded URL and updates the config session variables
  # for the Use Case of sending over a pre-populated config URL without having created a session
  def insert_query(query)

    puts "insert query..."
    ap query
    ap session[:catalog_file]
    ap session[:navbar_color]

    if query['message'] != "" and query['message'] != nil
      session[:home_message] = query['message']
    end
    if query['logo'] != "" and query['logo'] != nil
      session[:logo] = query['logo']
    end
    if query['back_color'] != "" and query['back_color'] != nil
      session[:navbar_color] = '#' + query['back_color']
    end
    if query['catalog1'] != "" and query['catalog1'] != nil
      session[:catalog_file] = query['catalog1']
    end
    if query['vault'] != "" and query['vault'] != nil
      session[:vault] = query['vault']
    end
    if query['resources'] != "" and query['resources'] != nil
      session[:resources] = query['resources']
    end
    if query['onboarding'] != "" and query['onboarding'] != nil
      session[:onboarding] = query['onboarding']
    end
    if query['catalog'] != "" and query['catalog'] != nil
      session[:catalog] = query['catalog']
    end
    if query['background'] != "" and query['background'] != nil
      session[:background] = query['background']
    end
    config_url
    set_gon
  end

  def set_gon
    gon.push
      puts "In GON............"
      current_catalog_file = session[:catalog_file]
      ap gon.current_catalog_file

  end


end
