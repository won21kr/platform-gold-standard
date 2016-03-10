class MediaContentController < SecuredController

  skip_before_filter :verify_authenticity_token

  def show

    session[:current_page] = "media_content"
    client = user_client
    path = "/Media\ Content"
    threads = []

    # get parent media folder
    mediaFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/media_folder", :expires_in => 10.minutes) do
      client.folder_from_path(path)
    end

    # get network folders
    @networks = Rails.cache.fetch("/folder/#{session[:box_id]}/media_networks", :expires_in => 10.minutes) do
      client.folder_items(mediaFolder, fields: [:id, :name])
    end


    # NBC Network
    @nbc = @networks.find {|s| s.name == 'NBC' }
    @nbcItems = Rails.cache.fetch("/folder/#{session[:box_id]}/nbc_items", :expires_in => 10.minutes) do
      client.folder_items(@nbc, fields: [:id, :name, :description, :created_at])
    end

    @nbcItems.each do |n|
      threads << Thread.new do
        class << n
          attr_accessor :imageId, :videoId, :videoDescription, :videoName,
                        :rating, :staring
        end

        # get network folder items
        showFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/nbc_items/#{n.id}", :expires_in => 10.minutes) do
          client.folder_items(n, fields: [:id, :name, :description])
        end
        imageFile = showFolder.find {|s| s.name.split('.').last == 'jpg' }
        trailerFile = showFolder.find {|s| s.name.split('.').last == 'mp4' }

        # get video file metadata
        meta = Rails.cache.fetch("/folder/#{session[:box_id]}/nbc_items/#{n.id}_meta", :expires_in => 10.minutes) do
          client.all_metadata(trailerFile)["entries"].first
        end

        # add file attributes
        n.imageId = imageFile.id
        n.videoId = trailerFile.id
        n.videoDescription = trailerFile.description
        n.videoName = trailerFile.name
        n.staring = meta["Related Names"]
        n.rating = meta["Content Rating"]
      end

    end


    # USA Network
    @usa = @networks.find {|s| s.name == 'USA Network' }
    @usaItems = Rails.cache.fetch("/folder/#{session[:box_id]}/usa_items", :expires_in => 10.minutes) do
      client.folder_items(@usa, fields: [:id, :name, :description, :created_at])
    end
    @usaItems.each do |n|
      threads << Thread.new do
        class << n
          attr_accessor :imageId, :videoId, :videoDescription, :videoName,
                        :rating, :staring
        end
        # get network folder items
        showFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/usa_items/#{n.id}", :expires_in => 10.minutes) do
          client.folder_items(n, fields: [:id, :name, :description])
        end
        imageFile = showFolder.find {|s| s.name.split('.').last == 'jpg' }
        trailerFile = showFolder.find {|s| s.name.split('.').last == 'mp4' }

        # get video file metadata
        meta = Rails.cache.fetch("/folder/#{session[:box_id]}/usa_items/#{n.id}_meta", :expires_in => 10.minutes) do
          client.all_metadata(trailerFile)["entries"].first
        end

        # add file attributes
        n.imageId = imageFile.id
        n.videoId = trailerFile.id
        n.videoDescription = trailerFile.description
        n.videoName = trailerFile.name
        n.staring = meta["Related Names"]
        n.rating = meta["Content Rating"]
      end
    end

    threads.each { |thr| thr.join }
  end

  # search for TV show
  def search_show
    query = params[:search]
    client = user_client

    @results = client.search(query, content_types: :name, type: :folder, ancestor_folder_ids: ENV['MEDIA_CONTENT_FOLDER'])
    ap @results

    if (@results.size == 0)
      @message = "There are 0 shows matching your search of \"#{query}\""
    elsif(@results.size == 1)
      @message = "There is 1 show matching your search of \"#{query}\""
    else
      @message = "There are #{@results.size} shows matching your search of \"#{query}\""
    end

  end



end
