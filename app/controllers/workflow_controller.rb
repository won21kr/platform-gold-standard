class WorkflowController < SecuredController

  skip_before_filter :verify_authenticity_token
  DOCUSIGN_CLIENT = DocusignRest::Client.new

  # main controller for onboarding workflow
  def show

    client = user_client
    approvalPath = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Pending\ Approval/"
    sigReqPath = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Signature\ Required/"

    # progress bar initialize
    session[:progress] = 0

    approvalFolder = client.folder_from_path(approvalPath)
    sigReqFolder = client.folder_from_path(sigReqPath)

    # check where we are in the onboarding workflow process
    @pendingApproval = client.folder_items(approvalFolder).files
    @sigRequired = client.folder_items(sigReqFolder).files


    if(params[:formSubmit] == "true")
      # use form variables to fill out html template file,
      # convert html file to a pdf and upload to Box

      # the "Doc" module code can be found in app/models/
      doc = Doc.new({:tel => params[:tel], :address => params[:address],
                     :bday => params[:bday], :acct => params[:acct],
                     :username => session[:userinfo]['info']['name'],
                     :review_status => "pending", :signature_status => "pending"})

      filename = "tmp/Onboarding Contract.pdf"
      path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Pending\ Approval"
      doc.configure_pdf(client, filename, path)

      session[:progress] = 33
      @pendingApproval = client.folder_items(approvalFolder).files
      set_preview_url(@pendingApproval.first.id)
    elsif (@pendingApproval.size > 0)

      task = client.file_tasks(@pendingApproval.first, fields: [:is_completed])

      if (task.first.is_completed)
        # task is not complete, move to "Pending Signatures" document, setup DocuSign

        # move @pendingApproval file into sig required folder
        client.move_file(@pendingApproval.first, sigReqFolder.id)

        #set_preview_url(@pendingApproval.first.id)
        session[:progress] = 66
      else
        # task not yet compeleted, display pending approval file
        puts "task not yet complete"
        set_preview_url(@pendingApproval.first.id)
        session[:progress] = 33
      end
    end

    # check if document needs to be signed
    if (@sigRequired.size > 0)

      envelope_response = create_docusign_envelope

      recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
        envelope_id: envelope_response["envelopeId"],
        name: "Chad Burnette",
        email: "cburnette+docusign-test@box.com",
        return_url: docusign_response_url(envelope_response["envelopeId"])
      )
      @url = recipient_view["url"]
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
          signed_folder = box_user.folder_from_path("Signed Documents")
          file = box_user.upload_file(temp_file.path, signed_folder)
          Box.create_in_view_api(file)
          box_user.update_file(file, name: box_info[:box_doc_name])
          box_user.update_metadata(file, [{'op' => 'add', 'path' => '/docusign_envelope_id', 'value' => params["envelope_id"]}])
          box_user.delete_file(box_info[:box_doc_id])

        ensure
          temp_file.delete
        end

        flash[:notice] = "Thanks! Successfully signed."
        render :text => utility.breakout_path(dashboard_path), content_type: 'text/html'
      else
        flash[:error] = "You chose not to sign the document."
        render :text => utility.breakout_path(dashboard_path), content_type: 'text/html'
      end
    end


  end

  private


  def create_docusign_envelope
    box_user = Box.user_client(session[:box_id])

    box_file = box_user.file(params[:box_doc_id])
    raw_file = box_user.download_file(box_file)
    temp_file = Tempfile.open("box_doc_", Rails.root.join('tmp'), :encoding => 'ascii-8bit')

    begin
      temp_file.write(raw_file)
      temp_file.close

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
            name: 'Chad Burnette',
            email: 'cburnette+docusign-test@box.com',
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

    envelope
  end

  def set_preview_url(id)
    @previewURL = user_client.embed_url(id)
  end

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end

end
