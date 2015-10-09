class SearchController < SecuredController


  def show

    client = user_client
    @results = nil
    session[:current_page] = "resources"


    if(params[:search].nil? or params[:search][:query] == "")

      # did we redirect to a subfolder?
      # If yes, fetch subfolder contents, else fetch resource folders
      if(params[:folder_id].nil?)

      else
        puts "get subfolder"
        @results = client.folder_items(params[:folder_id],
                                       fields: [:id, :name, :created_at, :size])
      end

      ap @results
    else
      @text = params[:search][:query]
      @results = client.search(@text, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
      @results = @results.files
    end

  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
