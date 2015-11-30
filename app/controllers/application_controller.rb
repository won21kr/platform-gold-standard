class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper :all
  helper_method :get_task_status

  def get_task_status

    if (session[:task_status].nil?)
      puts "getting task status"
      client = user_client
      # get workflow folder paths
      path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
      completedPath = "#{path}/Completed/"

      completedFolder = Rails.cache.fetch("/staging/folder/#{completedPath}", :expires_in => 20.minutes) do
        client.folder_from_path(completedPath)
      end

      if((file = client.folder_items(completedFolder, fields: [:id]).files).size > 0)
        session[:task_status] = 0
      else
        session[:task_status] = 1
      end
    end

    session[:task_status]
  end

end
