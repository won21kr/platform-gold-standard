class WorkflowController < SecuredController

  skip_before_filter :verify_authenticity_token
  DOCUSIGN_CLIENT = DocusignRest::Client.new

  # main controller for onboarding workflow.
  def show

    client = user_client

    # fetch the onboarding doc file from whichever folder it current lives in
    # also, update the current workflow status state
    @onboardDoc = get_onboarding_doc
    session[:current_page] = "workflow"
    session[:task_status] = 1
    # perform actions based on current workflow status state
    if (@status == "toFill")
      session[:progress] = 0
      session[:task_status] = 1
      @message = "Step 1. Fill out your personal information"
    elsif(@status == "pendingApproval")
      set_preview_url(@onboardDoc.id)
      session[:progress] = 1
      session[:task_status] = 1
      @message = "Step 2. Wait for contract to be reviewed by the company"
    elsif(@status == "approved" or @status == "pendingSig")
      # create docusign doc
      envelope_response = create_docusign_envelope(@onboardDoc.id)

      # set up docusign view, fetch url
      recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
        envelope_id: envelope_response["envelopeId"],
        name: "Marcus Doe",
        email: "mmitchell+standard@box.com",
        return_url: docusign_response_url(envelope_response["envelopeId"])
      )
      ap recipient_view

      @url = recipient_view["url"]
      session[:progress] = 2
      session[:task_status] = 1
      @message = "Step 3. Sign the onboarding contract"
    elsif(@status == "signed")
      set_preview_url(@onboardDoc.id)
      session[:progress] = 3
      session[:task_status] = 0
      @message = "Onboarding process complete!"
    end

  end

  def form_submit

    puts "submitting form"
    client = user_client

    if(params[:formSubmit] == "true")
      # use form variables to fill out html template file,
      # convert html file to a pdf and upload to Box
      filename = "tmp/Onboarding Contract.pdf"

      # the "Doc" module code can be found in app/models/
      doc = Doc.new({:tel => params[:tel], :address => params[:address],
                     :bday => params[:bday], :id => params[:id],
                     :username => session[:userinfo]['info']['name'],
                     :review_status => "pending", :signature_status => "pending"})


      path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Pending\ Approval"
      doc.configure_pdf(client, filename, path)
    end

    flash[:notice] = "Thanks for filling out your information! Your contract is now under review."
    redirect_to workflow_path

  end


  def docusign_response
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
        completedPath = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Completed/"
        signed_folder = box_user.folder_from_path(completedPath)
        file = box_user.upload_file(temp_file.path, signed_folder)
        #Box.create_in_view_api(file)
        box_user.update_file(file, name: box_info[:box_doc_name])
        #box_user.update_metadata(file, [{'op' => 'add', 'path' => '/docusign_envelope_id', 'value' => params["envelope_id"]}])
        # meta = box_user.metadata(box_info[:box_doc_id])
        # ap meta
        box_user.delete_file(box_info[:box_doc_id])

        # box_user.create_metadata(file, meta)

      ensure
        temp_file.delete
      end

      flash[:notice] = "Thanks! Document successfully signed."
      render :text => utility.breakout_path(workflow_path), content_type: 'text/html'
    else
      flash[:error] = "You chose not to sign the document."
      render :text => utility.breakout_path(workflow_path), content_type: 'text/html'
    end
  end

  def reset_workflow

    puts "reset workflow..."
    client = user_client

    # get workflow folder paths
    path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
    approvalPath = "#{path}/Pending\ Approval/"
    sigReqPath = "#{path}/Signature\ Required/"
    completedPath = "#{path}/Completed/"

    # get all workflow folders, utilize cache
    approvalFolder = Rails.cache.fetch("/folder/#{approvalPath}", :expires_in => 20.minutes) do
      client.folder_from_path(approvalPath)
    end
    sigReqFolder = Rails.cache.fetch("/folder/#{sigReqPath}", :expires_in => 20.minutes) do
      client.folder_from_path(sigReqPath)
    end
    completedFolder = Rails.cache.fetch("/folder/#{completedPath}", :expires_in => 20.minutes) do
      client.folder_from_path(completedPath)
    end

    begin
      if ((file = client.folder_items(approvalFolder, fields: [:id]).files).size > 0)
        # file exists in approval folder
      elsif((file = client.folder_items(sigReqFolder, fields: [:id]).files).size > 0)
        # file exists in sig required folder
      elsif((file = client.folder_items(completedFolder, fields: [:id]).files).size > 0)
        # file exists in completed folder
      end
      ap file

      # delete file
      client.delete_file(file.first)
    rescue
      puts "Error: workflow not yet started!"
    end

    redirect_to workflow_path
  end

  private


  def create_docusign_envelope(box_doc_id)

    box_user = user_client

    box_file = box_user.file_from_id(box_doc_id)
    raw_file = box_user.download_file(box_file)
    temp_file = Tempfile.open("box_doc_", Rails.root.join('tmp'), :encoding => 'ascii-8bit')

    begin
      temp_file.write(raw_file)
      temp_file.close

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
            sign_here_tabs: [{anchor_string: "Signature:", anchor_x_offset: '100', anchor_y_offset: '0'}]
          }
        ],
        files: [
          {path: temp_file.path, name: "#{box_file.name}"}
        ],
        status: 'sent'
      )

      #stash stuff in the session for the end of the docusign flow
      session[envelope["envelopeId"]] = {box_doc_id: box_file.id, box_doc_name: box_file.name}
    rescue => ex
      puts ex.message
    ensure
      temp_file.delete
    end

    ap envelope

    envelope
  end

  # determine what the current workflow status
  # return the onboarding doc file obj
  def get_onboarding_doc

    # either "toFill", "pendingApproval", "approved", "pendingSig", "signed"
    @status = nil
    client = user_client

    # get workflow folder paths
    path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
    approvalPath = "#{path}/Pending\ Approval/"
    sigReqPath = "#{path}/Signature\ Required/"
    completedPath = "#{path}/Completed/"

    # get all workflow folders, utilize cache
    approvalFolder = Rails.cache.fetch("/folder/#{approvalPath}", :expires_in => 20.minutes) do
      client.folder_from_path(approvalPath)
    end
    sigReqFolder = Rails.cache.fetch("/folder/#{sigReqPath}", :expires_in => 20.minutes) do
      client.folder_from_path(sigReqPath)
    end
    completedFolder = Rails.cache.fetch("/folder/#{completedPath}", :expires_in => 20.minutes) do
      client.folder_from_path(completedPath)
    end

    # determine where we are in the onboarding workflow process
    if ((file = client.folder_items(approvalFolder, fields: [:id]).files).size > 0)

      # get the approval task status on the document
      task = client.file_tasks(file.first, fields: [:is_completed])

      if (task.first.is_completed == true)
        # task has been approved, move file to sig required folder

        @status = "approved"
        client.move_file(file.first, sigReqFolder.id)
        #file = client.folder_items(sigReqFolder).files
      else
        # task has not yet been approved, wait for approval
        @status = "pendingApproval"
      end
    elsif((file = client.folder_items(sigReqFolder, fields: [:id]).files).size > 0)
      # document in signature required folder, needs to be signed

      @status = "pendingSig"
    elsif((file = client.folder_items(completedFolder, fields: [:id]).files).size > 0)
      # document has already been signed
      @status = "signed"
    else
      # the information form has not yet been filled out by the customer
      @status = "toFill"
    end

    # return document obj or nil if document doesn't exist yet
    if(!file.nil?)
      file.first
    else
      nil
    end
  end

  def set_preview_url(id)
    @previewURL = user_client.embed_url(id)
  end

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end

end
