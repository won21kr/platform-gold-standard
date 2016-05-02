class DashboardController < SecuredController

  skip_before_filter :verify_authenticity_token
  # main controller for customer vault
  def show


    # get user client obj for Box API calls
    client = user_client
    mixpanel_tab_event("My Vault", "Main Page")
    @user_access_token = client.access_token
    session[:current_page] = "vault"
    threads = []
    @breadcrumb = {}
    session[:current_folder] = params[:id]

    # get "My Files" and "Shared Files" folder objects
    @myFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
      client.folder_from_path('My Files')
    end
    @sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
      client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
    end
    @sharedFolder.name = "Shared Files"

    # check if we're in a subfolder
    if (!params[:id].nil? and params[:id] != @sharedFolder.id and params[:id] != @myFolder.id)
      @myFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder/#{params[:id]}", :expires_in => 10.minutes) do
        client.folder_from_id(params[:id])
      end
      # session[:current_folder] = @myFolder.id

      # get breadcrumbs
      if @myFolder.path_collection?

        path = @myFolder.path_collection["entries"].drop(1)
        path.each do |item|
          @breadcrumb[item.name] = [item.id,true]
        end

        @breadcrumb[@myFolder.name] = [@myFolder.id, false]
      end
    end

    # set active folder ID, either "My Files" or "Shared Files" folder
    if(session[:current_folder].nil?)
      @currentFolder = @myFolder.id
    else
      @currentFolder = session[:current_folder]
    end
    session[:current_folder] = @currentFolder


    # get all files for dashboard vault display, either "My Files" or "Shared Files"
    threads << Thread.new do
      @myFiles = client.folder_items(@myFolder, fields: [:name, :id, :modified_at])
    end
    threads << Thread.new do
      @sharedFiles = client.folder_items(@sharedFolder, fields: [:name, :id, :modified_at]).files
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
    mixpanel_tab_event("My Vault", "Rename Item")

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

    redirect_to dashboard_id_path(session[:current_folder])
  end

  # post to edit folder name
  def edit_folder_name

    client = user_client
    mixpanel_tab_event("My Vault", "Rename Item")
    # folder = client.folder_from_id(params[:folder_id])
    session[:current_folder] = params[:folder_id]

    # make Box API call to update folder name
    begin
      client.update_folder(params[:folderId], name: params[:folderName])
      Rails.cache.delete("/folder/#{session[:box_id]}/my_folder/#{params[:folderId]}")
      flash[:notice] = "Folder name changed to \"#{params[:folderName]}\""
    rescue
      flash[:error] = "Error: Could not change folder name"
    end

    redirect_to dashboard_id_path(session[:current_folder])
  end


  # upload files to parameter specified folder ID
  def upload

    #http://www.dropzonejs.com/
    session[:current_folder] = params[:folder_id]
    uploaded_file = params[:file]
    folder = params[:folder_id]
    mixpanel_tab_event("My Vault", "Upload File")

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
    mixpanel_tab_event("My Vault", "Download File")
    download_url = Rails.cache.fetch("/download_url/#{params[:id]}", :expires_in => 10.minutes) do
      user_client.download_url(params[:id])
    end
    redirect_to download_url
  end

  # delete file
  def delete_file

    session[:current_folder] = params[:folder]
    client = user_client
    mixpanel_tab_event("My Vault", "Delete File")

    # delete file
    client.delete_file(params[:id])
    flash[:notice] = "File successfully deleted!"

    redirect_to dashboard_id_path(session[:current_folder])
  end

  # move file from personal vault to "Shared Files" folder
  def share_file

    id = params[:id]
    mixpanel_tab_event("My Vault", "Share File")
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
    mixpanel_tab_event("My Vault", "Share File")
    session[:current_folder] = params[:folder]
    client = user_client

    # get my folder, then move file into my folder
    myFolder = client.folder_from_path('My Files')
    client.move_file(id, myFolder)
    flash[:notice] = "File moved to private folder!"

    redirect_to dashboard_id_path(myFolder.id)
  end

  # Create a new empty sub-folder
  def new_folder

    puts "create new folder"
    client = user_client
    mixpanel_tab_event("My Vault", "New Folder")

    # get "My Files" and "Shared Files" folder objects
    @currentFolder = params[:parent_id]

    # create new subfolder
    begin
      newFolder = client.create_folder(params[:folderName], @currentFolder)
    rescue
      puts "could not create new folder"
      flash[:error] = "Error: could not create folder"
    end

    redirect_to dashboard_id_path(@currentFolder)
  end

  # delete subfolder
  def delete_folder
    session[:current_folder] = params[:folder]
    client = user_client
    mixpanel_tab_event("My Vault", "Delete Folder")


    # delete folder
    client.delete_folder(params[:id], recursive: true)
    flash[:notice] = "Folder successfully deleted!"

    redirect_to dashboard_id_path(session[:current_folder])
  end

  # move dragged file into subfolder
  def move_file

    destFolder = params[:dest]
    targetFile = params[:file_id]
    client = user_client
    mixpanel_tab_event("My Vault", "Move File - Drag & Drop")

    # get folder
    folder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder/#{params[:dest]}", :expires_in => 10.minutes) do
      client.folder_from_id(params[:dest])
    end

    begin
      # get shared folder, then move file into shared folder
      client.move_file(targetFile, destFolder)
      flash[:notice] = "File moved into \"#{folder.name}\""
    rescue
      flash[:error] = "Error: File could not be moved"
    end

    redirect_to dashboard_id_path(session[:current_folder])
  end

  # move dragged file into subfolder
  def move_folder

    destFolder = params[:dest]
    targetFolder = params[:folder_id]
    client = user_client
    mixpanel_tab_event("My Vault", "Move Folder - Drag & Drop")

    # get folder
    folder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder/#{params[:dest]}", :expires_in => 10.minutes) do
      client.folder_from_id(params[:dest])
    end

    begin
      # get shared folder, then move file into shared folder
      client.move_folder(targetFolder, destFolder)
      flash[:notice] = "Folder moved into \"#{folder.name}\""
    rescue
      flash[:error] = "Error: Folder could not be moved"
    end

    redirect_to dashboard_id_path(session[:current_folder])
  end


end
