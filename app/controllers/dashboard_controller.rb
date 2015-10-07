class DashboardController < SecuredController

  def show

    client = user_client
    # folder = user_client.folder_from_id('4267363735')
    rootFolders = client.folder_items(Boxr::ROOT)

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

    # get files for dashboard display
    if(@currentFolder == @myFolder.id)
      @files = client.folder_items(@myFolder, fields: [:name, :id, :created_at])
    elsif(@currentFolder == @sharedFolder.id)
      @files = client.folder_items(@sharedFolder, fields: [:created_at])
    end


    # @files.each do |f|
    #   class << f
    #     attr_accessor :created_at
    #   end
    #
    #   file = client.file_from_id(f.id, fields: [:created_at])
    #   f.created_at = file.created_at
    # end

  end

  def upload_claim

    meta = Hash.new
    ap params

    # add file metadata
    id = session[:claimId].to_s
    puts id
    meta.store("Claim ID", id)
    meta.store("Claim Type", params[:claimType])
    meta.store("Claim Date", params[:claimDate])
    meta.store("Claim Value", params[:claimValue])
    meta.store("Claim Desciption", params[:description])
    meta.store("Claim Status", "Pending")
    session[:meta] = meta
    ap meta

    @folder = user_client.folder_from_id(params[:id])

  end

  def new_claim
    puts "creating claim"

    session[:claimId] = rand(10 ** 10)

    # create new claim Folder
    @newClaimFolder = user_client.create_folder("Claim - ##{session[:claimId]}", Boxr::ROOT)
    user_client.add_collaboration(@newClaimFolder, {id: session[:agent], type: :user}, :editor)

  end

  def display_claim

    @comments = []
    @claimFolderId = params[:id]
    @claimFolder = user_client.folder_from_id(@claimFolderId)
    @items = user_client.folder_items(@claimFolderId).files

    begin
      if(request.post?)
        puts "post request\ncomment: #{params[:comment]}"
        comment = params[:comment]
        user_client.add_comment_to_file(@items[0], message: comment)
      end
    rescue
      puts "Error in processing comment"
    end

    if(@items.length > 0)
      @comments = user_client.file_comments(@items[0])
      ap @comments
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
    image = Rails.cache.fetch("/image_thumbnail/#{params[:id]}", :expires_in => 10.minutes) do
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

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
