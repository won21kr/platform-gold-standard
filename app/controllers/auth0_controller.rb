class Auth0Controller < ApplicationController
  def callback
    session[:userinfo] = request.env['omniauth.auth']
    mixpanel_capture

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

      # mixpanel create user
      # tracker = Mixpanel::Tracker.new('6626ce667ecfc52ecd9b823c730fa8f5')
      # ap tracker.people.set(session[:box_id], {
      #     '$name'       => session[:userinfo]['info']['name'],
      # });

      puts "created new box user and set box_id in auth0 metadata"
    end

    redirect_to dashboard_path
  end

  def failure
    @error_msg = request.params['message']
  end

  private

  # capture mixpanel login event
  def mixpanel_capture
    tracker = Mixpanel.client
    event = tracker.track('1234', 'Login', {:username => session[:userinfo]['info']['name'], :auth => 'Auth0'})
  end

  # create folders for user and add to group
  def setup_box_account

    threads = []
    box_user = Box.user_client(session[:box_id])

    threads << Thread.new do
      # create shared folder, add collaborator
      sharedFolder = box_user.create_folder("#{session[:userinfo]['info']['name']} - Shared Files", Boxr::ROOT)
      box_user.add_collaboration(sharedFolder, {id: ENV['EMPL_ID'], type: :user}, :editor)

      # create onboarding workflow folders
      workflowFolder = box_user.create_folder("Onboarding Workflow", sharedFolder)
    end

    threads << Thread.new do
      # add user to "Customers" group
      Box.admin_client.add_user_to_group(session[:box_id], ENV['CUSTOMER_GROUP'])
    end

    threads << Thread.new do
      # create my Files folder
      box_user.create_folder("My Files", Boxr::ROOT)
    end


    threads.each { |thr| thr.join }
  end

end
