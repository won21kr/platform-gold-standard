class ConfigController < ApplicationController
  skip_before_filter :verify_authenticity_token
  # before_action :check_config

  require 'csv'


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
      :body => "#{session[:config_url]}"
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
      m.subject = 'Here is your customized Box Platform Standard'
      m.text = "Files have been updated. Please take a look here: "
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

    # add user config database entry, ActiveRecord video tutorial!!!
    user_data = Userconfig.new(username: session[:userinfo].nil? ? "" : session[:userinfo]['info']['name'],
                               date: DateTime.now, # .strftime("%m/%d/%y")
                               company: session[:company],
                               logo_url: session[:logo],
                               home_url: session[:background],
                               vault: true,
                               resources: session[:resources] == "on" ? true : false,
                               onboarding_tasks: session[:onboarding] == "on" ? true : false,
                               medical_credentialing: session[:medical_credentialing] == "on" ? true : false,
                               loan_origination: session[:loan_docs] == "on" ? true : false,
                               upload_sign: session[:upload_sign] == "on" ? true : false,
                               tax_return: session[:tax_return] == "on" ? true : false,
                               submit_claim: session[:create_claim] == "on" ? true : false)
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
    session[:config_url] = "#{ENV['ACTIVE_URL']}/"
    session[:config_url] << "?message=#{session[:home_message]}"
    session[:config_url] << "&logo=#{session[:logo]}"
    if(!session[:navbar_color].nil? && session[:navbar_color] != "")
      session[:config_url] << "&back_color=#{session[:navbar_color][1..-1]}"
    end
    session[:config_url] << "&vault=#{session[:vault]}"
    session[:config_url] << "&resources=#{session[:resources]}"
    session[:config_url] << "&onboarding=#{session[:onboarding]}"
    session[:config_url] << "&med_credentialing=#{session[:medical_credentialing]}"
    session[:config_url] << "&loan_docs=#{session[:loan_docs]}"
    session[:config_url] << "&background=#{session[:background]}"
    session[:config_url] << "&tax_return=#{session[:tax_return]}"
    session[:config_url] << "&upload_sign=#{session[:upload_sign]}"
    session[:config_url] << "&create_claim=#{session[:create_claim]}"
    session[:config_url] << "&create_claim=#{session[:request_for_proposal]}"
    session[:config_url] << "&dicom_viewer=#{session[:dicom_viewer]}"
    session[:config_url] << "&media_content=#{session[:media_content]}"
    session[:config_url] << "&eventstream=#{session[:eventstream]}"

  end

end
