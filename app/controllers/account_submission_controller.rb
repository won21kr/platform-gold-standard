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

    # get all account folders
    @accounts = client.folder_items(@accountFolder, fields: [:id, :name, :description, :modified_at]).folders

    # check the status of each accounts folder
    @accounts.each do |f|
      class << f
        attr_accessor :status
      end

      if (f.name.include? "(Submitted)")
        f.status = "Submitted"
        f.name = f.name.split("(").first
      else
        f.status = "Pending"
      end

    end

  end

  def create_acct
    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions"


    # get account submission folder
    begin
      @accountsFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/accountFolder", :expires_in => 10.minutes) do
        client.folder_from_path(path)
      end
    rescue
      puts "Error: should never be here"
    end

    # create new acct submission folder, check if same folder name already exists
    begin
      @newAccount = client.create_folder(params["name"], @accountsFolder)
      client.update_folder(@newAccount, description: params["address"])
    rescue
      flash[:notice] = "Error: account with the same name already exists"
      redirect_to "/account-submission"
    end

  end

  def list_account
    client = user_client
    session[:current_page] = "account_sub"
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions"
    threads = []

    # get account submission folder
    begin
      @accountFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/accountFolder/#{params[:id]}", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_id(params[:id], fields: [:id, :name, :description])
      end
      # @loanFolder = client.folder_from_path(path)
    rescue
      puts "should not be here"
      flash[:notice] = "Error: something went wrong"
      redirect_to "/account-submission"
    end

    # get all submission account files
    @accountItems = client.folder_items(@accountFolder, fields: [:id, :name]).files
    @readyForSubmit = true

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
          @readyForSubmit = false
        end
        file.status = status
        file.comments = numComments
      end
    end

    threads.each { |thr| thr.join }

    # check if account has been submitted
    if (@accountFolder.name.include? "(Submitted)")
      @readyForSubmit = false
      @submitted = true
    end

  end

  # Upload a new file version
  def upload_new_version

    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions/" + params[:file].original_filename
    client = user_client

    ap params

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

    redirect_to "/account-submission/list-acct/#{params[:id]}"
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
    # get account submission folder
    begin
      @accountFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/accountFolder/#{params[:folderId]}", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_id(params[:id], fields: [:id, :name, :description])
      end
      client.update_folder(@accountFolder, name: "#{@accountFolder.name} (Submitted)")
      # @loanFolder = client.folder_from_path(path)
    rescue
      puts "should not be here"
      flash[:notice] = "Error: something went wrong"
      redirect_to "/account-submission"
    end

    Rails.cache.delete("/folder/#{session[:box_id]}/accountFolder/#{params[:folderId]}")
    flash[:notice] = "Business application submission complete"

    redirect_to "/account-submission/list-acct/#{params[:folderId]}"
  end


  # delete account folders, reset process
  def reset_accts

    puts "reset accounts"

    path = "#{session[:userinfo]['info']['name']} - Shared Files/Account Submissions"
    client = user_client

    # get account submission folder
    begin
      @accountFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/accountFolder", :expires_in => 10.minutes) do
        client.folder_from_path(path)
      end
      # get all account folders
      @accounts = client.folder_items(@accountFolder, fields: [:id, :name, :description, :modified_at]).folders
      @accounts.each do |f|
        client.delete_folder(f, recursive: true)
      end
    rescue
      puts "should not be here"
      flash[:notice] = "Error: something went wrong"
      redirect_to "/account-submission"
    end

    redirect_to acct_sub_path
  end




end
