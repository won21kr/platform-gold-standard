class LoanDocumentsController < SecuredController

  DOCUSIGN_CLIENT = DocusignRest::Client.new
  skip_before_filter :verify_authenticity_token

  def show

    client = user_client
    session[:current_page] = "loan_docs"
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"
    docStatus = Hash.new
    threads = []
    mixpanel_tab_event("Loan Origination", "Main Page")

    # intitialize doc hash maps to be referenced in the view
    @docStatus = {"Loan Agreement" => "Missing", "W2 Form" => "Missing",
                  "Tax Return" => "Missing", "Loan Image" => "file_toupload.png",
                  "W2 Image" => "file_toupload.png", "Tax Image" => "file_toupload.png"}
    @fileId = {"Loan Agreement" => nil, "W2 Form" => nil,
               "Tax Return" => nil}
    @searchFiles = {"Loan" => nil, "W2" => nil, "Tax" => nil}
    @fileComments = {"Loan" => nil, "W2" => nil, "Tax" => nil}

    # get loan documents folder, if it doesn't exist create one
    begin
      @loanFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/loan_folder", :expires_in => 10.minutes) do
        client.folder_from_path(path)
      end
      # @loanFolder = client.folder_from_path(path)
    rescue
      parent = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @loanFolder = client.create_folder("Loan Documents", parent)
    end

    # get all loan doc folder items
    @loanItems = client.folder_items(@loanFolder, fields: [:id, :name, :modified_at])

    # iterate through loan folder to check out documents w/ multithreading
    @loanItems.each do |file|

      threads << Thread.new do
        # configure names and get file task if exists
        name = file.name.split(".").first
        imageName = name.split(" ").first + " Image"
        searchName = name.split(" ").first

        if (name == "Loan Agreement - Signature Needed")
          @docStatus["Loan Agreement"] = "Signature Needed"
          @docStatus[imageName] = "file_process.png"
          @fileId["Loan Agreement"] = file.id
          # @fileComments[searchName] = client.file_comments(file.id, fields: [:id]).size
        elsif(name == "Loan Agreement - Completed")
          @docStatus["Loan Agreement"] = "Completed"
          @docStatus[imageName] = "file_success.png"
          @fileId["Loan Agreement"] = file.id
          # @fileComments[searchName] = client.file_comments(file.id, fields: [:id]).size
        else
          # document is either w2 or tax doc. Get file tasks and comments
          task = client.file_tasks(file, fields: [:is_completed]).first
          @fileComments[searchName] = client.file_comments(file.id, fields: [:id]).size
          if(task != nil and task.is_completed)
            # task completed
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
      end
    end

    threads.each { |thr| thr.join }

    # if one of the loan documents is "missing", then
    # get vault folder and search for items by name
    if (@docStatus["Loan Agreement"] == "Missing" or @docStatus["W2 Form"] == "Missing" or @docStatus["Tax Return"] == "Missing")

      vaultFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("My Files")
      end

      # search for loan related documents
      tmpSearchFiles = Rails.cache.fetch("/loan_docs_search/#{session[:box_id]}", :expires_in => 4.minutes) do
        puts "miss"
        client.search("W2 || Tax || Loan", content_types: :name, file_extensions: 'pdf', ancestor_folder_ids: vaultFolder.id)
      end

      # parse through search results
      @searchFiles["W2"] = tmpSearchFiles.select {|item| item.name.upcase.include?("w2".upcase) }
      @searchFiles["Loan"] = tmpSearchFiles.select {|item| item.name.upcase.include?("loan".upcase) }
      @searchFiles["Tax"] = tmpSearchFiles.select {|item| item.name.upcase.include?("tax".upcase) }
    end

  end

  # upload files to parameter specified folder ID
  def loan_upload

    puts "uploading file dropzone..."

    #http://www.dropzonejs.com/
    mixpanel_tab_event("Loan Origination", "Upload Document")
    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"

    uploaded_file = params[:file]
    name = params[:file_name]
    fileName = params[:file_name]

    folder = Rails.cache.fetch("/folder/#{session[:box_id]}/loan_folder", :expires_in => 10.minutes) do
      client.folder_from_path(path)
    end

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_user = Box.user_client(session[:box_id])
      box_file = client.upload_file(temp_file.path, folder)

      ext = box_file.name.split(".").last
      fileName = fileName + "." + ext

      uploadedFile = client.update_file(box_file, name: fileName)
      msg = "Please review and complete the task"
      task = client.create_task(uploadedFile, action: :review, message: msg)
      client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])

    rescue => ex
      puts 'error uploading'
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "#{name} Successfully Uploaded!"
    respond_to do |format|
      # ap format
      format.json{ render :json => {} }
    end
  end

  # upload files to parameter specified folder ID
  def loan_post

    puts "uploading - file picker..."

    #http://www.dropzonejs.com/
    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"
    mixpanel_tab_event("Loan Origination", "Upload Document")

    uploaded_file = params[:file]
    name = params[:file_name]
    fileName = params[:file_name]

    folder = Rails.cache.fetch("/folder/#{session[:box_id]}/loan_folder", :expires_in => 10.minutes) do
      client.folder_from_path(path)
    end

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_user = Box.user_client(session[:box_id])
      box_file = client.upload_file(temp_file.path, folder)

      ext = box_file.name.split(".").last
      fileName = fileName + "." + ext

      uploadedFile = client.update_file(box_file, name: fileName)
      msg = "Please review and complete the task"
      task = client.create_task(uploadedFile, action: :review, message: msg)
      client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])

    rescue => ex
      puts 'error'
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "#{name} Successfully Uploaded!"
    redirect_to loan_docs_path
  end

  # copy over a document from the user's vault to Loan Docs folder
  def copy_from_vault

    puts "copy from vault"
    mixpanel_tab_event("Loan Origination", "Copy Doc From Vault")
    fileId = params[:file_id]
    oldName = params[:old_name].split(".")
    newName = params[:new_name] + "." + oldName.last
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"

    # get loan docs folder, copy vault file into it
    client = user_client
    folder = Rails.cache.fetch("/folder/#{session[:box_id]}/loan_folder", :expires_in => 10.minutes) do
      client.folder_from_path(path)
    end
    # folder = client.folder_from_path(path)
    toCopy = client.file_from_id(fileId, fields: [:name, :id])
    copiedFile = client.copy_file(toCopy, folder, name: newName)

    # assign task to Box managed user
    msg = "Please review and complete the task"
    task = client.create_task(copiedFile, action: :review, message: msg)
    client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])
    flash[:notice] = "Successfully copied over \"#{oldName.first}\" from your vault"

    redirect_to loan_docs_path
  end

  # delete folder, reset loan process
  def reset_loan
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"

    # get loan docs folder, copy vault file into it
    client = user_client
    mixpanel_tab_event("Loan Origination", "Reset Workflow")
    folder = client.folder_from_path(path)
    items = client.folder_items(folder, fields: [:id])
    # client.delete_folder(folder, recursive: true)

    items.each do |f|
      client.delete_file(f)
    end

    redirect_to loan_docs_path
  end

  # start loan agreement docusign process
  def loan_docusign

    fileId = params[:file_id]
    envelope_response = create_docusign_envelope(fileId)
    mixpanel_tab_event("Loan Origination", "Start Docusign")

    # set up docusign view, fetch url
    recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
      envelope_id: envelope_response["envelopeId"],
      name: "Marcus Doe",
      email: "mmitchell+standard@box.com",
      return_url: docusign_response_loan_url(envelope_response["envelopeId"])
    )

    @url = recipient_view["url"]
  end

  # create docusign envelope for loan agreement
  def create_docusign_envelope(box_doc_id)

    box_user = user_client
    #
    # puts "#{box_doc_id} box file id"

    box_file = box_user.file_from_id(box_doc_id)
    raw_file = box_user.download_file(box_file)
    temp_file = Tempfile.open("box_doc_", Rails.root.join('tmp'), :encoding => 'ascii-8bit')

    begin
      temp_file.write(raw_file)
      temp_file.close

      puts "doc client"
      ap DOCUSIGN_CLIENT
      envelope = DOCUSIGN_CLIENT.create_envelope_from_document(
        email: {
          subject: "Signature Requested",
          body: "Please electronically sign this document."
        },
        # If embedded is set to true in the signers array below, emails
        # don't go out to the signers and you can embed the signature page in an
        # iFrame by using the client.get_recipient_view method
        signers: [
          {
            embedded: true,
            name: 'Marcus Doe',
            email: 'mmitchell+standard@box.com',
            role_name: 'Client',
            signHereTabs: [{"xPosition": "100", "yPosition": "100", "documentId": "1", "pageNumber": "1"}]
            # sign_here_tabs: [{anchor_string: "guarantee that all information above", anchor_x_offset: '150', anchor_y_offset: '50'}]
          }
        ],
        files: [
          {path: temp_file.path, name: "#{box_file.name}"}
        ],
        status: 'sent'
      )

      session[envelope["envelopeId"]] = {box_doc_id: box_file.id, box_doc_name: box_file.name}
    rescue => ex
      puts "Error in creating envo"
    ensure
      temp_file.delete
    end

    envelope
  end

  # docusign response for loan agreement
  def docusign_response_loan
    utility = DocusignRest::Utility.new

    if params[:event] == "signing_complete"
      mixpanel_tab_event("Loan Origination", "Docusign Sign")
      temp_file = Tempfile.open(["docusign_response_",".pdf"], Rails.root.join('tmp'), :encoding => 'ascii-8bit')

      begin
        DOCUSIGN_CLIENT.get_document_from_envelope(
          envelope_id: params["envelope_id"],
          document_id: 1,
          local_save_path: temp_file.path
        )

        box_info = session[params["envelope_id"]]

        box_user = user_client
        completedPath = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Loan\ Documents"
        signed_folder = box_user.folder_from_path(completedPath)
        file = box_user.upload_file(temp_file.path, signed_folder)
        #Box.create_in_view_api(file)
        box_user.update_file(file, name: "Loan Agreement - Completed.pdf")
        #box_user.update_metadata(file, [{'op' => 'add', 'path' => '/docusign_envelope_id', 'value' => params["envelope_id"]}])
        # meta = box_user.metadata(box_info[:box_doc_id])
        # ap meta
        box_user.delete_file(box_info[:box_doc_id])

        # box_user.create_metadata(file, meta)

      ensure
        temp_file.delete
      end

      flash[:notice] = "Thanks! Loan agreement successfully signed."
      render :text => utility.breakout_path(loan_docs_path), content_type: 'text/html'
    else
      flash[:error] = "You chose not to sign the document."
      render :text => utility.breakout_path(loan_docs_path), content_type: 'text/html'
    end
  end


end
