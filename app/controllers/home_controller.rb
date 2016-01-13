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


  def login
    puts "login background page"

    ap session[:background]
  end

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

end
