class HomeController < ApplicationController

  # before_action :check_config

  # List of DO NOT DELETEs
  # Credentialing Specialist - "CRED_SPECIALIST"
  # Matt - "CUSTOMER ID"
  # Juihee = 254291677, juihee1@test.com
  # Matt Marque = 257524801, wolterskluwer@box.com
  # Sam Peters = 258215985,  speters+demo@box.com
  # Credentialing Specialist = 260539217, cred-specialist@box.com
  DO_NOT_DELETE_IDS = [ENV['EMPL_ID'], ENV['CUSTOMER_ID'], ENV['CRED_SPECIALIST'],
                      '254291677', '257524801', '258215985', '260539217']


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
          deleted = box_admin.delete_user(box_user_id, notify: false, force: true)
          puts "deleting user #{box_user_id}"
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
    session[:userinfo] = nil
    session[:task_status] = nil
    session[:med_task_status] = nil
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
    session[:config_url] << "?message=#{session[:home_message]}"
    session[:config_url] << "&logo=#{session[:logo]}"
    if(!session[:navbar_color].nil? && session[:navbar_color] != "")
      session[:config_url] << "&back_color=#{session[:navbar_color][1..-1]}"
    end
    session[:config_url] << "&vault=#{session[:vault]}"
    session[:config_url] << "&resources=#{session[:resources]}"
    session[:config_url] << "&onboarding=#{session[:onboarding]}"
    session[:config_url] << "&catalog=#{session[:catalog]}"
    session[:config_url] << "&background=#{session[:background]}"
    session[:config_url] << "&salesforce=#{session[:salesforce]}"

  end

  # fetches config query from encoded URL and updates the config session variables
  def insert_query(query)

    puts "insert query..."
    ap query

    if query['message'] != "" and query['message'] != nil
      session[:home_message] = query['message']
    end
    if query['logo'] != "" and query['logo'] != nil
      session[:logo] = query['logo']
    end
    if query['back_color'] != "" and query['back_color'] != nil
      session[:navbar_color] = '#' + query['back_color']
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
    if query['salesforce'] != "" and query['salesforce'] != nil
      session[:salesforce] = query['salesforce']
    end
    config_url
  end
end
