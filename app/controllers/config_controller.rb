class ConfigController < SecuredController

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
      session[:account_sub] = "off"
      session[:dicom_viewer] = "off"
      session[:media_content] = "off"
      session[:eventstream] = "off"
      session[:product_supply] = "off"

      # Okta
      session[:okta] = "off"
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
    session[:realopp] = params[:realopp]

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
    session[:okta] = !params[:okta].blank? ? 'on' : 'off'

    # check feature tab configuration
    session[:resources] = !params[:resources].blank? ? 'on' : 'off'
    session[:onboarding] = !params[:onboarding].blank? ? 'on' : 'off'
    session[:medical_credentialing] = !params[:medical_credentialing].blank? ? 'on' : 'off'
    session[:loan_docs] = !params[:loan_docs].blank? ? 'on' : 'off'
    session[:upload_sign] = !params[:uploadsign].blank? ? 'on' : 'off'
    session[:tax_return] = !params[:taxreturn].blank? ? 'on' : 'off'
    session[:create_claim] = !params[:createclaim].blank? ? 'on' : 'off'
    session[:request_for_proposal] = !params[:requestforproposal].blank? ? 'on' : 'off'
    session[:account_sub] = !params[:acctsub].blank? ? 'on' : 'off'
    session[:dicom_viewer] = !params[:dicom_viewer].blank? ? 'on' : 'off'
    session[:media_content] = !params[:media_content].blank? ? 'on' : 'off'
    session[:eventstream] = !params[:eventstream].blank? ? 'on' : 'off'
    session[:product_supply] = !params[:product_supply].blank? ? 'on' : 'off'
    session[:blue_care] = !params[:blue_care].blank? ? 'on' : 'off'


    # capture all user data and upload to csv, only if in production
    if (ENV['RACK_ENV'] == 'production')
      # capture_user_data
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
                               eventstream: session[:eventstream] == "on" ? true : false,
                               media_content: session[:media_content] == "on" ? true : false,
                               blue_care: session[:blue_care] == "on" ? true : false)
    user_data.save
    # ap user_data
    # ap Userconfig.all

  end

  # clear session
  def reset_config
    tracker = Mixpanel.client
    event = tracker.track('1234', 'Configuration - Reset')
    session.clear
    redirect_to config_path
  end

  # configure the app for a certain industry
  def configure_industry

    industry = params[:industry]
    tracker = Mixpanel.client

    # if configured for okta
    if !session[:okta].nil? and session[:okta] == 'on'
      auth = "okta"
    end

    case industry
    when "finserv"
      # copy over files + folders
      if session[:userinfo].present?
        copy_content(industry)
      end

      if (ENV['RACK_ENV'] == 'production')
        event = tracker.track(session[:box_id], 'Configuration - Industry', {"industry" => 'Financial Services - Wealth Management'})
      end
      session.clear
      session[:company] = "Blue Advisors"
      session[:industry_resources] = ENV['FINSERV_RESOURCES']
      session[:loan_docs] = 'on'
      session[:logo] = 'https://platform-staging.box.com/shared/static/d51xjgxeku8ktihe53yw1g0m2jnw593x.png'
      # session[:background] = 'https://platform-staging.box.com/shared/static/1gwe4kkkgycqoa0mg7i11jntaew0curl.png'
      session[:alt_text] = "{\"My Vault\" : \"Document Vault\",
                             \"My Files\" : \"Personal\",
                             \"Your personal and shared files\" : \"Your personal and shared financial documents\",
                             \"Shared Files\" : \"Shared (with Advisor)\",
                             \"Resources\" : \"Client Resources\",
                             \"Find relevant content, fast\" : \"Browse relevant financial documents\",
                             \"Onboarding Tasks\" : \"Sign Tax Return\"}"
      session[:industry] = "finserv"

    when "healthcare"

      # copy over files + folders
      if session[:userinfo].present?
        copy_content(industry)
      end

      session.clear
      session[:company] = "Blue Care"
      session[:industry_resources] = ENV['HEALTHCARE_RESOURCES']
      # session[:background] = 'https://platform-staging.box.com/shared/static/0mh4ysttxj5h8wg742iovy3hmdj4umvj.png'
      session[:logo] = 'https://platform-staging.box.com/shared/static/lc6swn86txsxzysb5phhgcjm54bbunwd.png'
      session[:alt_text] = "{\"My Vault\" : \"Patient Vault\",
                             \"My Files\" : \"Personal\",
                             \"Your personal and shared files\" : \"Your personal and shared medical documents\",
                             \"Shared Files\" : \"Shared (with Physician)\",
                             \"Resources\" : \"Patient Education\",
                             \"Find relevant content, fast\" : \"Browse relevant medical documents\",
                             \"Onboarding Tasks\" : \"Sign Release Form\"}"
      session[:industry] = "healthcare"

    when "insurance"

      # copy over files + folders
      if session[:userinfo].present?
        copy_content(industry)
      end

      session.clear
      session[:company] = "Blue Insurance"
      # session[:industry_resources] = ENV['INSURANCE_RESOURCES']
      session[:create_claim] = "on"
      # session[:background] = 'https://platform-staging.box.com/shared/static/7bmw68id15gxv4sxixnnfttxmvjvwv47.png'
      session[:logo] = 'https://platform-staging.box.com/shared/static/8dr0t56a218bfk92sop0op4d6zct9jz6.png'
      session[:alt_text] = "{\"My Vault\" : \"Insurance Documents\",
                             \"My Files\" : \"Personal\",
                             \"Your personal and shared files\" : \"Your personal and shared insurance documents\",
                             \"Shared Files\" : \"Shared (with Agent)\",
                             \"Resources\" : \"Education\",
                             \"Find relevant content, fast\" : \"Browse educational insurance documents\",
                             \"Onboarding Tasks\" : \"Incident Report Form\"}"
      session[:industry] = "insurance"

    when "nonprofit"

      auth = nil
      # copy over files + folders
      if session[:userinfo].present?
        copy_content(industry)
      end

      session.clear
      session[:company] = "Impact Cloud"
      session[:industry_resources] = ENV['NONPROFIT_RESOURCES']
      session[:logo] = 'https://platform-staging.box.com/shared/static/8drrkvwgfurgm2cedn5yfx9kf4lfbsji.png'
      session[:alt_text] = "{\"My Vault\" : \"Disaster Site Captures\",
                             \"My Files\" : \"Personal\",
                             \"Your personal and shared files\" : \"Your personal and shared disaster site captures\",
                             \"Shared Files\" : \"Shared (with org)\",
                             \"Find relevant content, fast\" : \"Browse relevant responder resources\",
                             \"Onboarding Tasks\" : \"Responder Agreement\"}"
      session[:industry] = "nonprofit"

      # turn on okta auth
      if (auth == "okta")
        session[:okta] = "on"
      end

    else
    end

    redirect_to '/'
  end

  private

  # delete all vault content and replace with predefined industry folder structure
  def copy_content(industry)

    puts "copying content..."
    client = user_client
    threads = []

    # get "My Files" and "Shared Files" folder objects
    myFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/my_folder", :expires_in => 10.minutes) do
      client.folder_from_path('My Files')
    end
    myFolderContents = client.folder_items(myFolder, fields: [:id, :type])

    sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
      client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
    end
    sharedFolderContents = client.folder_items(sharedFolder, fields: [:id]).files

    # delete vault folder contents
    myFolderContents.each do |f|
      if (f.type == "folder")
        client.delete_folder(f, recursive: true)
      else
        client.delete_file(f)
      end
    end

    sharedFolderContents.each do |f|
      threads << Thread.new do
        client.delete_file(f)
      end
    end

    threads.each { |thr| thr.join }

    # fetch industry folder items
    case industry
    when "finserv"
      industryParentItems = client.folder_items(ENV['FINSERV_VAULT_CONTENT'], fields: [:id, :type])
    when "healthcare"
      industryParentItems = client.folder_items(ENV['HEALTHCARE_VAULT_CONTENT'], fields: [:id, :type])
    when "insurance"
      industryParentItems = client.folder_items(ENV['INSURANCE_VAULT_CONTENT'], fields: [:id, :type])
    when "nonprofit"
      industryParentItems = client.folder_items(ENV['NONPROFIT_VAULT_CONTENT'], fields: [:id, :type])
    else
    end

    # copy industry folder items over
    industryParentItems.each do |f|
      threads << Thread.new do
        if f.type == "folder"
          client.copy_folder(f, myFolder)
        else
          client.copy_file(f, myFolder)
        end
      end
    end

    threads.each { |thr| thr.join }

  end

  def mixpanel_capture

    configuration = {}

    configuration[:username] = session[:userinfo]['info']['name'] unless session[:userinfo].blank?
    configuration[:company] = session[:company] unless session[:company].blank?
    configuration[:realopp] = session[:realopp] unless session[:realopp].blank?
    configuration[:okta] = session[:okta] unless session[:okta] != "on"
    configuration[:logo_url] = session[:logo] unless session[:logo].blank?
    configuration[:home_url] = session[:background] unless session[:background].blank?
    configuration[:alt_text] = session[:alt_text] unless session[:alt_text].blank?
    # configuration[:tab_configuration] = tab_config

    tracker = Mixpanel.client
    event = tracker.track(session[:box_id], 'Configuration - General', configuration)

    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'My Vault')
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Resources') unless session[:resources] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Onboarding Tasks') unless session[:onboarding] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Medical Credentialing') unless session[:medical_credentialing] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Loan Origination') unless session[:loan_docs] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Upload & Sign') unless session[:upload_sign] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Tax Return') unless session[:tax_return] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Submit A Claim') unless session[:create_claim] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'Box Events') unless session[:eventstream] != "on"
    tracker.track(session[:box_id], 'Configuration - Tabs', 'tab_configuration' => 'DICOM Viewer') unless session[:dicom_viewer] != "on"
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
    query["request_for_proposal"] = session[:request_for_proposal] unless session[:request_for_proposal].blank?
    query["back_color"] = session[:navbar_color][1..-1] unless session[:navbar_color].blank?

    query["okta"] = session[:okta]
    query["vault"] = session[:vault]
    query["resources"] = session[:resources]
    query["onboarding"] = session[:onboarding]
    query["med_credentialing"] = session[:medical_credentialing]
    query["loan_docs"] = session[:loan_docs]
    query["tax_return"] = session[:tax_return]
    query["upload_sign"] = session[:upload_sign]
    query["dicom_viewer"] = session[:dicom_viewer]
    query["media_content"] = session[:media_content]
    query["eventstream"] = session[:eventstream]
    query["product_supply"] = session[:product_supply]
    query["blue_care"] = session[:blue_care]

    session[:config_url] = template.expand({"query" => query})
    puts "config_url: " + session[:config_url]
  end

end
