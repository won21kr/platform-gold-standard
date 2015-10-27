class CatalogController < SecuredController

  helper_method :get_thumbnail

  # main catalog controller
  def show

    # get user client obj and file ID
    client = user_client
    @myFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
      client.folder_from_path('Product Catalog')
    end

    @files = client.folder_items(@myFolder, fields: [:name, :id]).files


    @fileId = '41372508334'
    session[:fileId] = @fileId

    @file = client.file_from_id(@fileId)

  end

  def thumbnail

    image = Rails.cache.fetch("/image_thumbnail/#{params[:id]}", :expires_in => 10.minutes) do
      puts "miss!"
      user_client.thumbnail(params[:id], min_height: 256, min_width: 256)
    end

    send_data image, :type => 'image/png', :disposition => 'inline'
  end

  # preview file
  def preview
    embed_url = user_client.embed_url(params[:id])
  end

  private
# create user client and return
  def user_client
    Box.user_client(session[:box_id])
  end

end
