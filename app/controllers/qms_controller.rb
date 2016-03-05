class QmsController < SecuredController

  skip_before_filter :verify_authenticity_token
  # main controller for customer vault
  def show

    client = user_client
    threads = []

    # get loan documents folder, if it doesn't exist create one
    path = "#{session[:userinfo]['info']['name']} - Shared Files/QMS Folder"

    begin
      @qmsFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/qms_folder", :expires_in => 10.minutes) do
        client.folder_from_path(path)
      end
    rescue
      parent = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @qmsFolder = client.create_folder("QMS Folder", parent)
    end

    @workflowItems = client.folder_items(@qmsFolder, fields: [:id, :name, :modified_at, :content_created_at])
    # attach file metadata template to each file
    # attach file metadata template to each file
    @workflowItems.each do |c|
      threads << Thread.new do
        class << c
          attr_accessor :qualityManagerApproval, :documentManagerApproval, :customerApproverApproval
        end

        begin
          meta = client.all_metadata(c)["entries"]

          meta.each do |m|
            if (m["$template"] == "qmsMetadata")
              c.qualityManagerApproval = m["qualityManagerApproval"]
              c.documentManagerApproval = m["documentManagerApproval"]
              c.customerApproverApproval = m["customerApproverApproval"]
            end
          end

        rescue
          c.qualityManagerApproval = ""
          c.documentManagerApproval = ""
          c.customerApproverApproval = ""
        end
      end
    end

    threads.each { |thr| thr.join }

  end

  def search_vault(name)

    client = user_client

    vaultFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 8.minutes) do
      puts "miss"
      client.folder_from_path("My Files")
    end

    results = client.search(name, content_types: :name, ancestor_folder_ids: vaultFolder.id)

    results
  end

  # post to edit filename
  def edit_filename

    client = user_client

    file = client.file_from_id(params[:fileId], fields: [:parent])

    # set current folder id & new file name
    session[:current_folder] = file.parent.id
    newName = params[:fileName] + '.' + params[:fileExt]

    # make Box API call to update file name
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
    session[:current_folder] = params[:folder_id]
    uploaded_file = params[:file]
    folder = params[:folder_id]

    # upload file to box from tmp folder
    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close
      box_user = Box.user_client(session[:box_id])
      box_file = box_user.upload_file(temp_file.path, folder)

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

  def create_folder
    client = user_client

    parentFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/QMS Folder")
    session[:workflowFolder] = client.create_folder(params[:proposal], parentFolder)

    render 'qms/workflow_upload'
  end

  def upload_file
    #http://www.dropzonejs.com/
    client = user_client

    puts "inside the upload method"
    uploaded_file = params[:file]

    folder = client.folder_from_id(session[:workflowFolder].id)

    puts "folder grabbed here: "
    ap folder

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close
      box_file = client.upload_file(temp_file.path, folder)
      session[:workflowFile] = box_file.id

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

  def reset
    client = user_client

    #clear cache of file id and delete folder and folder items
    client.delete_folder(session[:workflowFolder], recursive: true)
    session.delete(:workflowFolder)

    redirect_to qms_path
  end

  def qms_submit_metadata

    client = user_client

    @metadataHash = {
      "qualityManagerApproval" => params[:quality_manager_approval],
      "documentManagerApproval" => params[:document_manager_approval],
      "customerApproverApproval" => params[:customer_approver_approval]
    }

    meta = {'qualityManagerApproval' => @metadataHash["qualityManagerApproval"],
            'documentManagerApproval' => @metadataHash["documentManagerApproval"],
            'customerApproverApproval' => @metadataHash["customerApproverApproval"]
          }
    begin
      ap session[:workflowFile]
      file = client.file_from_id(session[:workflowFile], fields: [:id])
      ap file
      client.create_metadata(file, meta, scope: :enterprise, template: 'qmsMetadata')
      puts "file object: "
      ap file
      session[:claimPage] = 'submitted'
    rescue Exception => e
      ap e
      puts "error. Folder not found"
      flash[:error] = "Error. Something went wrong."
      session[:claimPage] = 'newClaim'
    end
      redirect_to qms_path
  end

  def qms_metadata_upload
  end
end
