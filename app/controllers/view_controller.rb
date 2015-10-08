
class ViewController < SecuredController


  def show

  end


  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
