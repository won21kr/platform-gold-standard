class HomeController < ApplicationController

  DO_NOT_DELETE_IDS = [ENV['AGENT_ID1'],ENV['AGENT_ID2'], ENV['AGENT_ID3'], ENV['RUSER_ID']]

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
end
