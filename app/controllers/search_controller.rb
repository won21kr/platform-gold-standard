class SearchController < SecuredController

  skip_before_filter :verify_authenticity_token
  BOX_CLIENT = HTTPClient.new
  # BOX_CLIENT.cookie_manager = nil
  BOX_CLIENT.send_timeout = 3600 #one hour; needed for lengthy uploads

  # main search page controller
  def show

    # get user client to make API calls
    client = user_client
    @results = nil
    @industry = false
    session[:current_page] = "search"
    mixpanel_tab_event("Resources", "Main Page")
    
    # has this been configured for an industry?
    if (!session[:industry_resources].nil?)
      @industry = true
      resourceFolderId = session[:industry_resources]

      # get root industry resource folder
      resource = Rails.cache.fetch("/resource_folder/#{resourceFolderId}", :expires_in => 15.minutes) do
        puts "miss"
        client.folder_from_id(resourceFolderId, fields: [:id, :name, :size])
      end
      # need roots, subname, and results
      if(params[:folder_id].nil?)
        @root = true
        @results = Rails.cache.fetch("/resource_folder/#{resourceFolderId}/subfolders", :expires_in => 15.minutes) do
          client.folder_items(resourceFolderId, fields: [:id, :name, :content_modified_at, :description])
        end
      else
        # get subfolder contents and subfolder name
        @results = Rails.cache.fetch("/resource_folder/#{resourceFolderId}/#{params[:folder_id]}", :expires_in => 15.minutes) do
          puts "miss"
          client.folder_items(params[:folder_id], fields: [:id, :name, :created_at, :parent])
        end

        # get subfolder
        subFolder = @results.first.parent
        @subName = subFolder.name
      end

    # get generic resource folder
    else

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
          @results = Rails.cache.fetch("/resource_folder/#{ENV['RESOURCE_FOLDER']}/subfolders", :expires_in => 15.minutes) do
            client.folder_items(ENV['RESOURCE_FOLDER'], fields: [:id, :name, :content_modified_at, :description])
          end

          # tell view that we are in the root resource folder
          @root = true
        else
          # in a resource subfolder

          # get subfolder contents and subfolder name
          @results = Rails.cache.fetch("/resource_folder/#{ENV['RESOURCE_FOLDER']}/#{params[:folder_id]}", :expires_in => 15.minutes) do
            puts "miss"
            client.folder_items(params[:folder_id], fields: [:id, :name, :created_at, :parent])
          end

          # get subfolder
          subFolder = @results.first.parent
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
          mixpanel_tab_event("Resources", "Search File Name")
        elsif (params[:filter] == "file_type")
          @results = client.search(@text, content_types: :name, file_extensions: @text, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
          @search_type = "file type"
          mixpanel_tab_event("Resources", "Search File Type")
        else
          mixpanel_tab_event("Resources", "Search Metadata")
          mdfilters = {"templateKey" => "#{ENV['METADATA_KEY']}", "scope" => "enterprise",
                       "filters" => {"#{params["key"]}" => "#{params["filter_query"]}"}}
          @results = client.search(mdfilters: mdfilters, ancestor_folder_ids: ENV['RESOURCE_FOLDER'])
          # @search_type = params["key"]

          # little hack to change message name
          if(params["key"] == 'type')
            @search_type = "category"
          elsif(params["key"] == 'audience')
            @search_type = "privacy"
          end
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

  end

  def processed_response(res)
    body_json = Oj.load(res.body)
    return BoxrMash.new(body_json)
  end

end
