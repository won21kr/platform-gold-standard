class MessagingSystemController < ApplicationController

  skip_before_filter :verify_authenticity_token

  def show
    session[:current_page] = "messaging_system"
    client = user_client


    # fetch parent messages folder and individual messages subfolders
    # if no parent "Messages" folder exists, create one
    begin
      @messagesFolder = Rails.cache.fetch("/messages-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Messages Folder")
      end

      @messages = client.folder_items(@messagesFolder, fields: [:id, :name, :description])

    rescue
      puts "folder not yet created, create"
      sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @messagesFolder = client.create_folder("Messages Folder", sharedFolder)
      @messages = []
    end

  end

  # compose message page controller
  # just re-fetch the messages to populate the sent value
  def compose_message

    client = user_client

    # fetch parent messages folder and individual messages subfolders
    # if no parent "Messages" folder exists, create one
    begin
      @messagesFolder = Rails.cache.fetch("/messages-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Messages Folder")
      end

      @messages = client.folder_items(@messagesFolder, fields: [:id, :name, :description])

    rescue
      puts "folder not yet created, create"
      sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @messagesFolder = client.create_folder("Messages Folder", sharedFolder)
      @messages = []
    end

  end

  # create message folder, upload documents, and invite collaborator
  def save_message

    message = params[:message]
    subject = params[:subject]
    files = params[:files]
    client = user_client

    # fetch parent messages folder
    begin
      @messagesFolder = Rails.cache.fetch("/messages-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Messages Folder")
      end
    rescue
      puts "Error should never be here"
    end

    # Create new message folder and add message into folder description
    newMessageFolder = client.create_folder(subject, @messagesFolder)
    client.update_folder(newMessageFolder, description: message)

    # upload each file to new message folder
    files.each do |file|
      ap file.original_filename
      file = client.upload_file(file.tempfile, newMessageFolder, name: file.original_filename)
    end

    redirect_to messaging_system_path
  end

  # delete message
  def delete_message

    client = user_client
    folderId = params[:id]

    client.delete_folder(folderId, recursive: true)

    redirect_to messaging_system_path
  end

  # show message thread
  def show_message

    client = user_client
    folderId = params[:id]

    # fetch parent messages folder and individual messages subfolders
    # if no parent "Messages" folder exists, create one
    begin
      @messagesFolder = Rails.cache.fetch("/messages-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Messages Folder")
      end

      @message = client.folder_from_id(folderId, fields: [:id, :name, :description, :created_by])
      @files = client.folder_items(folderId, fields: [:id, :name])

    rescue
      puts "Error should never be here"
      @files = []
    end

  end

  def preview
    client = user_client
    folderId = params[:id]
    begin
      @messagesFolder = Rails.cache.fetch("/messages-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Messages Folder")
      end

      @preview_url = client.embed_url(folderId)
      ap @preview_url

    rescue
      puts "Error should never be here"
      @files = []
    end
  end


end
