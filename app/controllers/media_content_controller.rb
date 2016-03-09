class MediaContentController < SecuredController

  def show

    session[:current_page] = "media_content"
    client = user_client
    path = "/Media\ Content"

    # get parent media folder
    mediaFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/media_folder", :expires_in => 10.minutes) do
      client.folder_from_path(path)
    end

    # get network folders
    @networks = Rails.cache.fetch("/folder/#{session[:box_id]}/media_networks", :expires_in => 10.minutes) do
      client.folder_items(mediaFolder, fields: [:id, :name])
    end

    # get all networks folders
    @nbc = @networks.find {|s| s.name == 'NBC' }
    @nbcItems = Rails.cache.fetch("/folder/#{session[:box_id]}/nbc_items", :expires_in => 10.minutes) do
      client.folder_items(@nbc, fields: [:id, :name, :description])
    end

    @nbcItems.each do |n|
      class << n
        attr_accessor :imageId, :videoId
      end
      showFolder = client.folder_items(n, fields: [:id, :name])
      imageFile = showFolder.find {|s| s.name.split('.').last == 'jpg' }
      trailerFile = showFolder.find {|s| s.name.split('.').last == 'mp4' }

      n.imageId = imageFile.id
      n.videoId = trailerFile.id
    end


    @usa = @networks.find {|s| s.name == 'USA Networks' }
    @usaItems = Rails.cache.fetch("/folder/#{session[:box_id]}/usa_items", :expires_in => 10.minutes) do
      client.folder_items(@usa, fields: [:id, :name, :description])
    end
    @usaItems.each do |n|
      class << n
        attr_accessor :imageId, :videoId
      end
      showFolder = client.folder_items(n, fields: [:id, :name])
      imageFile = showFolder.find {|s| s.name.split('.').last == 'jpg' }
      trailerFile = showFolder.find {|s| s.name.split('.').last == 'mp4' }

      n.imageId = imageFile.id
      n.videoId = trailerFile.id
    end



    @cnbc = @networks.find {|s| s.name == 'CNBC' }
    @e = @networks.find {|s| s.name == 'E!' }


    # PROMO!!!!

  end
end
