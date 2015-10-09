class SearchController < SecuredController


  def show

    client = user_client
    @results = nil
    session[:current_page] = "resources"

    # get root resource folder
    @resource = Rails.cache.fetch("/resource_folder/#{ENV['RESOURCE_FOLDER']}", :expires_in => 20.minutes) do
      puts "miss"
      client.folder_from_id(ENV['RESOURCE_FOLDER'], fields: [:id, :name, :size])
    end

    # check if search query was entered
    if(params[:search].nil? or params[:search][:query] == "")

      # Check if we are in the root resource folder or a sub-resource folder
      if(params[:folder_id].nil?)
        # get resource subfolders
        @results = client.folder_items(ENV['RESOURCE_FOLDER'],
                                       fields: [:id, :name, :created_at, :size])
        @root = true
      else

        # get subfolder contents and subfolder name
        @results = client.folder_items(params[:folder_id],
                                       fields: [:id, :name, :created_at, :size])
        subFolder = client.folder_from_id(params[:folder_id], fields: [:name])
        @subName = subFolder.name
        session[:current]
      end
    else

      # search based on posted query
      @text = params[:search][:query]
      @results = client.search(@text, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
      @results = @results.files
    end

    if (!@subName.nil?)
      session[:rfolder] = subFolder.id
    else
      session[:rfolder] = ""
    end

  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
