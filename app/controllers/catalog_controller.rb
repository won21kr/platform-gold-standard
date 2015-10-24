class CatalogController < SecuredController

  helper_method :get_thumbnail

  # main catalog controller
  def show

    # get user client obj and file ID
    client = user_client
    @fileId = '41372508334'
    session[:fileId] = @fileId

    @file = client.file_from_id(@fileId)

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
