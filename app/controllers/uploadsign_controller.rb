class UploadsignController < SecuredController

  skip_before_filter :verify_authenticity_token
  DOCUSIGN_CLIENT = DocusignRest::Client.new

  # main controller for upload and sign tab
  def show

    # get user client obj for Box API calls
    client = user_client
    session[:current_page] = "upload-sign"

    # get signed and pending signature folders, create them if they dont exist
    begin
      @pendingFolder = Rails.cache.fetch("/uploadnisgn/#{session[:box_id]}/pending", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("Upload\ &\ Sign/Pending\ Signature")
      end
      @signedFolder = Rails.cache.fetch("/uploadnisgn/#{session[:box_id]}/signed", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("Upload\ &\ Sign/Signed")
      end
    rescue
      signFolder = client.create_folder("Upload & Sign", Boxr::ROOT)
      @pendingFolder = client.create_folder("Pending Signature", signFolder)
      @signedFolder = client.create_folder("Signed", signFolder)
    end

    # get signed/pending files
    @pendingFiles = client.folder_items(@pendingFolder, fields: [:name, :id])
    @signedFiles = client.folder_items(@signedFolder, fields: [:name, :id])

  end

  # upload files to parameter specified folder ID
  def sign_upload


    puts "Uploading to sign doc"

    #http://www.dropzonejs.com/
    uploaded_file = params[:file]
    folder = params[:folder_id]
    ext = uploaded_file.original_filename.split('.').last

    if (ext == "pdf")
      temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
      begin
        temp_file.write(uploaded_file.read)
        temp_file.close

        box_user = Box.user_client(session[:box_id])

        box_file = box_user.upload_file(temp_file.path, folder)
        # box_user.create_metadata(box_file, meta)

      rescue => ex
        puts ex.message
      ensure
        File.delete(temp_file)
      end

      flash[:notice] = "Successfully Uploaded!"
    else
      flash[:error] = "Error: File not uploaded. Must upload a PDF."
    end
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


  # delete file
  def reset_uploadnsign

    client = user_client
    begin
      pendingFolder = Rails.cache.fetch("/uploadnisgn/#{session[:box_id]}/pending", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("Upload\ &\ Sign/Pending\ Signature")
      end
      signedFolder = Rails.cache.fetch("/uploadnisgn/#{session[:box_id]}/signed", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("Upload\ &\ Sign/Signed")
      end

      # get signed/pending files, and delete all
      pendingFiles = client.folder_items(pendingFolder, fields: [:id])
      pendingFiles.each do |f|
        client.delete_file(f)
      end

      signedFiles = client.folder_items(signedFolder, fields: [:id])
      signedFiles.each do |f|
        client.delete_file(f)
      end

    rescue
      puts "Error: Can't delete folder items"
    end

    redirect_to uploadsign_path
  end


  def start_docusign
    # fetch the onboarding doc file from whichever folder it current lives in
    # also, update the current workflow status state
    id = params[:id]

  # perform actions based on current workflow status state
    envelope_response = create_docusign_envelope(id)

    # set up docusign view, fetch url
    recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
      envelope_id: envelope_response["envelopeId"],
      name: "Marcus Doe",
      email: "mmitchell+standard@box.com",
      return_url: uploadnsign_docusign_response_url(envelope_response["envelopeId"])
    )

    @url = recipient_view["url"]
  end

  def uploadnsign_docusign_response

    utility = DocusignRest::Utility.new
    temp_file = Tempfile.open(["uploadsign_docusign_response_",".pdf"], Rails.root.join('tmp'), :encoding => 'ascii-8bit')
    box_user = user_client

      begin
        DOCUSIGN_CLIENT.get_document_from_envelope(
          envelope_id: params["envelope_id"],
          document_id: 1,
          local_save_path: temp_file.path
        )

        box_info = session[params["envelope_id"]]

        signed_folder = Rails.cache.fetch("/uploadnisgn/#{session[:box_id]}/signed", :expires_in => 10.minutes) do
          puts "miss"
          client.folder_from_path("Upload\ &\ Sign/Signed")
        end
        file = box_user.upload_file(temp_file.path, signed_folder)
        box_user.update_file(file, name: box_info[:box_doc_name])
        box_user.delete_file(box_info[:box_doc_id])
      ensure
        temp_file.delete
      end

      flash[:notice] = "Thanks! Document successfully signed."
      render :text => utility.breakout_path(uploadsign_path), content_type: 'text/html'
  end


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
            signHereTabs: [{"xPosition": "100", "yPosition": "100", "documentId": "1", "pageNumber": "1"}]
            # sign_here_tabs: [{anchor_string: "Signature:", anchor_x_offset: '100', anchor_y_offset: '0'}]
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

    ap "Envelope Successfully Created"
    envelope
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
