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

      @collaborators = Rails.cache.fetch("/messages-folder/#{session[:box_id]}/collaborators/#{@messagesFolder.id}", :expires_in => 15.minutes) do
        client.folder_collaborations(@messagesFolder, fields: [:accessible_by])
      end

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

      @messages = Rails.cache.fetch("/messages-folder/#{session[:box_id]}/all-messages/#{@messagesFolder.id}", :expires_in => 15.minutes) do
        client.folder_items(@messagesFolder, fields: [:id, :name, :description])
      end

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
    threads = []

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

    # upload each file to new message folder, multithreaded
    files.each do |file|
      threads << Thread.new do
        file = client.upload_file(file.tempfile, newMessageFolder, name: file.original_filename)
      end
    end

    # Upload new txt file for attaching comments
    # and attach message as first comment
    threads << Thread.new do
      file = File.open("Messages.txt", "w")
      file.write("Message Thread File")
      messagesFile = client.upload_file(file, newMessageFolder)
      client.add_comment_to_file(messagesFile, message: message)
      file.close
    end

    # rejoin all threads
    threads.each { |thr| thr.join }

    redirect_to messaging_system_path
  end

  # delete message
  def delete_message

    client = user_client
    folderId = params[:id]

    # delete message
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

      # get total number of messages in "Sent" folder
      @sentMessages = Rails.cache.fetch("/messages-folder/#{session[:box_id]}/all-messages/#{@messagesFolder.id}", :expires_in => 15.minutes) do
        client.folder_items(@messagesFolder, fields: [:id, :name, :description])
      end

      # fetch current displayed message folder and attachment files
      @message = Rails.cache.fetch("/messages-folder/#{session[:box_id]}/current-message/#{folderId}", :expires_in => 15.minutes) do
        client.folder_from_id(folderId, fields: [:id, :name, :description, :created_by])
      end
      @files = Rails.cache.fetch("/messages-folder/#{session[:box_id]}/current-message/#{folderId}/items", :expires_in => 15.minutes) do
        client.folder_items(folderId, fields: [:id, :name])
      end

      # Fetch message thread from file comments
      @messageThreadFile = @files.select{|file| file.name == "Messages.txt"}.first
      @messageThread = client.file_comments(@messageThreadFile)

      @collaborators = Rails.cache.fetch("/messages-folder/#{session[:box_id]}/collaborators/#{@messagesFolder.id}", :expires_in => 15.minutes) do
        client.folder_collaborations(@messagesFolder, fields: [:accessible_by])
      end

    rescue
      puts "Error should never be here"
      @files = []
    end

  end

  # post message
  def post_message

    folderId = params[:messageId]
    fileId = params[:threadFileId]
    message = params[:message]
    client = user_client

    # attach new comment
    client.add_comment_to_file(fileId, message: message)

    redirect_to show_message_path(folderId)
  end

end
