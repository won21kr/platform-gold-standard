class UploadsignController < SecuredController

  skip_before_filter :verify_authenticity_token
  DOCUSIGN_CLIENT = DocusignRest::Client.new
  # main controller for customer vault
  def show

    # get user client obj for Box API calls
    client = user_client
    session[:current_page] = "upload-sign"

    # get "My Files" and "Shared Files" folder objects
    @myFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
      client.folder_from_path('My Files')
    end
    @sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
      client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
    end
    @sharedFolder.name = "Shared Files"

    # set active folder ID, either "My Files" or "Shared Files" folder
    if(params[:id])
      @currentFolder = params[:id]
    else
      @currentFolder = @myFolder.id
    end
    session[:current_folder] = @currentFolder

    # get all files for dashboard vault display, either "My Files" or "Shared Files"
    if(@currentFolder == @myFolder.id)
      @files = client.folder_items(@myFolder, fields: [:name, :id, :created_at, :modified_at]).files
    elsif(@currentFolder == @sharedFolder.id)
      @files = client.folder_items(@sharedFolder, fields: [:name, :id, :created_at, :modified_at]).files
    end
#add ds
  end

  # post to edit filename
  def edit_filename

    client = user_client

    file = client.file_from_id(params[:fileId])
    newName = params[:fileName] + '.' + params[:fileExt]

    begin
      client.update_file(file, name: newName)
      flash[:notice] = "File name changed to \"#{params[:fileName]}\""
    rescue
      flash[:error] = "Error: Could not change file name"
    end

    redirect_to dashboard_path
  end

  # upload files to parameter specified folder ID
  def upload

    #http://www.dropzonejs.com/
    uploaded_file = params[:file]
    folder = params[:folder_id]

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_user = Box.user_client(session[:box_id])

      box_file = box_user.upload_file(temp_file.path, folder)
      #box_user.create_metadata(box_file, session[:meta])

    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "Successfully Uploaded!"
    respond_to do |format|
      format.json{ render :json => {} }
    end
  end

  # get file thumbnail from file ID
  def thumbnail

    image = Rails.cache.fetch("/image_thumbnail/#{params[:id]}", :expires_in => 10.minutes) do
      puts "miss!"
      user_client.thumbnail(params[:id], min_height: 256, min_width: 256)
    end

    send_data image, :type => 'image/png', :disposition => 'inline'
  end

  # download file from file ID
  def download

    download_url = Rails.cache.fetch("/download_url/#{params[:id]}", :expires_in => 10.minutes) do
      user_client.download_url(params[:id])
    end
    redirect_to download_url
  end

  # delete file
  def delete_file

    id = params[:id]
    client = user_client
    client.delete_file(id)
    flash[:notice] = "File successfully deleted!"

    redirect_to dashboard_id_path(session[:current_folder])
  end

  # move file from personal vault to "Shared Files" folder
  def share_file

    id = params[:id]
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
    client = user_client

    # get my folder, then move file into my folder
    myFolder = client.folder_from_path('My Files')
    client.move_file(id, myFolder)
    flash[:notice] = "File moved to private folder!"

    redirect_to dashboard_id_path(myFolder.id)
  end

  def start_docusign
    # fetch the onboarding doc file from whichever folder it current lives in
    # also, update the current workflow status state
    id = params[:id]
    @onboardDoc = get_onboarding_doc

    # perform actions based on current workflow status state
      envelope_response = create_docusign_envelope(@onboardDoc.id)

      # set up docusign view, fetch url
      recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
        envelope_id: envelope_response["envelopeId"],
        name: "Marcus Doe",
        email: "mmitchell+standard@box.com",
        return_url: uploadsign_docusign_response_url(envelope_response["envelopeId"])
      )
      ap recipient_view

      @url = recipient_view["url"]
      session[:progress] = 2
    if(session[:progress] == 3)
      set_preview_url(@onboardDoc.id)
      session[:progress] = 3
      @message = "Onboarding process complete!"
    end

  end

  def uploadsign_docusign_response

    ap "in docusign response"
    utility = DocusignRest::Utility.new
    temp_file = Tempfile.open(["uploadsign_docusign_response_",".pdf"], Rails.root.join('tmp'), :encoding => 'ascii-8bit')

      begin
        DOCUSIGN_CLIENT.get_document_from_envelope(
          envelope_id: params["envelope_id"],
          document_id: 1,
          local_save_path: temp_file.path
        )

        box_info = session[params["envelope_id"]]

        box_user = user_client
        path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/"
        signed_folder = box_user.folder_from_path(path)
        file = box_user.upload_file(temp_file.path, signed_folder)
        #Box.create_in_view_api(file)
        box_user.delete_file(box_info[:box_doc_id])
        box_user.update_file(file, name: "Signed-"+ box_info[:box_doc_name])
        #box_user.update_metadata(file, [{'op' => 'add', 'path' => '/docusign_envelope_id', 'value' => params["envelope_id"]}])
        # meta = box_user.metadata(box_info[:box_doc_id])
        # ap meta


        # box_user.create_metadata(file, meta)

      ensure
        temp_file.delete
      end

      session[:progress] = 3
      puts session[:progress]
      flash[:notice] = "Thanks! Document successfully signed."
     render :text => utility.breakout_path(start_docusign_path), content_type: 'text/html'
  end


  def create_docusign_envelope(box_doc_id)

    ap "in create docusign envelope"
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
    ap "Envelope Successfully Created"
    envelope
  end

  # determine what the current workflow status
  # return the onboarding doc file obj
  def get_onboarding_doc
    # either "toFill", "pendingApproval", "approved", "pendingSig", "signed"
    @status = nil
    client = user_client
    ap " In get onboarding document"
    # get workflow folder paths
    path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/"
    sharedFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")

    if ((file = client.folder_items(sharedFolder, fields: [:id]).files).size > 0)
      ap "File Exists"
      ap file
    end

    if(!file.nil?)
      file.first
    else
      nil
    end

  end


  def set_preview_url(id)
    @previewURL = user_client.embed_url(id)
  end

  private

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end

end
