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

    end

    config_url
  end

  def post_config

    puts 'posting configuration page....'

    # check if new branding parameters were saved
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
    session[:account_sub] = !params[:acctsub].nil? ? 'on' : 'off'
    session[:dicom_viewer] = !params[:dicom_viewer].nil? ? 'on' : 'off'

    # capture all user data and upload to csv, only if in production
    if (ENV['RACK_ENV'] == 'production')
      capture_user_data
    end
    redirect_to config_path
  end

  # capture user + current configurations, modify csv, & upload to Box
  def capture_user_data

    # get enterprise token
    user_data_client = Box.user_client(ENV['USER_DATA_ID'])

    # get tab config
    tabs = {'vault' => "X",
            'resources' => session[:resources] == "on" ? "X" : "",
            'onboarding' => session[:onboarding] == "on" ? "X" : "",
            'medical_credentialing' => session[:medical_credentialing] == "on" ? "X" : "",
            'loan_docs' => session[:loan_docs] == "on" ? "X" : "",
            'upload_sign' => session[:upload_sign] == "on" ? "X" : "",
            'tax_return' => session[:tax_return] == "on" ? "X" : "",
            'create_claim' => session[:create_claim] == "on" ? "X" : ""}

    # open CSV and update
    CSV.open("user-data/user-data.csv", "a+") do |csv|

      # update csv with user config
      csv << [session[:userinfo].nil? ? "" : session[:userinfo]['info']['name'],
              DateTime.now.strftime("%m/%d/%y"), session[:logo],
              session[:background], tabs["vault"], tabs["resources"], tabs["onboarding"],
              tabs["medical_credentialing"], tabs["loan_docs"], tabs["upload_sign"],
              tabs["tax_return"], tabs["create_claim"]]
    end

    # upload new file version
    begin
      file = Rails.cache.fetch("/user-data-file", :expires_in => 10.minutes) do
        user_data_client.file_from_path("User\ Data/user-data.csv")
      end
      user_data_client.upload_new_version_of_file("user-data/user-data.csv", file)
    rescue
      puts "something went wrong"
    end

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
    session[:config_url] << "&dicom_viewer=#{session[:dicom_viewer]}"


  end

end
