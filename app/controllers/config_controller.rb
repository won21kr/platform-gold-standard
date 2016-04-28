class ConfigController < ApplicationController

  skip_before_filter :verify_authenticity_token
  # before_action :check_config

  def show
    puts "config page get..."

    # check if the tabs have been configured yet
    started = true

    if session[:vault].blank?
      session[:vault] = 'on'
      started = false
    end

    if(started == false)
      session[:vault] = 'on'
      session[:resources] = 'on'
      session[:onboarding] = 'on'
      session[:catalog] = 'off'

      # NEW FEATURES
      session[:medical_credentialing] = "off"
      session[:loan_docs] = "off"
      session[:upload_sign] = "off"
      session[:tax_return] = "off"
      session[:create_claim] = "off"
      # session[:account_sub] = "off"
      # session[:dicom_viewer] = "off"
      # session[:media_content] = "off"
      session[:eventstream] = "off"

      # Okta
      # session[:okta] = "off"
    end

    config_url
  end

  def twilio_method
    account_sid = "AC4c44fc31f1d7446784b3e065f92eb4e6"
    auth_token = "5ad821b20cff339979cd0a9d42e1a05d"
    client = Twilio::REST::Client.new account_sid, auth_token
    tracker = Mixpanel.client
    event = tracker.track('1234', 'Configuration - Twilio')

    from = params[:region] # Your Twilio number
    puts "Values from the twilio modal:\nInput Phone Number: #{params[:phoneNumber]}\nInput Region: #{params[:region]}"

    friends = {
      params[:phoneNumber] => "Boxr"
    }
    friends.each do |key, value|
      client.account.messages.create(
      :from => from,
      :to => key,
      :body => "Here's your custom app URL. Have a kickass demo! " + session[:config_url]
      )
    end
    redirect_to config_path
  end

  def send_grid_method

    tracker = Mixpanel.client
    event = tracker.track('1234', 'Configuration - SendGrid')
    client = SendGrid::Client.new do |c|
      c.api_user = 'carycheng77'
      c.api_key =  'CaryCheng77' #'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'
    end

    mail = SendGrid::Mail.new do |m|
      m.to = params[:emailAddress]
      m.from = params[:emailAddress]
      m.subject = "Your custom Platform Standard app"
      m.text = "Here\'s the custom-configured Platform Standard app URL you created. Have a kickass demo! " + session[:config_url]
    end

    puts client.send(mail)
    # {"message":"success"}
    redirect_to config_path
  end

  def post_config

    puts 'posting configuration page....'

    session[:company] = params[:company]
    session[:logo] = params[:logo]

    if !params[:navbar_color].blank? and params[:navbar_color] != ""
      if (params[:navbar_color][0] == '#')
        session[:navbar_color] = params[:navbar_color]
      else
        session[:navbar_color] = '#' + params[:navbar_color]
      end
    else
      session[:navbar_color] = nil
    end

    session[:background] = params[:background]
    session[:alt_text] = params[:alt_text]

    # Okta configuration
    # session[:okta] = !params[:okta].blank? ? 'on' : 'off'

    # check feature tab configuration
    session[:resources] = !params[:resources].blank? ? 'on' : 'off'
    session[:onboarding] = !params[:onboarding].blank? ? 'on' : 'off'
    session[:medical_credentialing] = !params[:medical_credentialing].blank? ? 'on' : 'off'
    session[:loan_docs] = !params[:loan_docs].blank? ? 'on' : 'off'
    session[:upload_sign] = !params[:uploadsign].blank? ? 'on' : 'off'
    session[:tax_return] = !params[:taxreturn].blank? ? 'on' : 'off'
    session[:create_claim] = !params[:createclaim].blank? ? 'on' : 'off'
    # session[:request_for_proposal] = !params[:requestforproposal].blank? ? 'on' : 'off'
    # session[:account_sub] = !params[:acctsub].blank? ? 'on' : 'off'
    # session[:dicom_viewer] = !params[:dicom_viewer].blank? ? 'on' : 'off'
    # session[:media_content] = !params[:media_content].blank? ? 'on' : 'off'
    session[:eventstream] = !params[:eventstream].blank? ? 'on' : 'off'

    # capture all user data and upload to csv, only if in production
    if (ENV['RACK_ENV'] == 'production')
      capture_user_data
      # Mixpanel capture event
      mixpanel_capture
    end
    redirect_to config_path
  end

  # capture user + current configurations, modify csv, & upload to Box
  def capture_user_data

    # add a user config row entry
    user_data = Userconfig.new(username: session[:userinfo].blank? ? "" : session[:userinfo]['info']['name'],
                               date: DateTime.now,
                               company: session[:company],
                               okta: session[:okta] == "on" ? true : false,
                               logo_url: session[:logo],
                               home_url: session[:background],
                               vault: true,
                               resources: session[:resources] == "on" ? true : false,
                               onboarding_tasks: session[:onboarding] == "on" ? true : false,
                               medical_credentialing: session[:medical_credentialing] == "on" ? true : false,
                               loan_origination: session[:loan_docs] == "on" ? true : false,
                               upload_sign: session[:upload_sign] == "on" ? true : false,
                               tax_return: session[:tax_return] == "on" ? true : false,
                               submit_claim: session[:create_claim] == "on" ? true : false,
                               eventstream: session[:eventstream] == "on" ? true : false)
    user_data.save
  end

  # clear session
  def reset_config
    tracker = Mixpanel.client
    event = tracker.track('1234', 'Configuration - Reset')
    session.clear
    redirect_to config_path
  end

  private

  def mixpanel_capture

    configuration = {}

    configuration[:username] = session[:userinfo]['info']['name'] unless session[:user].blank?
    configuration[:company] = session[:company] unless session[:company].blank?
    # configuration[:okta] = session[:okta] unless session[:okta] != "on"
    configuration[:logo_url] = session[:logo] unless session[:logo].blank?
    configuration[:home_url] = session[:background] unless session[:background].blank?
    configuration[:alt_text] = session[:alt_text] unless session[:alt_text].blank?
    # configuration[:tab_configuration] = tab_config

    tracker = Mixpanel.client
    event = tracker.track('1234', 'Configuration - General', configuration)

    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'My Vault')
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Resources') unless session[:resources] != "on"
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Onboarding Tasks') unless session[:onboarding] != "on"
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Medical Credentialing') unless session[:medical_credentialing] != "on"
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Loan Origination') unless session[:loan_docs] != "on"
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Upload & Sign') unless session[:upload_sign] != "on"
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Tax Return') unless session[:tax_return] != "on"
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Submit A Claim') unless session[:create_claim] != "on"
    tracker.track('1234', 'Configuration - Tabs', 'tab_configuration' => 'Box Events') unless session[:eventstream] != "on"
    # tracker.track('1234', 'Configuration', 'tab_configuration' => 'DICOM Viewer') unless session[:dicom_viewer] != "on"
  end

  # construct configuration URL
  def config_url
    template = Addressable::Template.new("#{ENV['ACTIVE_URL']}{?query*}")

    query = {}
    query[""] =
    query["company"] = session[:company] unless session[:company].blank?
    query["logo"] = session[:logo] unless session[:logo].blank?
    query["alt_text"] = session[:alt_text] unless session[:alt_text].blank?
    query["background"] = session[:background] unless session[:background].blank?
    query["create_claim"] = session[:create_claim] unless session[:create_claim].blank?
    # query["request_for_proposal"] = session[:request_for_proposal] unless session[:request_for_proposal].blank?
    query["back_color"] = session[:navbar_color][1..-1] unless session[:navbar_color].blank?

    # query["okta"] = session[:okta]
    query["vault"] = session[:vault]
    query["resources"] = session[:resources]
    query["onboarding"] = session[:onboarding]
    query["med_credentialing"] = session[:medical_credentialing]
    query["loan_docs"] = session[:loan_docs]
    query["tax_return"] = session[:tax_return]
    query["upload_sign"] = session[:upload_sign]
    # query["dicom_viewer"] = session[:dicom_viewer]
    # query["media_content"] = session[:media_content]
    query["eventstream"] = session[:eventstream]

    session[:config_url] = template.expand({"query" => query})
    puts "config_url: " + session[:config_url]
  end

end
