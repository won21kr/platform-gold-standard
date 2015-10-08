class SearchController < SecuredController


  def show

    client = user_client
    @results = nil
    session[:current_page] = "resources"

    ap params

    if(params[:search].nil? or params[:search][:query] == "")
      @results = client.folder_items(ENV['RESOURCE_FOLDER'],
                                     fields: [:id, :name, :created_at, :size])
    else
      @text = params[:search][:query]
      @results = client.search(@text)
      @results = @results.files
    end

  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
