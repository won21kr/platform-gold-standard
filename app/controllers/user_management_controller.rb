class UserManagementController < ApplicationController

  skip_before_filter :verify_authenticity_token
  DO_NOT_DELETE_IDS = [ENV['EMPL_ID'], ENV['CUSTOMER_ID'], ENV['CRED_SPECIALIST'],
                      '260539217', ENV['USER_DATA_ID']]

  def show
    if !session[:usermanage_pass].present?
      redirect_to '/user-management-password'
    else

      admin = Box.admin_client
      @appUsers = admin.all_users

      # remove all non app users and special app users
      @appUsers.delete_if {|u| !u.login.include? "AppUser" or DO_NOT_DELETE_IDS.include? u.id}

      # sort array by date last modified
      @appUsers = @appUsers.sort {|a,b| a.modified_at <=> b.modified_at}
      @appUsers = @appUsers.reverse

      # add okta accounts

      # add auth0 accounts
      logins = Auth0API.client.users
      @appUsers.each do |u|
        class << u
          attr_accessor :idp, :idp_id
        end
        if (logins.any? {|login| login["box_id"] == u.id})
          u.idp = "Auth0"

          # get Auth0 id
          ndx = logins.find_index {|l| l["box_id"] == u.id}
          u.idp_id = logins[ndx]["user_id"]
        else
          u.idp = "Okta"
        end

      end

    end
  end

  # delete auth0 user and associated app user account
  def delete_user

    user_id = params[:auth0Id]
    box_id = params[:boxId]
    name = params[:name]
    box_admin = Box.admin_client

    begin
      auth0 = Auth0API.client.delete_user(user_id)
      deleted = box_admin.delete_user(box_id, notify: false, force: true)
      ap deleted
      ap auth0
      flash[:notice] = "Deleted user #{name}"
    rescue
      flash[:notice] = "Could not delete user #{name}"
    end

    redirect_to user_management_path
  end

  # provision new Okta user
  def provision_okta_user

    first = params[:firstname]
    last = params[:lastname]
    email = params[:username]
    pass = params[:password]

    # create new okta user
    okta_client = HTTPClient.new
    headers = {"Authorization" => "SSWS #{ENV['OKTA_TOKEN']}",
               "Content-Type" => "application/json",
               "Accept" => "application/json"}

    # create user in Okta
    uri = "#{ENV['OKTA_DOMAIN']}/api/v1/users?activate=true"
    userQuery = {}
    userQuery[:profile] = {'firstName' => first,
                           'lastName' => last,
                           'email' => email,
                           'login' => email,
                           'mobilePhone' => ""}
    userQuery[:credentials] = {'password' => pass}
    res = okta_client.post(uri, body: Oj.dump(userQuery), header: headers)
    json = Oj.load(res.body)

    # did we receive an error creating the okta user?
    if (!json['errorCode'].nil?)
      flash[:notice] = "Error #{json['errorCauses'][0]['errorSummary']}"
    else
      # create box app user
      box_user = Box.admin_client.create_user(email, is_platform_access_only: true)

      # store the box id in Okta as metadata
      uri = "#{ENV['OKTA_DOMAIN']}/api/v1/users/#{json['id']}"
      query = {}
      query[:profile] = {}
      query[:profile][:boxId] = box_user.id
      res = okta_client.post(uri, body: Oj.dump(query), header: headers)
      setup_box_account(email, box_user.id)
      send_grid(email, pass, first)
      flash[:notice] = "Provisioned new account. Email sent to #{email}"
    end

    redirect_to user_management_path
  end

  def enter_password_submit
    password = params[:password]

    if(password == ENV['USER_MANAGE_PASS'])
      session[:usermanage_pass] = true
      redirect_to user_management_path
    else
      flash[:notice] = "Invalid password"
      redirect_to enter_password_path
    end
  end

  # Email newly provisioned user
  def send_grid(email, password, name)

    client = SendGrid::Client.new do |c|
      c.api_user = 'carycheng77'
      c.api_key =  'CaryCheng77' #'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'
    end

    mail = SendGrid::Mail.new do |m|
      m.to = email
      m.from = email
      m.subject = "Okta Credentials for Platform Standard app"
      m.text = "#{name},\n\nHere are you credentials.\n\nUsername: #{email}\n\nPassword: #{password}\n\nApplication URL: #{ENV['ACTIVE_URL']}"
    end

    client.send(mail)
  end

  # parse csv and create new users
  def create_users_from_csv

  end



  private

  # create folders for user and add to group
  def setup_box_account(username, id)

    threads = []
    box_user = Box.user_client(id)

    threads << Thread.new do
      # create shared folder, add collaborator
      sharedFolder = box_user.create_folder("#{username} - Shared Files", Boxr::ROOT)
      box_user.add_collaboration(sharedFolder, {id: ENV['EMPL_ID'], type: :user}, :editor)

      # create onboarding workflow folders
      workflowFolder = box_user.create_folder("Onboarding Workflow", sharedFolder)
    end

    threads << Thread.new do
      # add user to "Customers" group
      Box.admin_client.add_user_to_group(id, ENV['CUSTOMER_GROUP'])
    end

    threads << Thread.new do
      # create my Files folder
      box_user.create_folder("My Files", Boxr::ROOT)
    end

    threads.each { |thr| thr.join }
  end

end
