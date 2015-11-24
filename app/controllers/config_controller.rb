class ConfigController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_action :check_config


  def show

    # check if reset
    if !params[:reset].nil?
      session.clear
    end


    # check if new branding parameters were saved
    if !params[:company].nil? and params[:company] != ""
      session[:company] = params[:company]
    end
    if !params[:logo].nil? and params[:logo] != ""
      session[:logo] = params[:logo]
    end
    if !params[:navbar_color].nil? and params[:navbar_color] != ""
      session[:navbar_color] = '#' + params[:navbar_color]
    end
    if !params[:catalog_file].nil? and params[:catalog_file] !=""
      session[:catalog_file] = params[:catalog_file]
    end

    config_url
    #ap session
  end


  def reset_config
    session.clear
    puts "session reset..."
    redirect_to config_url
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
    session[:config_url] << "?company=#{session[:company]}"
    session[:config_url] << "&logo=#{session[:logo]}"
    session[:config_url] << "&catalog=#{session[:catalog_file]}"
    if(!session[:navbar_color].nil? && session[:navbar_color] != "")
      session[:config_url] << "&back_color=#{session[:navbar_color][1..-1]}"
    end

  end

  # fetches config query from encoded URL and updates the config session variables
  # for the Use Case of sending over a pre-populated config URL without having created a session
  def insert_query(query)

    puts "insert query..."
    ap query
    ap session[:catalog_file]
    ap session[:navbar_color]

    if query['company'] != "" and query['company'] != nil
      session[:company] = query['company']
    end
    if query['logo'] != "" and query['logo'] != nil
      session[:logo] = query['logo']
    end
    if query['back_color'] != "" and query['back_color'] != nil
      session[:navbar_color] = '#' + query['back_color']
    end
    if query['catalog'] != "" and query['catalog'] != nil
      session[:catalog_file] = query['catalog']
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
