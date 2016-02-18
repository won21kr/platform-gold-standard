class AccountSubmissionController < SecuredController

  DOCUSIGN_CLIENT = DocusignRest::Client.new
  skip_before_filter :verify_authenticity_token

  def show

    client = user_client
    session[:current_page] = "account_sub"
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions"
    threads = []

    # get account submission folder, if it doesn't exist create one
    begin
      @accountFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/accountFolder", :expires_in => 10.minutes) do
        client.folder_from_path(path)
      end
      # @loanFolder = client.folder_from_path(path)
    rescue
      parent = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @accountFolder = client.create_folder("Account Submissions", parent)
    end

    # get all submission account files
    folderItems = client.folder_items(@accountFolder, fields: [:id, :name])
    @accountItems = folderItems.files
    @accountSubFolder = folderItems.folders

    if(@accountItems.size == 0 && @accountSubFolder.size == 0)
      # still need to upload items

      @status = "toUpload"
    elsif (@accountItems.size > 0)
      # uploaded account documents exist

      @status = "pendingApproval"
      @readyForPrequal = true

      # parse each file. get associated task and comments
      @accountItems.each do |file|

        threads << Thread.new do
          class << file
            attr_accessor :comments, :status
          end
          task = client.file_tasks(file, fields: [:is_completed]).first
          numComments = client.file_comments(file.id, fields: [:id]).size
          if(task.is_completed)
            status = "Approved"
          else
            status = "Pending"
            @readyForPrequal = false
          end
          file.status = status
          file.comments = numComments
        end
      end

      threads.each { |thr| thr.join }

    elsif (@accountSubFolder.size > 0)
      # documents were approved, parse folder

      @status = "approved"
      @approvedItems = client.folder_items(@accountSubFolder.first, fields: [:id, :name, :modified_at])
    end


    # # if one of the loan documents is "missing", then
    # # get vault folder and search for items by name
    # if (@docStatus["Loan Agreement"] == "Missing" or @docStatus["W2 Form"] == "Missing" or @docStatus["Tax Return"] == "Missing")
    #
    #   vaultFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
    #     puts "miss"
    #     client.folder_from_path("My Files")
    #   end
    #
    #   # search for loan related documents
    #   tmpSearchFiles = Rails.cache.fetch("/loan_docs_search/#{session[:box_id]}", :expires_in => 4.minutes) do
    #     puts "miss"
    #     client.search("W2 || Tax || Loan", content_types: :name, file_extensions: 'pdf', ancestor_folder_ids: vaultFolder.id)
    #   end
    #
    #   # parse through search results
    #   @searchFiles["W2"] = tmpSearchFiles.select {|item| item.name.include?("W2") }
    #   @searchFiles["Loan"] = tmpSearchFiles.select {|item| item.name.include?("Loan") }
    #   @searchFiles["Tax"] = tmpSearchFiles.select {|item| item.name.include?("Tax") }
    # end

  end

  # Upload a new file version
  def upload_new_version

    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions/" + params[:file].original_filename
    client = user_client

    file = client.file_from_id(params[:fileId], fields: [:id, :name])

    # get both old and new file extensions and check if they match
    newExt = params[:file].original_filename.split('.').last
    oldExt = file.name.split('.').last

    if (newExt == oldExt)
      temp_file = File.open(Rails.root.join('tmp', params[:file].original_filename), 'wb')

      begin
        temp_file.write(params[:file].read)
        temp_file.close
        version = client.upload_new_version_of_file(temp_file.path, file)
        flash[:notice] = "New file version uploaded for \"#{version.name}\""
      rescue => ex
        puts ex.message
      ensure
        File.delete(temp_file)
      end
    else
      flash[:notice] = "Error: you must upload a new file version of the same file type"
    end

    redirect_to "/account-submission"
  end

  # upload files to parameter specified folder ID
  def account_doc_upload

    puts "uploading file..."

    #http://www.dropzonejs.com/
    uploaded_file = params[:file]
    folder = params[:folder_id]
    client = user_client

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_file = client.upload_file(temp_file.path, folder)

      # create task
      msg = "Please review and complete the task"
      task = client.create_task(box_file, action: :review, message: msg)
      client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])

    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "Business application files submitted. Wait for company approval."

    respond_to do |format|
      format.json{ render :json => {} }
    end
  end

  def prequal_submit

    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions"

    @accountFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/accountFolder", :expires_in => 10.minutes) do
      client.folder_from_path(path)
    end
    items = client.folder_items(@accountFolder, fields: [:id, :name, :modified_at]).files
    folder = client.create_folder("Pre Qualification", @accountFolder)

    items.each do |f|
      client.move_file(f, folder)
    end
    flash[:notice] = "Business application submitted for Pre-Qualification"

    redirect_to "/account-submission"
  end

  # copy over a document from the user's vault to Loan Docs folder
  # def copy_from_vault
  #
  #   puts "copy from vault"
  #   fileId = params[:file_id]
  #   oldName = params[:old_name].split(".")
  #   newName = params[:new_name] + "." + oldName.last
  #   path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"
  #
  #   # get loan docs folder, copy vault file into it
  #   client = user_client
  #   folder = Rails.cache.fetch("/folder/#{session[:box_id]}/loan_folder", :expires_in => 10.minutes) do
  #     client.folder_from_path(path)
  #   end
  #   # folder = client.folder_from_path(path)
  #   toCopy = client.file_from_id(fileId, fields: [:name, :id])
  #   copiedFile = client.copy_file(toCopy, folder, name: newName)
  #
  #   # assign task to Box managed user
  #   msg = "Please review and complete the task"
  #   task = client.create_task(copiedFile, action: :review, message: msg)
  #   client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])
  #   flash[:notice] = "Successfully copied over \"#{oldName.first}\" from your vault"
  #
  #   redirect_to loan_docs_path
  # end

  # delete folder, reset loan process
  def reset_accts

    puts "reset accounts"

    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions"

    # get loan docs folder, copy vault file into it
    client = user_client
    folder = client.folder_from_path(path)
    items = client.folder_items(folder, fields: [:id])
    files = items.files
    folders = items.folders
    # client.delete_folder(folder, recursive: true)

    files.each do |f|
      client.delete_file(f)
    end

    folders.each do |f|
      client.delete_folder(f, recursive: true)
    end

    redirect_to acct_sub_path
  end




end
