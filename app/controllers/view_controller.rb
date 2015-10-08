
class ViewController < SecuredController


  def show

    client = user_client
    @preview_url = client.embed_url(params[:id])

  end


  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
