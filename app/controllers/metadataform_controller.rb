class MetadataformController < SecuredController
  skip_before_filter :verify_authenticity_token
  SHORT_CACHE_DURATION = 1.second
  LONGER_CACHE_DURATION = 10.minutes

  DOCUSIGN_CLIENT = DocusignRest::Client.new
  def show
    # get user client obj for Box API calls
    client = user_client
    @user_access_token = client.access_token
    session[:current_page] = "meta-form"

    begin
      @metaUploadsFolder = client.folder_from_path("Metadata\ User\ Uploads/Uploads\ -\ #{session[:box_id]}") do
      end
    rescue
      metaParentFolder = client.folder_from_path("Metadata User Uploads")
      @metaUploadsFolder = client.create_folder("Uploads - #{session[:box_id]}", metaParentFolder)
    end

    # get user metadata uploads
    @metaUploadsFiles = client.folder_items(@metaUploadsFolder, fields: [:name, :id])

  end

  # attach metadata to most recently uploaded file
  def attachmetadata
    client = user_client

    metaValue1 = params[:metaValue1]
    metaValue2 = params[:metaValue2]
    metaValue3 = params[:metaValue3]
    metaValue4 = params[:metaValue4]
    metaValue5 = params[:metaValue5]
    metaValue6 = params[:metaValue6]
    metaValue7 = params[:metaValue7]
    metaValue8 = params[:metaValue8]


    folder = client.folder_from_path("Metadata\ User\ Uploads/Uploads\ -\ #{session[:box_id]}")
    uploads = client.folder_items(folder, fields: [:name, :id])

    # define metadata
    meta = {"Name" => metaValue1,
            "Email" => metaValue2,
            "Telephone" => metaValue3,
            "Date Witnessed" => metaValue4,
            "Location" => metaValue5,
            "Borough" => metaValue6,
            "Crime Type" => metaValue7,
            "Description" => metaValue8}

    # attach metadata
    uploads.each_with_index do |f, i|
      begin
        client.create_metadata(f, meta)
        metadata = client.metadata(f, scope: :global, template: :properties)
      rescue Exception => e
        puts "FATAL: metadata already exists"
      end
      flash[:notice] = "Thank you for submitting"
    end
    redirect_to '/metadataform'
  end
end
