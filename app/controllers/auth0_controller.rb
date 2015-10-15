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

    redirect_to dashboard_path
  end

  def failure
    @error_msg = request.params['message']
  end

  private

  def setup_box_account
    #puts "user: #{session[:box_id]}"
    box_user = Box.user_client(session[:box_id])

    # add user to "Customers" group
    Box.admin_client.add_user_to_group(session[:box_id], ENV['CUSTOMER_GROUP'])

    # create new user folders and add collaborator
    sharedFolder = box_user.create_folder("#{session[:userinfo]['info']['name']} - Shared Files", Boxr::ROOT)
    box_user.add_collaboration(sharedFolder, {id: ENV['EMPL_ID'], type: :user}, :editor)
    box_user.create_folder("My Files", Boxr::ROOT)

    # create onboarding workflow folders, add automation
    workflowFolder = box_user.create_folder("Onboarding Workflow", sharedFolder)
    box_user.create_folder("Pending Approval", workflowFolder)
    box_user.create_folder("Signature Required", workflowFolder)
    box_user.create_folder("Completed", workflowFolder)

  end

end
