class UserconfigController < ApplicationController
  skip_before_filter :verify_authenticity_token

  require 'csv'
  # require 'mixpanel-ruby'

  def show

  end

  def generate_csv

    # if (params[:password] == "demo1234" && ENV['RACK_ENV'] == 'production')

      # get all user configurations
      configurations = Userconfig.all
      tracker = Mixpanel::Tracker.new('6626ce667ecfc52ecd9b823c730fa8f5')
      ap tracker
      # user = tracker.people.set(session[:box_id], {
      #   '$name' => session[:userinfo]['info']['name'],
      # });
      ap tracker.track('1234', 'Sent Message')

      # open CSV and update
      # CSV.open("user-data/user-data.csv", "w") do |csv|
      #
      #   # first csv line
      #   csv << ["User", "Date Accessed", "Company", "Logo URL", "Home Page URL",
      #           "Vault", "Resources", "Onboarding Tasks", "Medical Credentialing",
      #           "Loan Origination", "Upload & Sign", "Tax Return", "Submit A Claim"]
      #
      #   # iterate through each db entry
      #   configurations.each do |c|
      #
      #     # update csv with user configurations
      #     csv << [c.username,
      #             c.date.strftime("%m/%d/%y"),
      #             c.company,
      #             c.logo_url,
      #             c.home_url,
      #             c.vault ? "X" : "",
      #             c.resources ? "X" : "",
      #             c.onboarding_tasks ? "X" : "",
      #             c.medical_credentialing ? "X" : "",
      #             c.loan_origination ? "X" : "",
      #             c.upload_sign ? "X" : "",
      #             c.tax_return ? "X" : "",
      #             c.submit_claim ? "X" : ""]
      #   end

      # end

      # get user token, upload CSV file
    #   user_data_client = Box.user_client(ENV['USER_DATA_ID'])
    #   begin
    #
    #     begin
    #       oldFile = user_data_client.file_from_path("User\ Data/user-data.csv")
    #       user_data_client.delete_file(oldFile)
    #     rescue
    #       puts "file doesn't exist"
    #     end
    #
    #     folder = user_data_client.folder_from_path("User\ Data")
    #     ap folder
    #     uploadedFile = user_data_client.upload_file("user-data/user-data.csv", folder)
    #
    #     puts "uploaded"
    #     # create shared link
    #     @link = user_data_client.create_shared_link_for_file(uploadedFile, access: :open)
    #     flash[:notice] = "Generated and uploaded user configuration CSV. #{view_context.link_to('link', @link.shared_link.url)}".html_safe
    #   rescue
    #     flash[:notice] = "Error: something went wrong"
    #   end
    #
    # else
    #   if (params[:password] == "demo1234")
    #     flash[:notice] = "Error: not available locally"
    #   else
    #     flash[:notice] = "Error: invalid password"
    #   end
    # end


    redirect_to user_config_path
  end


end
