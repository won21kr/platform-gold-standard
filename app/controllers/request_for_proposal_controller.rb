class RequestForProposalController < SecuredController
  skip_before_filter :verify_authenticity_token

  def show
    client = user_client

    session[:current_page] = "request_for_proposal"
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Request For Proposal"

    # get rfp documents folder, if it doesn't exist create one
    begin
      @rfpFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/rfp_folder", :expires_in => 10.minutes) do
        client.folder_from_path(path)
      end
    rescue
      parent = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        puts "miss"
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @rfpFolder = client.create_folder("Request For Proposal", parent)
    end

    ap session[:createdFolder]
    if(session[:createdFolder] != nil)
      @folderItems = client.folder_items(session[:createdFolder], fields: [:name])
    elsif
      puts "empty folder"
    end
  end

  def create_folder
    client = user_client

    parentFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Request For Proposal")
    @subRfpFolder = client.create_folder(params[:proposal], parentFolder)
    session[:createdFolder] = @subRfpFolder

    redirect_to request_for_proposal_path
  end

  def upload_file
    #http://www.dropzonejs.com/
    client = user_client

    uploaded_file = params[:file]

    folder = client.folder_from_id(session[:createdFolder].id)

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close
      box_file = client.upload_file(temp_file.path, folder)

    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "Successfully Uploaded!"
    respond_to do |format|
      format.json{ render :json => {} }
    end
  end

  def reset
    client = user_client

    #clear cache of file id and delete folder and folder items
    client.delete_folder(session[:createdFolder], recursive: true)
    session.delete(:createdFolder)

    redirect_to request_for_proposal_path
  end

  def enable_shared_link
    client = user_client
    updated_folder = client.create_shared_link_for_folder(session[:createdFolder], access: :open)
    session[:sharedLink] = updated_folder.shared_link.url

    flash[:notice] = "This folder is ready to share!"
    redirect_to request_for_proposal_path
  end

  def disable_shared_link
    client = user_client
    updated_folder = client.disable_shared_link_for_folder(session[:createdFolder])

    redirect_to request_for_proposal_path
  end

  def send_grid_method
    client = user_client
    collaboration = client.add_collaboration(session[:createdFolder], {login: params[:emailAddress], type: :user}, :viewer_uploader)

    client = SendGrid::Client.new do |c|
      c.api_user = 'carycheng77'
      c.api_key =  'CaryCheng77' #'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'
    end

    mail = SendGrid::Mail.new do |m|
      m.to = params[:emailAddress]
      m.from = params[:emailAddress]
      m.subject = 'Proposal Documents for Project'
      m.text = session[:sharedLink]
    end

    puts client.send(mail)
    # {"message":"success"}
    redirect_to request_for_proposal_path
  end
end
