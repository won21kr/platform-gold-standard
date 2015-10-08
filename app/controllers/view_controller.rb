
class ViewController < SecuredController

  helper_method :get_thumbnail

  def show

    client = user_client
    @fileId = params[:id]
    session[:fileId] = @fileId

    @file = client.file_from_id(params[:id])

    # fetch and reorder comments
    comments = client.file_comments(@file)
    @comments = Array.new
    while (comments.size != 0)
      @comments.push(comments.pop)
    end
  end

  def comment

    client = user_client
    comment = params[:comment]

    # get file and add comment
    file = client.file_from_id(session[:fileId])
    client.add_comment_to_file(file, message: comment)

    redirect_to view_doc_path(session[:fileId])
  end

  def get_thumbnail(id)

    user = Rails.cache.fetch("/avatar_urls/#{id}", :expires_in => 10.minutes) do
      puts "cache miss"
      Box.admin_client.user_from_id(id, fields: [:avatar_url])
    end
    user.avatar_url
  end

  def download
    download_url = Rails.cache.fetch("/download_url/#{params[:id]}", :expires_in => 10.minutes) do
      user_client.download_url(params[:id])
    end

    download_url
  end

  def preview
    embed_url = user_client.embed_url(params[:id])
  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
