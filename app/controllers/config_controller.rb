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
    if(!session[:navbar_color].nil? && session[:navbar_color] != "")
      session[:config_url] << "&back_color=#{session[:navbar_color][1..-1]}"
    end

  end

  # fetches config query from encoded URL and updates the config session variables
  def insert_query(query)

    puts "insert query..."
    ap query

    if query['company'] != "" and query['company'] != nil
      session[:company] = query['company']
    end
    if query['logo'] != "" and query['logo'] != nil
      session[:logo] = query['logo']
    end
    if query['back_color'] != "" and query['back_color'] != nil
      session[:navbar_color] = '#' + query['back_color']
    end

    config_url
  end

end
