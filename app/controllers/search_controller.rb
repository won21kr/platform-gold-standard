class SearchController < SecuredController

  skip_before_filter :verify_authenticity_token
  BOX_CLIENT = HTTPClient.new
  BOX_CLIENT.cookie_manager = nil
  BOX_CLIENT.send_timeout = 3600 #one hour; needed for lengthy uploads
  #BOX_CLIENT.agent_name = "Boxr/#{Boxr::VERSION}"
  #BOX_CLIENT.transparent_gzip_decompression = true

  # main search page controller
  def show

    # get user client to make API calls
    client = user_client
    @results = nil
    session[:current_page] = "search"

    # get root resource folder
    @resource = Rails.cache.fetch("/resource_folder/#{ENV['RESOURCE_FOLDER']}", :expires_in => 15.minutes) do
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
        @results = Rails.cache.fetch("/resource_folder/#{ENV['RESOURCE_FOLDER']}/subfolers", :expires_in => 15.minutes) do
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

      ap params
      # perform Box search, get results
      if (!params[:search].nil?)
        @results = client.search(@text, content_types: :name, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
        @search_type = "file name"
      elsif (params[:filter] == "file_type")
        @results = client.search(@text, content_types: :name, file_extensions: @text, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
        @search_type = "file type"
      else
        mdfilters = {"templateKey" => "#{ENV['METADATA_KEY']}", "scope" => "enterprise",
                     "filters" => {"#{params["key"]}" => "#{params["filter_query"]}"}}
        @results = client.search(mdfilters: mdfilters, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
        @search_type = params["key"]
      end

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
          attr_accessor :type, :audience
        end

        begin
          meta = Rails.cache.fetch("/metadata/#{r.id}", :expires_in => 15.minutes) do
            puts "miss"
            client.all_metadata(r)["entries"]
          end

          meta.each do |m|
            if (m["$template"] == "#{ENV['METADATA_KEY']}")
              r.type = m["type"]
              r.audience = m["audience"]
            end
          end

        rescue
          r.type = ""
          r.audience = ""
        end
      end
    end

  end

  def processed_response(res)
    body_json = Oj.load(res.body)
    return BoxrMash.new(body_json)
  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
