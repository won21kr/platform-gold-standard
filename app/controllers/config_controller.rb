class ConfigController < ApplicationController

  require 'uri'

  skip_before_filter :verify_authenticity_token
  # before_action :check_config

  def show
    puts "config page get..."

    # check if the tabs have been configured yet
    started = true

    if session[:vault].nil?
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

      # Okta
      session[:okta] = "off"
    end

    config_url
  end

  def twilio_method
    account_sid = "AC4c44fc31f1d7446784b3e065f92eb4e6"
    auth_token = "5ad821b20cff339979cd0a9d42e1a05d"
    client = Twilio::REST::Client.new account_sid, auth_token

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

    puts "MADE IT TO THE METHOD: #{params[:emailAddress]}"
    client = SendGrid::Client.new do |c|
      c.api_user = 'carycheng77'
      c.api_key =  'CaryCheng77' #'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'
    end

    mail = SendGrid::Mail.new do |m|
      m.to = params[:emailAddress]
      m.from = params[:emailAddress]
      m.subject = 'Your custom Platform Standard app"
      m.text = "Here\'s the custom-configured Platform Standard app URL you created. Have a kickass demo! " + session[:config_url]
    end

    puts client.send(mail)
    # {"message":"success"}
    redirect_to config_path
  end

  def post_config

    puts 'posting configuration page....'

    # check if new branding parameters were saved
    if !params[:company].nil? and params[:company] != ""
      session[:company] = params[:company]
    end
    if !params[:logo].nil? and params[:logo] != ""
      session[:logo] = params[:logo]
    end
    if !params[:backgroud].nil? and params[:background] != ""
      session[:background] = params[:background]
    end
    if !params[:navbar_color].nil? and params[:navbar_color] != ""
      if (params[:navbar_color][0] == '#')
        session[:navbar_color] = params[:navbar_color]
      else
        session[:navbar_color] = '#' + params[:navbar_color]
      end
    end

    # Okta configuration
    session[:okta] = !params[:okta].nil? ? 'on' : 'off'

    # check feature tab configuration
    session[:resources] = !params[:resources].nil? ? 'on' : 'off'
    session[:onboarding] = !params[:onboarding].nil? ? 'on' : 'off'
    session[:medical_credentialing] = !params[:medical_credentialing].nil? ? 'on' : 'off'
    session[:loan_docs] = !params[:loan_docs].nil? ? 'on' : 'off'
    session[:upload_sign] = !params[:uploadsign].nil? ? 'on' : 'off'
    session[:tax_return] = !params[:taxreturn].nil? ? 'on' : 'off'
    session[:create_claim] = !params[:createclaim].nil? ? 'on' : 'off'
    session[:request_for_proposal] = !params[:requestforproposal].nil? ? 'on' : 'off'
    session[:account_sub] = !params[:acctsub].nil? ? 'on' : 'off'
    session[:dicom_viewer] = !params[:dicom_viewer].nil? ? 'on' : 'off'
    session[:media_content] = !params[:media_content].nil? ? 'on' : 'off'
    session[:eventstream] = !params[:eventstream].nil? ? 'on' : 'off'

    # capture all user data and upload to csv, only if in production
    if (ENV['RACK_ENV'] == 'production')
      capture_user_data
    end
    redirect_to config_path
  end

  # capture user + current configurations, modify csv, & upload to Box
  def capture_user_data

    # add a user config row entry
    user_data = Userconfig.new(username: session[:userinfo].nil? ? "" : session[:userinfo]['info']['name'],
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
                               media_content: session[:media_content] == "on" ? true : false)
    user_data.save
    # ap user_data
    # ap Userconfig.all

  end

  # clear session
  def reset_config
    session.clear
    redirect_to config_path
  end

  private

  # construct configuration URL
  def config_url
    url = "#{ENV['ACTIVE_URL']}?"

    # url << "message=#{session[:home_message]}"
    url << "okta=#{session[:okta]}"
    url << "&company=#{session[:company]}" unless session[:company].blank?
    url << "&logo=#{session[:logo]}" unless session[:logo].blank?
    url << "&background=#{session[:background]}" unless session[:background].blank?
    url << "&create_claim=#{session[:create_claim]}" unless session[:create_claim].blank?
    url << "&request_for_proposal=#{session[:request_for_proposal]}" unless session[:request_for_proposal].blank?
    url << "&back_color=#{session[:navbar_color][1..-1]}" unless session[:navbar_color].blank?

    url << "&vault=#{session[:vault]}"
    url << "&resources=#{session[:resources]}"
    url << "&onboarding=#{session[:onboarding]}"
    url << "&med_credentialing=#{session[:medical_credentialing]}"
    url << "&loan_docs=#{session[:loan_docs]}"

    url << "&tax_return=#{session[:tax_return]}"
    url << "&upload_sign=#{session[:upload_sign]}"
    url << "&dicom_viewer=#{session[:dicom_viewer]}"
    url << "&media_content=#{session[:media_content]}"
    url << "&eventstream=#{session[:eventstream]}"

    session[:config_url] = URI.escape(url)
    puts "Config_url Method: "
    ap session[:config_url]
  end

end
