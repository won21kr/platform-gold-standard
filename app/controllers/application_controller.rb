class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper :all
  helper_method :get_task_status, :get_med_task_status
  before_action :check_config

  # def get_task_status
  #
  #   if (session[:task_status].nil?)
  #     puts "getting task status"
  #     client = user_client
  #     # get workflow folder paths
  #     path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
  #     completedPath = "#{path}/Completed/"
  #
  #     completedFolder = Rails.cache.fetch("/folder/#{completedPath}", :expires_in => 15.minutes) do
  #       client.folder_from_path(completedPath)
  #     end
  #
  #     if((file = client.folder_items(completedFolder, fields: [:id]).files).size > 0)
  #       session[:task_status] = 0
  #     else
  #       session[:task_status] = 1
  #     end
  #   end
  #
  #   session[:task_status]
  # end

  # get med credential workflow status
  def get_med_task_status

    client = user_client
    puts "get med task status"

    # if the medical credentialing form doc has been generated, check if the task has been approved
    begin
      taskFile = client.file_from_path("#{session[:userinfo]['info']['name']}\ -\ Medical\ Credentialing/Medical\ Application\ Form.pdf")
      task = client.file_tasks(taskFile, fields: [:is_completed])
    rescue
      puts "file doesn't exist yet..."
    end
    ap task

    if(task.nil?)
      session[:med_task_status] = 1
    elsif(task.first.is_completed == false)
      session[:med_task_status] = 1
    elsif(task.first.is_completed == true)
      session[:med_task_status] = 0
    else
      session[:med_task_status] = 1
    end

    session[:med_task_status]
  end

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end


  private

  def check_config
    # check if query string exists
    if(params != "")
      puts "params not nil, insert query if it exists"
      insert_query(params)
    end

  end

  # fetches config query from encoded URL and updates the config session variables
  def insert_query(query)

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
    if query['med_credentialing'] != "" and query['med_credentialing'] != nil
      session[:medical_credentialing] = query['med_credentialing']
    end
    if query['loan_docs'] != "" and query['loan_docs'] != nil
      session[:loan_docs] = query['loan_docs']
    end
    if query['background'] != "" and query['background'] != nil
      session[:background] = query['background']
    end
    if query['catalog_file'] != "" and query['catalog_file'] != nil
      session[:catalog_file] = query['catalog_file']
    end
    if query['upload_sign'] != "" and query['upload_sign'] != nil
      session[:upload_sign] = query['upload_sign']
    end
    if query['salesforce'] != "" and query['salesforce'] != nil
      session[:salesforce] = query['salesforce']
    end
    if query['tax_return'] != "" and query['tax_return'] != nil
      session[:tax_return] = query['tax_return']
    end
  end

end
