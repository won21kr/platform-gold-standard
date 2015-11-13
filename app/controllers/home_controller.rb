class HomeController < ApplicationController

  before_action :check_config

  # List of DO NOT DELETEs
  # Matt, Juihee
  DO_NOT_DELETE_IDS = [ENV['EMPL_ID'], ENV['CUSTOMER_ID'], '254291677']

  def reset_logins
  @message = "This feature is currently disabled"
  begin
    box_admin = Box.admin_client

    num_deleted_logins = 0
    logins = Auth0API.client.users
    logins.each do |login|
      box_user_id = login["box_id"]

      unless DO_NOT_DELETE_IDS.include? box_user_id
        begin
          box_admin.delete_user(box_user_id, notify: false, force: true)
          Auth0API.client.delete_user(login["user_id"])
          num_deleted_logins += 1
        rescue
        end
      end
    end

    @message = "Successfully deleted #{num_deleted_logins} logins."
  rescue => ex
    @message = ex.message
  end
end

  def logout
    reset_session
    redirect_to home_path
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
