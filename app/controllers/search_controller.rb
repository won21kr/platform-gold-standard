class SearchController < SecuredController

  skip_before_filter :verify_authenticity_token

  # main search page controller
  def show

    # get user client to make API calls
    client = user_client
    @results = nil
    session[:current_page] = "search"

    # get root resource folder
    @resource = Rails.cache.fetch("/resource_folder/#{ENV['RESOURCE_FOLDER']}", :expires_in => 20.minutes) do
      puts "miss"
      client.folder_from_id(ENV['RESOURCE_FOLDER'], fields: [:id, :name, :size])
    end

    # check if search query was entered
    if((params[:search].nil? or params[:search][:query] == "") and params[:filter_query].nil?)
      # search query was not entered

      # Check if we are in the root resource folder or a sub-resource folder
      if(params[:folder_id].nil?)
        # in root resource folder

        # get resource subfolder objects
        @results = Rails.cache.fetch("/resource_folder/#{ENV['RESOURCE_FOLDER']}/subfolers", :expires_in => 20.minutes) do
          client.folder_items(ENV['RESOURCE_FOLDER'], fields: [:id, :name, :created_at, :size])
        end

        # tell view that we are in the root resource folder
        @root = true
      else
        # in a resource subfolder

        # get subfolder contents and subfolder name
        @results = client.folder_items(params[:folder_id],
                                       fields: [:id, :name, :created_at, :size])
        subFolder = client.folder_from_id(params[:folder_id], fields: [:name])
        @subName = subFolder.name
        session[:current]
      end
    else
      # a search query was enterd

      # search based on search text query or filter query
      if(!params[:search].nil?)
        @text = params[:search][:query]
      else
        @text = params[:filter_query]
      end

      # perform Box search, get results
      if (!params[:search].nil?)
        @results = client.search(@text, content_types: :name, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
        @search_type = "file name"
      elsif (params[:filter] == "file_type")
        @results = client.search(@text, content_types: :name, file_extensions: @text, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
        @search_type = "file type"
      else
        @results = client.search(@text, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
        @search_type = "file attribute"
      end

      ap @results
      @results = @results.files
    end

    # set current folder session variable
    if (!@subName.nil?)
      session[:rfolder] = subFolder.id
    else
      session[:rfolder] = ""
    end

    # attach metadata to each result file if we're not in the root folder
    if (@root.nil?)
      @results.each do |r|
        class << r
          attr_accessor :type, :product
        end

        begin
          meta = Rails.cache.fetch("/metadata/#{r.id}", :expires_in => 20.minutes) do
            puts "miss"
            client.metadata(r)
          end

          r.type = meta["Type"]
          r.product = meta["Product"]
        rescue
          r.type = ""
          r.product = ""
        end
      end
    end

  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
