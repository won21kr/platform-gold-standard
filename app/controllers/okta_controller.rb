class OktaController < ApplicationController

  skip_before_filter :verify_authenticity_token

  def callback

    puts "okta callback..."
    session[:userinfo] =  {}
    session[:userinfo]['info'] = {}

    # Get User Box ID from Okta
    okta_client = HTTPClient.new
    headers = {"Authorization" => "SSWS #{ENV['OKTA_TOKEN']}",
               "Content-Type" => "application/json",
               "Accept" => "application/json"}
    uri = "#{ENV['OKTA_DOMAIN']}/api/v1/users/#{params[:id]}"
    res = okta_client.get(uri, header: headers) # body: Oj.dump(query),
    json = Oj.load(res.body)
    session[:box_id] = json['profile']['boxId']
    session[:userinfo]['info']['name'] = json['profile']['email']


    mixpanel_capture

    if (session[:industry] == "nonprofit")
      redirect_to workflow_path
    else
      redirect_to dashboard_path
    end
  end

  def failure
    @error_msg = request.params['message']
  end


  def signup
  end

  def signup_submit

    session[:userinfo] = {}
    session[:userinfo]['info'] = {}
    session[:userinfo]['info']['name'] = params[:email]

    # set http client + header
    okta_client = HTTPClient.new
    headers = {"Authorization" => "SSWS #{ENV['OKTA_TOKEN']}",
               "Content-Type" => "application/json",
               "Accept" => "application/json"}

    # create user in Okta
    uri = "#{ENV['OKTA_DOMAIN']}/api/v1/users?activate=true"
    userQuery = {}
    userQuery[:profile] = {'firstName' => params[:first],
                           'lastName' => params[:last],
                           'email' => params[:email],
                           'login' => params[:email],
                           'mobilePhone' => ""}
    userQuery[:credentials] = {'password' => params[:password]}
    res = okta_client.post(uri, body: Oj.dump(userQuery), header: headers)
    json = Oj.load(res.body)

    # did we receive an error creating the okta user?
    if (!json['errorCode'].nil?)
      flash[:error] = "Error #{json['errorCauses'][0]['errorSummary']}"
      redirect_to okta_signup_path
    else
      # create box app user
      box_user = Box.admin_client.create_user(session[:userinfo]['info']['name'], is_platform_access_only: true)
      session[:box_id] = box_user.id

      # store the box id in Okta as customer profile metadata
      uri = "#{ENV['OKTA_DOMAIN']}/api/v1/users/#{json['id']}"
      query = {}
      query[:profile] = {}
      query[:profile][:boxId] = session[:box_id]
      res = okta_client.post(uri, body: Oj.dump(query), header: headers)

      mixpanel_capture
      setup_box_account
      redirect_to dashboard_path
    end
  end


  private

  # capture mixpanel login event
  def mixpanel_capture
    tracker = Mixpanel.client
    tracker.people.set(session[:box_id], {'$email' => session[:userinfo]['info']['name']})
    tracker.people.increment(session[:box_id], {'Logins' => 1})
    tracker.track(session[:box_id], 'Login', {:auth => 'Okta'})
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
