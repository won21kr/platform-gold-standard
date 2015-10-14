class WorkflowController < SecuredController

  skip_before_filter :verify_authenticity_token

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

        set_preview_url(@pendingApproval.first.id)
        session[:progress] = 66
      else
        # task not yet compeleted, display pending approval file
        puts "task not yet complete"
        set_preview_url(@pendingApproval.first.id)
        session[:progress] = 33
      end


    end


  end

  private

  def set_preview_url(id)
    @previewURL = user_client.embed_url(id)
  end

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end

end
