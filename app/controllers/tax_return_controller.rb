class TaxReturnController < SecuredController

  skip_before_filter :verify_authenticity_token
  DOCUSIGN_CLIENT = DocusignRest::Client.new

  def show

    client = user_client
    @user_access_token = client.access_token

    session[:current_page] = "tax_return"
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Tax Return"
    docStatus = Hash.new
    threads = []

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
      @loanFolder = client.folder_from_path(path)
    rescue
      parent = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @loanFolder = client.create_folder("Signed Documents", parent)
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
        task = client.file_tasks(file, fields: [:is_completed]).first

        if (name == "Loan Agreement - Signature Needed")
          @docStatus["Loan Agreement"] = "Signature Needed"
          @docStatus[imageName] = "file_process.png"
          @fileId["Loan Agreement"] = file.id
          @fileComments[searchName] = client.file_comments(file.id, fields: [:id]).size
        elsif(name == "Loan Agreement - Completed")
          @docStatus["Loan Agreement"] = "Completed"
          @docStatus[imageName] = "file_success.png"
          @fileId["Loan Agreement"] = file.id
          @fileComments[searchName] = client.file_comments(file.id, fields: [:id]).size
        else
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

    # get vault folder and search for items by name
    # vaultId = client.folder_from_path("My Files").id
    vaultFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
      puts "miss"
      client.folder_from_path("My Files")
    end

    if (@docStatus["Loan Agreement"] == "Missing")
      threads << Thread.new do
        @searchFiles["Loan"] = Rails.cache.fetch("/loan_search/#{session[:box_id]}/loan", :expires_in => 4.minutes) do
          puts "miss"
          client.search("Loan", content_types: :name, file_extensions: 'pdf', ancestor_folder_ids: vaultFolder.id)
        end
      end
    end

    if (@docStatus["W2 Form"] == "Missing")
      threads << Thread.new do
        @searchFiles["W2"] = Rails.cache.fetch("/loan_search/#{session[:box_id]}/w2", :expires_in => 4.minutes) do
          puts "miss"
          client.search("W2", content_types: :name, file_extensions: 'pdf', ancestor_folder_ids: vaultFolder.id)
        end
      end
    end

    if (@docStatus["Tax Return"] == "Missing")
      threads << Thread.new do
        @searchFiles["Tax"] = Rails.cache.fetch("/loan_search/#{session[:box_id]}/tax", :expires_in => 4.minutes) do
          puts "miss"
          client.search("Tax", content_types: :name, file_extensions: 'pdf', ancestor_folder_ids: vaultFolder.id)
        end
      end
    end

    #  rejoins threads
    threads.each { |thr| thr.join }




    #========================================================================================================
    #Submit metadata functions begins here

    if (!session[:claimPage].nil? and session[:claimPage] == 'submitted')
      @currentPage = 'submitted'
      session[:claimPage] = 'newClaim'
    else
      @currentPage = 'newClaim'
    end


    begin
      @taxReturnFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Tax Return")
      @taxes = client.folder_items(@taxReturnFolder, fields: [:id, :name, :content_created_at])

    rescue
      puts "folder not yet created, create"
      sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
      client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      client.create_folder("Tax Return", sharedFolder)
    end

      @myFolder = Rails.cache.fetch("#{session[:userinfo]['info']['name']} - Shared Files/Tax Return", :expires_in => 10.minutes) do
      client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Tax Return")
    end

    @taxFiles = client.folder_items(@myFolder)


    # attach file metadata template to each file
    @taxes.each do |c|
      threads << Thread.new do
        class << c
          attr_accessor :category, :subcategory
        end

        begin
          # meta = Rails.cache.fetch("/claim-metadata/#{c.id}", :expires_in => 10.minutes) do
          #   puts "miss"
          #   client.all_metadata(c)["entries"]
          # end
          meta = client.all_metadata(c)["entries"]

          meta.each do |m|
            if (m["$template"] == "taxCategory")
              c.category = m["category"]
              c.subcategory = m["subcategory"]
            end
          end

        rescue
          c.claimId = ""
          c.type = ""
          c.estimatedValue = ""
          c.description = ""
          c.status = ""
        end
      end
    end

    threads.each { |thr| thr.join }

  end

  # upload files to parameter specified folder ID
  def tax_loan_upload

    puts "uploading file..."

    #http://www.dropzonejs.com/
    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Tax Return"

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

  # upload files to parameter specified folder ID
  def loan_agreement_upload

    puts "uploading file..."

    #http://www.dropzonejs.com/
    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Tax Return"

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


  # copy over a document from the user's vault to Loan Docs folder
  def tax_copy_from_vault

    puts "copy from vault"
    fileId = params[:file_id]
    oldName = params[:old_name].split(".")
    newName = params[:new_name] + "." + oldName.last
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Tax Return"

    # get loan docs folder, copy vault file into it
    client = user_client
    folder = client.folder_from_path(path)
    toCopy = client.file_from_id(fileId, fields: [:name, :id])
    copiedFile = client.copy_file(toCopy, folder, name: newName)

    # assign task to Box managed user
    msg = "Please review and complete the task"
    task = client.create_task(copiedFile, action: :review, message: msg)
    client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])
    flash[:notice] = "Successfully copied over \"#{oldName.first}\" from your vault"

    redirect_to "/metadata_upload"
  end

  def claim_info
    session[:current_page] = "create-claim"
    session[:claim] = params[:file]
    session[:claim_id] = params[:file].split('-').last

  end


  def submit_claim

  client = user_client

  path = "#{session[:userinfo]['info']['name']} - Shared Files/Tax Return"
  file = client.folder_from_path(path)
  taxFiles = client.folder_items(file)

  taxFiles.each do |f|
    @taxFileName = f.name
  end
  # puts "PLEASE WORK"
  # ap session[:fileName]

  meta = {'category' => params[:category],
          'subcategory' => params[:subcategory]}


  begin
    @taxReturnFolder = client.folder_from_path(path)
    @submittedTaxFile = client.file_from_path(path + "/#{@taxFileName}")
    client.create_metadata(@submittedTaxFile, meta, scope: :enterprise, template: 'taxCategory')
    # flash[:notice] = "Claim ##{session[:claim_id]} successfully submitted. Await company approval."
    session[:claimPage] = 'submitted'
  rescue Exception => e
    ap e
    puts "error. Folder not found"
    flash[:error] = "Error. Something went wrong."
    session[:claimPage] = 'newClaim'
  end


    redirect_to create_claim_path
  end


  def tax_reset

    client = user_client
    begin
      @taxReturnFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Tax Return")
      @taxes = client.folder_items(@taxReturnFolder, fields: [:id, :name])
    rescue
      puts "folder not yet created"
    end

    begin
      @signedFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Signed Documents")
      @signed = client.folder_items(@signedFolder, fields: [:id, :name])
    rescue
      puts "folder not yet created"
    end

    if @taxes != nil
      @taxes.each do |c|
        client.delete_file(c)
      end
    end

    if @signed != nil
      @signed.each do |c|
        client.delete_file(c)
      end
    end

    redirect_to create_claim_path
  end

  def tax_upload

    #http://www.dropzonejs.com/
    session[:current_folder] = params[:folder_id]
    uploaded_file = params[:file]
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Tax Return"

    session[:fileName] = uploaded_file.original_filename

    # upload file to box from tmp folder
    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close
      box_user = Box.user_client(session[:box_id])
      folder = box_user.folder_from_path(path)
      box_file = box_user.upload_file(temp_file.path, folder)
      puts "uploaded"
    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "Successfully Uploaded!"
    respond_to do |format|
      format.json{ render :json => {} }
    end
    redirect_to tax_return_path
  end

  # download file from file ID
  def download

    session[:current_folder] = params[:folder]
    download_url = Rails.cache.fetch("/download_url/#{params[:id]}", :expires_in => 10.minutes) do
      user_client.download_url(params[:id])
    end

    redirect_to download_url
  end

  # delete file
  def delete_file

    session[:current_folder] = params[:folder]
    client = user_client

    # delete file
    client.delete_file(params[:id])
    flash[:notice] = "File successfully deleted!"

    redirect_to dashboard_id_path(session[:current_folder])
  end

  # move file from personal vault to "Shared Files" folder
  def share_file

    id = params[:id]
    session[:current_folder] = params[:folder]
    client = user_client

    # get shared folder, then move file into shared folder
    sharedFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
    client.move_file(id, sharedFolder)
    flash[:notice] = "File shared with company employee!"

    redirect_to dashboard_id_path(sharedFolder.id)
  end

  # move file from "Shared Files" folder to personal vault
  def unshare_file

    id = params[:id]
    session[:current_folder] = params[:folder]
    client = user_client

    # get my folder, then move file into my folder
    myFolder = client.folder_from_path('My Files')
    client.move_file(id, myFolder)
    flash[:notice] = "File moved to private folder!"

    redirect_to dashboard_id_path(myFolder.id)
  end


  # start loan agreement docusign process
  def tax_loan_docusign

    fileId = params[:file_id]
    envelope_response = tax_create_docusign_envelope(fileId)

    # set up docusign view, fetch url
    recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
      envelope_id: envelope_response["envelopeId"],
      name: "Marcus Doe",
      email: "mmitchell+standard@box.com",
      return_url: tax_docusign_response_loan_url(envelope_response["envelopeId"])
    )

    @url = recipient_view["url"]
  end

  # create docusign envelope for loan agreement
  def tax_create_docusign_envelope(box_doc_id)

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

      # # no anchor string found!
      # if (envelope['errorCode'] == "ANCHOR_TAB_STRING_NOT_FOUND")
      #   envelope = DOCUSIGN_CLIENT.create_envelope_from_document(
      #     email: {
      #       subject: "Signature Requested",
      #       body: "Please electronically sign this document."
      #     },
      #     # If embedded is set to true in the signers array below, emails
      #     # don't go out to the signers and you can embed the signature page in an
      #     # iFrame by using the client.get_recipient_view method
      #     signers: [
      #       {
      #         embedded: true,
      #         name: 'Marcus Doe',
      #         email: 'mmitchell+standard@box.com',
      #         role_name: 'Client',
      #         signHereTabs: [{"xPosition": "100", "yPosition": "100", "documentId": "1", "pageNumber": "1"}]
      #         # sign_here_tabs: [{anchor_string: "guarantee that all information above", anchor_x_offset: '150', anchor_y_offset: '50'}]
      #       }
      #     ],
      #     files: [
      #       {path: temp_file.path, name: "#{box_file.name}"}
      #     ],
      #     status: 'sent'
      #   )
      # end
      session[envelope["envelopeId"]] = {box_doc_id: box_file.id, box_doc_name: box_file.name}
    rescue => ex
      puts "Error in creating envo"
    ensure
      temp_file.delete
    end

    envelope
  end

  # docusign response for loan agreement
  def tax_docusign_response_loan
    utility = DocusignRest::Utility.new

    if params[:event] == "signing_complete"
      temp_file = Tempfile.open(["docusign_response_",".pdf"], Rails.root.join('tmp'), :encoding => 'ascii-8bit')

      begin
        DOCUSIGN_CLIENT.get_document_from_envelope(
          envelope_id: params["envelope_id"],
          document_id: 1,
          local_save_path: temp_file.path
        )

        box_info = session[params["envelope_id"]]

        box_user = user_client
        completedPath = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Signed\ Documents"
        signed_folder = box_user.folder_from_path(completedPath)
        file = box_user.upload_file(temp_file.path, signed_folder)
        #Box.create_in_view_api(file)
        box_user.update_file(file, name: "Signed Document.pdf")
        #box_user.update_metadata(file, [{'op' => 'add', 'path' => '/docusign_envelope_id', 'value' => params["envelope_id"]}])
        # meta = box_user.metadata(box_info[:box_doc_id])
        # ap meta
        box_user.delete_file(box_info[:box_doc_id])

        # box_user.create_metadata(file, meta)

      ensure
        temp_file.delete
      end

      render :text => utility.breakout_path(tax_return_path), content_type: 'text/html'
    else
      flash[:error] = "You chose not to sign the document."
      render :text => utility.breakout_path(tax_return_path), content_type: 'text/html'
    end
  end

  def tax_file_upload
  end

  def metadata_upload
  end

  def loan_file_upload
  end

end
