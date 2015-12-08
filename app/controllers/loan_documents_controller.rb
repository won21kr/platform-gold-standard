class LoanDocumentsController < SecuredController


  def show

    client = user_client
    session[:current_page] = "loan_docs"
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"
    docStatus = Hash.new
    @docStatus = {"Loan Agreement" => "Missing", "W2 Form" => "Missing",
                  "Tax Return" => "Missing", "Loan Image" => "file_toupload.png",
                  "W2 Image" => "file_toupload.png", "Tax Image" => "file_toupload.png"}
    @fileId = {"Loan Agreement" => nil, "W2 Form" => nil,
               "Tax Return" => nil}
    @searchFiles = {"Loan" => nil, "W2" => nil, "Tax" => nil}

    # get loan documents folder, if it doesn't exist create one
    begin
      @loanFolder = client.folder_from_path(path)
    rescue
      parent = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      @loanFolder = client.create_folder("Loan Documents", parent)
      # client.add_collaboration(@loanFolder, {id: ENV['EMPL_ID'], type: :user}, :viewer)
      puts "created new loan docs folder..."
    end

    @loanItems = client.folder_items(@loanFolder, fields: [:id, :name, :modified_at])

    # iterate throug loan folder to check out documents
    @loanItems.each do |file|

      name = file.name.split(".").first
      imageName = name.split(" ").first + " Image"
      searchName = name.split(" ").first

      task = client.file_tasks(file, fields: [:is_completed]).first

      if(task != nil and task.is_completed)
        @docStatus[name] = "Accepted"
        @docStatus[imageName] = "file_success.png"
        @fileId[name] = file.id
      elsif(task != nil and !task.is_completed)
        #task not completed yet
        @docStatus[name] = "Received #{DateTime.strptime(file.modified_at).strftime("%m/%d/%y at %l:%M %p")}; In review"
        @docStatus[imageName] = "file_process.png"
        @fileId[name] = file.id

      else
        puts  "Error: should never be here!"

      end

    end
    # get vault folder and search for items
    vaultId = client.folder_from_path("My Files").id

    if (@docStatus["Loan Agreement"] == "Missing")
      @searchFiles["Loan"] = client.search("Loan", content_types: :name, ancestor_folder_ids: vaultId)
    end
    if (@docStatus["W2 Form"] == "Missing")
      @searchFiles["W2"] = client.search("W2", content_types: :name, ancestor_folder_ids: vaultId)
    end
    if (@docStatus["Tax Return"] == "Missing")
      @searchFiles["Tax"] = client.search("Tax", content_types: :name, ancestor_folder_ids: vaultId)
    end

    ap @searchFiles

  end

  # upload files to parameter specified folder ID
  def loan_upload

    puts "uploading file..."

    #http://www.dropzonejs.com/
    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"

    uploaded_file = params[:file]
    name = params[:file_name]
    fileName = params[:file_name]

    folder = client.folder_from_path(path)

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_user = Box.user_client(session[:box_id])
      box_file = client.upload_file(temp_file.path, folder)

      ext = box_file.name.split(".").last
      fileName = fileName + "." + ext

      uploadedFile = client.update_file(box_file, name: fileName)
      # client.create_metadata(uploadedFile, "Status" => "In Review")
      msg = "Please review and complete the task"
      task = client.create_task(uploadedFile, action: :review, message: msg)
      client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])
      #box_user.create_metadata(box_file, session[:meta])

    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "#{name} Successfully Uploaded!"
    respond_to do |format|
      format.json{ render :json => {} }
    end
  end

  def copy_from_vault

    puts "copy from vault"
    fileId = params[:file_id]
    oldName = params[:old_name].split(".")
    newName = params[:new_name] + "." + oldName.last

    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"

    # get loan docs folder, copy vault file into it
    client = user_client
    folder = client.folder_from_path(path)
    toCopy = client.file_from_id(fileId, fields: [:name, :id])

    copiedFile = client.copy_file(toCopy, folder, name: newName)
    # client.create_metadata(uploadedFile, "Status" => "In Review")

    msg = "Please review and complete the task"
    task = client.create_task(copiedFile, action: :review, message: msg)
    client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])
    flash[:notice] = "Successfully copied over \"#{oldName.first}\" from your vault"

    redirect_to loan_docs_path
  end

  def reset_loan
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"

    # get loan docs folder, copy vault file into it
    client = user_client
    folder = client.folder_from_path(path)
    client.delete_folder(folder, recursive: true)

    redirect_to loan_docs_path

  end


end
