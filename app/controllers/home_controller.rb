class HomeController < ApplicationController

  # before_action :check_config

  # List of DO NOT DELETEs
  # Credentialing Specialist - "CRED_SPECIALIST"
  # Matt - "CUSTOMER ID"
  # Credentialing Specialist = 260539217, cred-specialist@box.com
  DO_NOT_DELETE_IDS = [ENV['EMPL_ID'], ENV['CUSTOMER_ID'], ENV['CRED_SPECIALIST'],
                      '260539217', ENV['USER_DATA_ID']]

  def show
  end

  def login
    puts "login background page"
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
