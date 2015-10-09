class DashboardController < SecuredController

  def show

    client = user_client
    # folder = user_client.folder_from_id('4267363735')
    rootFolders = client.folder_items(Boxr::ROOT)
    session[:current_page] = "vault"

    @myFolder = client.folder_from_path('My Files')
    @sharedFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
    @sharedFolder.name = "Shared Files"

    # set active folder tab
    if(params[:id])
      puts "changing active folder"
      @currentFolder = params[:id]
    else
      @currentFolder = @myFolder.id
    end
    session[:current_folder] = @currentFolder

    # get files for dashboard display
    if(@currentFolder == @myFolder.id)
      @files = client.folder_items(@myFolder, fields: [:name, :id, :created_at])
    elsif(@currentFolder == @sharedFolder.id)
      @files = client.folder_items(@sharedFolder, fields: [:name, :id, :created_at])
    end
  end

  def upload
    #http://www.dropzonejs.com/

    uploaded_file = params[:file]
    folder = params[:folder_id]

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_user = Box.user_client(session[:box_id])
      #vault_folder = vault_folder(box_user)

      box_file = box_user.upload_file(temp_file.path, folder)
      box_user.create_metadata(box_file, session[:meta])

    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    respond_to do |format|
      format.json{ render :json => {} }
    end
    sleep(5)
  end

  def thumbnail
    image = Rails.cache.fetch("/image_thumbnail/#{params[:id]}", :expires_in => 20.minutes) do
      puts "miss!"
      user_client.thumbnail(params[:id], min_height: 256, min_width: 256)
    end

    send_data image, :type => 'image/png', :disposition => 'inline'
  end

  def preview
    embed_url = user_client.embed_url(params[:id])

    redirect_to embed_url
  end

  def download
    download_url = Rails.cache.fetch("/download_url/#{params[:id]}", :expires_in => 10.minutes) do
      user_client.download_url(params[:id])
    end
    redirect_to download_url
  end

  def delete_file

    id = params[:id]
    client = user_client
    client.delete_file(id)

    redirect_to dashboard_id_path(session[:current_folder])
  end

  def share_file

    id = params[:id]
    client = user_client

    # get shared folder, then move file into shared folder
    sharedFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
    client.move_file(id, sharedFolder)

    redirect_to dashboard_id_path(sharedFolder.id)
  end

  def unshare_file

    id = params[:id]
    client = user_client

    # get my folder, then move file into my folder
    myFolder = client.folder_from_path('My Files')
    client.move_file(id, myFolder)

    redirect_to dashboard_id_path(myFolder.id)
  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
