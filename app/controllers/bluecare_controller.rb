class BluecareController < SecuredController
  SHORT_CACHE_DURATION = 1.second
  LONGER_CACHE_DURATION = 10.minutes

  DOCUSIGN_CLIENT = DocusignRest::Client.new
  def show
    client = user_client
    @user_access_token = client.access_token

      # Bookshelf Items
      @bookshelf_folder = client.folder_from_id('10971446336')
      @bookshelf_files = client.folder_items(@bookshelf_folder, fields: [:name, :id, :modified_at])

      # Docusign Items
      @pendingSignatureFolder = client.folder_from_id('11020134011')
      @pendingSignatureItems = client.folder_items(@pendingSignatureFolder, fields: [:name, :id, :modified_at])
      ap @pendingSignatureItems

      @signedDocumentsFolder = client.folder_from_id('11022738678')
      @signedDocumentsItems = client.folder_items(@signedDocumentsFolder, fields: [:name, :id, :modified_at])

  end
  # delete file
  # def reset_bluecare
  #
  # begin
  #   client = user_client
  #   @signedDocumentsItems.each do |f|
  #     client.delete_file(f)
  #   end
  # rescue
  #   redirect_to bluecare_path
  # end

  # start loan agreement docusign process
  def bluecare_loan_docusign
    # get loan documents folder, if it doesn't exist create one
    client = user_client
    fileId = params[:file_id]


    @signedDocumentsFolder = client.folder_from_id('11022738678')
    @signedDocumentsItems = client.folder_items(@signedDocumentsFolder, fields: [:name, :id, :modified_at])
    @signedDocumentsItems.each do |f|
      client.delete_file(f)
    end

    box_file = client.file_from_id(fileId)
    enterprise = "enterprise_#{ENV['BOX_ENTERPRISE_ID']}"
    session[:fileName] = box_file.name

    envelope_response = bluecare_create_docusign_envelope(fileId)

    # set up docusign view, fetch url
    recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
      envelope_id: envelope_response["envelopeId"],
      name: "Marcus Doe",
      email: "mmitchell+standard@box.com",
      return_url: bluecare_docusign_response_loan_url(envelope_response["envelopeId"])
    )

    @url = recipient_view["url"]
  end

  # create docusign envelope for loan agreement
  def bluecare_create_docusign_envelope(box_doc_id)
    #
    # puts "#{box_doc_id} box file id"
    box_user = user_client
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
            #signHereTabs: [{"xPosition": "100", "yPosition": "100", "documentId": "1", "pageNumber": "1"}]
            sign_here_tabs: [{anchor_string: "Signature:", anchor_x_offset: '50', anchor_y_offset: '0'}]
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
  def bluecare_docusign_response_loan

    utility = DocusignRest::Utility.new
    mixpanel_tab_event("Tax Return", "Docusign Signed")

    if params[:event] == "signing_complete"
      temp_file = Tempfile.open(["docusign_response_",".pdf"], Rails.root.join('tmp'), :encoding => 'ascii-8bit')

      begin
        DOCUSIGN_CLIENT.get_document_from_envelope(
          envelope_id: params["envelope_id"],
          document_id: 1,
          local_save_path: temp_file.path
        )

        box_info = session[params["envelope_id"]]

        client = user_client
        bluecare_return_folder = client.folder_from_id('11022738678')
        file = client.upload_file(temp_file.path, bluecare_return_folder)
        # Box.create_in_view_api(file)
        client.update_file(file, name: session[:fileName].split(' (Not Signed)').first + " (Signed)" + "." + session[:fileName].split('.').last)
        # meta = box_user.metadata(box_info[:box_doc_id])
        # ap meta
        # client.delete_file(box_info[:box_doc_id])

        # box_user.create_metadata(file, meta)

      ensure
        temp_file.delete
      end
      flash[:error] = "Complete! Your document has been signed and submitted."
      render :text => utility.breakout_path(bluecare_path), content_type: 'text/html'
    else
      flash[:error] = "You chose not to sign the document."
      render :text => utility.breakout_path(bluecare_path), content_type: 'text/html'
    end
end









end
