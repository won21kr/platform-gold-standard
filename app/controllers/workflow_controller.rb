class WorkflowController < SecuredController

  skip_before_filter :verify_authenticity_token
  DOCUSIGN_CLIENT = DocusignRest::Client.new

  # main controller for onboarding workflow
  def show

    client = user_client

    # fetch the onboarding doc file from whichever folder it current lives in
    # also, update the current workflow status state
    @onboardDoc = get_onboarding_doc
    session[:current_page] = "workflow"
    session[:task_status] = 1


    # perform actions based on current workflow status state
    if (@status == "toFill")
      mixpanel_tab_event("Onboarding Tasks", "Fill Out Form Pending")
      session[:progress] = 0
      session[:task_status] = 1
      @message = "Step 1. Fill out your personal information"
    elsif(@status == "pendingApproval")
      mixpanel_tab_event("Onboarding Tasks", "Pending Approval")
      set_preview_url(@onboardDoc.id)
      session[:progress] = 1
      session[:task_status] = 1
      @message = "Step 2. Wait for contract to be reviewed by the company"
    elsif(@status == "approved" or @status == "pendingSig")
      mixpanel_tab_event("Onboarding Tasks", "Pending Signature")
      # create docusign doc
      case session[:industry]
      when "finserv"
        anchor_string = "signature (see instructions)"
        x_offset = '0'
        y_offset = '-10'
      when "healthcare"
        anchor_string = "Signature of patient"
        x_offset = '0'
        y_offset = '-30'
      when "insurance"
        anchor_string = "Signature:"
        x_offset = '90'
        y_offset = '5'
      when "nonprofit"
        anchor_string = "Signature:"
        x_offset = '150'
        y_offset = '0'
      else
        anchor_string = "Signature:"
        x_offset = '100'
        y_offset = '0'
      end

      envelope_response = create_docusign_envelope(@onboardDoc.id, anchor_string, x_offset, y_offset)

      # set up docusign view, fetch url
      begin
        recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
          envelope_id: envelope_response["envelopeId"],
          name: "Marcus Doe",
          email: "mmitchell+standard@box.com",
          return_url: docusign_response_url(envelope_response["envelopeId"])
        )

        @url = recipient_view["url"]
        session[:progress] = 2
        session[:task_status] = 1
        @message = "Step 3. Sign the onboarding contract"
      rescue
      end
    elsif(@status == "signed")
      mixpanel_tab_event("Onboarding Tasks", "Workflow Complete")
      set_preview_url(@onboardDoc.id)
      session[:progress] = 3
      session[:task_status] = 0
      @message = "Onboarding process complete!"
    end

  end

  def volunteer_form_submit

    client = user_client
    session[:volunteerForm] = {'name' => params[:name],
                               'mobile' => params[:tel],
                               'zip' => params[:zip]}

    # get workflow folder paths
    path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
    sigReqPath = "#{path}/Signature\ Required/"

    workflowFolder = Rails.cache.fetch("/folder/workflowFolder/#{session[:box_id]}", :expires_in => 15.minutes) do
      client.folder_from_path(path)
    end

    @sigReqFolder = Rails.cache.fetch("/folder/#{sigReqPath}/#{session[:box_id]}", :expires_in => 15.minutes) do
      begin
        client.folder_from_path(sigReqPath)
      rescue
        # folder doesn't exist, create
        client.create_folder("Signature Required", workflowFolder)
      end
    end

    # SFDC STRUCTURED DATA CODE HERE!

    client.copy_file(ENV['NONPROFIT_FORM'], @sigReqFolder)

    redirect_to workflow_path
  end

  def form_submit

    puts "submitting form"
    client = user_client
    mixpanel_tab_event("Onboarding Tasks", "Form Submit")


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
      doc.configure_pdf(client, filename, path, ENV['ONBOARDING_FORM'])
    end

    flash[:notice] = "Thanks for sharing your information! Your contract is under review."
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
        box_user.update_file(file, name: box_info[:box_doc_name])
        box_user.delete_file(box_info[:box_doc_id])

        updated_folder = box_user.create_shared_link_for_folder(signed_folder, access: :open)
        shared_link = updated_folder.shared_link.url
        user_vault_path = "Industry\ Resources/Nonprofit"
        user_vault_folder = box_user.folder_from_path(user_vault_path)
        user_vault_updated = box_user.create_shared_link_for_folder(user_vault_folder, access: :open)
        user_vault_shared_link = user_vault_updated.shared_link.url


        # box_user.create_metadata(file, meta)

      ensure
        temp_file.delete
      end

      if (session[:industry] == "nonprofit") # and some twilio number check
          twilio(session[:volunteerForm]['mobile'], shared_link, user_vault_shared_link)
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
    mixpanel_tab_event("Onboarding Tasks", "Reset Workflow")

    # get workflow folder paths
    path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
    approvalPath = "#{path}/Pending\ Approval/"
    sigReqPath = "#{path}/Signature\ Required/"
    completedPath = "#{path}/Completed/"

    # get all workflow folders, utilize cache
    approvalFolder = Rails.cache.fetch("/folder/#{approvalPath}/#{session[:box_id]}", :expires_in => 15.minutes) do
      client.folder_from_path(approvalPath)
    end
    sigReqFolder = Rails.cache.fetch("/folder/#{sigReqPath}/#{session[:box_id]}", :expires_in => 15.minutes) do
      client.folder_from_path(sigReqPath)
    end
    completedFolder = Rails.cache.fetch("/folder/#{completedPath}/#{session[:box_id]}", :expires_in => 15.minutes) do
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

      # delete file
      client.delete_file(file.first)
    rescue
      puts "Error: workflow not yet started!"
    end

    redirect_to workflow_path
  end

  private


  def create_docusign_envelope(box_doc_id, anchor_string, x_offset, y_offset)

    box_user = user_client

    box_file = box_user.file_from_id(box_doc_id)
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
            name: 'Marcus Doe',
            email: 'mmitchell+standard@box.com',
            role_name: 'Client',
            sign_here_tabs: [{anchor_string: anchor_string, anchor_x_offset: x_offset, anchor_y_offset: y_offset}]
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
      box_user.delete_file(box_doc_id)
    ensure
      temp_file.delete
    end

    envelope
  end

  # determine what the current workflow status
  # return the onboarding doc file obj
  def get_onboarding_doc

    # either "toFill", "pendingApproval", "approved", "pendingSig", "signed"
    @status = nil
    client = user_client
    threads = []

    # get workflow folder paths
    path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow"
    approvalPath = "#{path}/Pending\ Approval/"
    sigReqPath = "#{path}/Signature\ Required/"
    completedPath = "#{path}/Completed/"

    workflowFolder = Rails.cache.fetch("/folder/workflowFolder/#{session[:box_id]}", :expires_in => 15.minutes) do
      client.folder_from_path(path)
    end

    threads << Thread.new do

      # get all workflow folders, utilize cache
      @approvalFolder = Rails.cache.fetch("/folder/#{approvalPath}/#{session[:box_id]}", :expires_in => 15.minutes) do
        begin
          client.folder_from_path(approvalPath)
        rescue
          # folder doesn't exist, create
          client.create_folder("Pending Approval", workflowFolder)
        end
      end
    end

    threads << Thread.new do

      @sigReqFolder = Rails.cache.fetch("/folder/#{sigReqPath}/#{session[:box_id]}", :expires_in => 15.minutes) do
        begin
          client.folder_from_path(sigReqPath)
        rescue
          # folder doesn't exist, create
          client.create_folder("Signature Required", workflowFolder)
        end
      end
    end

    threads << Thread.new do

      @completedFolder = Rails.cache.fetch("/folder/#{completedPath}/#{session[:box_id]}", :expires_in => 15.minutes) do
        begin
          client.folder_from_path(completedPath)
        rescue
          # folder doesn't exist, create
          client.create_folder("Completed", workflowFolder)
        end
      end
    end

    threads.each { |thr| thr.join }

    # determine where we are in the onboarding workflow process
    if ((file = client.folder_items(@approvalFolder, fields: [:id]).files).size > 0)

      # get the approval task status on the document
      task = client.file_tasks(file.first, fields: [:is_completed])

      if (task.first.is_completed == true)
        # task has been approved, move file to sig required folder
        @status = "approved"
        client.move_file(file.first, @sigReqFolder.id)

      else
        # task has not yet been approved, wait for approval
        @status = "pendingApproval"
      end
    elsif((file = client.folder_items(@sigReqFolder, fields: [:id]).files).size > 0)
      # document in signature required folder, needs to be signed
      @status = "pendingSig"

    elsif((file = client.folder_items(@completedFolder, fields: [:id]).files).size > 0)
      # document has already been signed
      @status = "signed"

    elsif(!session[:industry].nil?)
      # use industry document
      file = Array.new
      @status = "pendingSig"
      case session[:industry]
      when 'finserv'
        file.push(client.copy_file(ENV['FINSERV_FORM'], @sigReqFolder))
      when 'healthcare'
        file.push(client.copy_file(ENV['HEALTHCARE_FORM'], @sigReqFolder))
      when 'insurance'
        file.push(client.copy_file(ENV['INSURANCE_FORM'], @sigReqFolder))
      when 'nonprofit'
        # file.push(client.copy_file(ENV['NONPROFIT_FORM'], @sigReqFolder))
        @status = "toFill"
      else
      end

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

  def twilio(phoneNumber, shared_link, user_vault_shared_link)
    account_sid = ENV['ACCOUNT_SID']
    auth_token = ENV['AUTH_TOKEN']
    client = Twilio::REST::Client.new account_sid, auth_token
    tracker = Mixpanel.client
    event = tracker.track('1234', 'Configuration - Twilio')

    from = +16507535096 # Your Twilio number

    friends = {
      phoneNumber => "New Volunteer"
    }
    friends.each do |key, value|
      client.account.messages.create(
      :from => from,
      :to => key,
      :body => "Thank you for signing up to be a new volunteer! You can find a signed copy of your volunter waiver here: " + shared_link +
        " Please take a look at your new volunteer information packet found here: " + user_vault_shared_link
      )
    end
  end

end
