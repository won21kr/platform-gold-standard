class DashboardController < SecuredController

  skip_before_filter :verify_authenticity_token
  # main controller for customer vault
  def show

    # get user client obj for Box API calls
    client = user_client
    session[:current_page] = "vault"


    # get "My Files" and "Shared Files" folder objects
    @myFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
      client.folder_from_path('My Files')
    end
    @sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
      client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
    end
    @sharedFolder.name = "Shared Files"

    # set active folder ID, either "My Files" or "Shared Files" folder
    if(session[:current_folder].nil?)
      @currentFolder = @myFolder.id
    else
      @currentFolder = session[:current_folder]
    end
    # session[:current_folder] = @currentFolder

    # get all files for dashboard vault display, either "My Files" or "Shared Files"
    @myFiles = client.folder_items(@myFolder, fields: [:name, :id, :created_at, :modified_at]).files
    @sharedFiles = client.folder_items(@sharedFolder, fields: [:name, :id, :created_at, :modified_at]).files

  end

  def search_vault(name)


    client = user_client

    vaultFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
      puts "miss"
      client.folder_from_path("My Files")
    end

    results = client.search(name, content_types: :name, ancestor_folder_ids: vaultFolder.id)

    results
  end

  # post to edit filename
  def edit_filename

    client = user_client

    file = client.file_from_id(params[:fileId])
    newName = params[:fileName] + '.' + params[:fileExt]

    begin
      client.update_file(file, name: newName)
      :javascript
      flash[:notice] = "File name changed to \"#{params[:fileName]}\""
    rescue
      flash[:error] = "Error: Could not change file name"
    end

    redirect_to dashboard_id_path(session[:current_folder])
  end

  # upload files to parameter specified folder ID
  def upload

    #http://www.dropzonejs.com/
    session[:current_folder] = params[:folder_id]
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

    session[:current_folder] = params[:folder]
    download_url = Rails.cache.fetch("/download_url/#{params[:id]}", :expires_in => 10.minutes) do
      user_client.download_url(params[:id])
    end
    redirect_to download_url
  end

  # delete file
  def delete_file

    session[:current_folder] = params[:folder]
    id = params[:id]
    client = user_client
    client.delete_file(id)
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

end
