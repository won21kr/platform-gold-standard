
class ViewController < SecuredController

  helper_method :get_thumbnail

  # main view controller
  def show

    # get user client obj and file ID
    client = user_client
    @fileId = params[:id]
    session[:fileId] = @fileId
    session[:current_page] = "resources"

    @file = client.file_from_id(params[:id])

    # fetch and reorder file comments
    comments = client.file_comments(@file)
    @comments = Array.new
    while (comments.size != 0)
      @comments.push(comments.pop)
    end

  end

  # add comment to file
  def comment

    client = user_client
    comment = params[:comment]

    # get file and add comment
    file = client.file_from_id(session[:fileId])
    client.add_comment_to_file(file, message: comment)

    redirect_to view_doc_path(session[:fileId])
  end

  # get and return Box user avatar thumbnail URL
  def get_thumbnail(id)

    avatar_url = Rails.cache.fetch("/avatar_urls/#{id}", :expires_in => 10.minutes) do
      puts "cache miss"
      begin
        Box.admin_client.user_from_id(id, fields: [:avatar_url]).avatar_url
      rescue
        puts "own avatar..."
        Box.admin_client.user_from_id(session[:box_id], fields: [:avatar_url]).avatar_url
      end
    end
    avatar_url
  end

  # download file
  def download
    download_url = Rails.cache.fetch("/download_url/#{params[:id]}", :expires_in => 10.minutes) do
      user_client.download_url(params[:id])
    end

    download_url
  end

  # preview file
  def preview
    embed_url = user_client.embed_url(params[:id])
  end

  private

  def user_client
    Box.user_client(session[:box_id])
  end

end
