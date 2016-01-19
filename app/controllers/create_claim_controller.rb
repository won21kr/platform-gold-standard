class CreateClaimController < SecuredController

  def show

    client = user_client
    session[:current_page] = "create-claim"


    begin
      @submittedClaimsFolder = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Claims")

    rescue
      puts "folder not yet created, create"
      sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      client.create_folder("Claims", sharedFolder)


    end




  end


end
