class Auth0Controller < ApplicationController
  def callback
    session[:userinfo] = request.env['omniauth.auth']

    auth0_meta = session[:userinfo]['extra']['raw_info']['app_metadata']
    if auth0_meta and auth0_meta.has_key?('box_id')
      puts "found box_id in auth0 metadata"
      session[:box_id] = auth0_meta['box_id']

    else
      #create box app user
      uid = session[:userinfo]['uid']
      box_name = session[:userinfo]['info']['name']
      box_user = Box.admin_client.create_user(box_name, is_platform_access_only: true)
      session[:box_id] = box_user.id

      #store the box_id in Auth0
      Auth0API.client.patch_user_metadata(uid, { box_id: box_user.id})

      setup_box_account


      puts "created new box user and set box_id in auth0 metadata"
    end

    assign_agent(session[:box_id])

    resource = Box.user_client(ENV['RUSER_ID'])
    folder = resource.folder_from_id(ENV['AVATARS_ID'])
    items = resource.folder_items(folder).files
    items.each do |f|

      meta = resource.metadata(f)
      if(meta['agent_id'] == session[:agent])
        session[:agent_url] = resource.download_url(f)
      end

    end


    redirect_to dashboard_path
  end

  def failure
    @error_msg = request.params['message']
  end

  def assign_agent(id)
    num = Integer(session[:box_id]).modulo(3)

    if(num == 0)
      session[:agent] = ENV['AGENT_ID1']
    elsif(num == 1)
      session[:agent] = ENV['AGENT_ID2']
    else
      session[:agent] = ENV['AGENT_ID3']
    end
  end

  private

  def setup_box_account
    #puts "user: #{session[:box_id]}"
    #box_user = Box.user_client(session[:box_id])

    resource = Box.user_client(ENV['RUSER_ID'])

    folder = resource.folder_from_id(ENV['RESOURCES_ID'])

    resource.add_collaboration(folder, {id: session[:box_id], type: :user}, :viewer)

    #this is where you set up the new app user's initial files, folders, permissions, etc.
    #box_user.create_folder("Test Folder", Boxr::ROOT)
    #box_user.upload_file(Rails.root.join("docs","test.txt"), Boxr::ROOT)
  end

end
