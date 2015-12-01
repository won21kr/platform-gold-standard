class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper :all
  helper_method :get_task_status
  before_action :check_config

  def get_task_status

    if (session[:task_status].nil?)
      puts "getting task status"
      client = user_client
      # get workflow folder paths
      path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
      completedPath = "#{path}/Completed/"

      completedFolder = Rails.cache.fetch("/folder/#{completedPath}", :expires_in => 15.minutes) do
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


  private

  def check_config
    # check if query string exists
    if(params != "")
      insert_query(params)
    end

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
  end

end
