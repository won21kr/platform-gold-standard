class CreateClaimController < SecuredController

  skip_before_filter :verify_authenticity_token

  def show

    client = user_client
    @user_access_token = client.access_token
    session[:current_page] = "create-claim"
    mixpanel_tab_event("Submit A Claim", "Main Page")
    threads = []

    if (!session[:claimPage].nil? and session[:claimPage] == 'submitted')
      @currentPage = 'submitted'
      session[:claimPage] = 'newClaim'
    else
      @currentPage = 'newClaim'
    end

    begin
      @submittedClaimsFolder = Rails.cache.fetch("/claims-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Claims")
      end

      @claims = client.folder_items(@submittedClaimsFolder, fields: [:id, :name])

    rescue
      puts "folder not yet created, create"
      sharedFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/shared_folder", :expires_in => 10.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      end
      @submittedClaimsFolder = client.create_folder("Claims", sharedFolder)
      @claims = []
    end

    # attach file metadata template to each file
    @claims.each do |c|
      threads << Thread.new do
        class << c
          attr_accessor :claimId, :estimatedValue, :type, :description, :status
        end

        begin
          meta = client.all_metadata(c)["entries"]

          meta.each do |m|
            if (m["$template"] == "insuranceClaim")
              c.claimId = m["id"]
              c.type = m["type"]
              c.estimatedValue = m["estimatedValue"]
              c.description = m['description']
              c.status = m['status']
            end
          end

        rescue
          c.claimId = ""
          c.type = ""
          c.estimatedValue = ""
          c.description = ""
          c.status = ""
        end
      end
    end

    threads.each { |thr| thr.join }

  end

  def claim_info
    session[:current_page] = "create-claim"
    session[:file_id] = params[:file_id]
    mixpanel_tab_event("Submit A Claim", "Fill Out Form")

    #
    # session[:claim] = params[:file]
    # session[:claim_id] = params[:file].split('-').last

  end

  def submit_claim

  client = user_client
  mixpanel_tab_event("Submit A Claim", "Submit Claim")

    begin
      @submittedClaimsFolder = Rails.cache.fetch("/claims-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Claims")
      end
      @claimFile = client.file_from_id(session[:file_id], fields: [:name])
      claimId = @claimFile.name.split('-').last.split('.').first

      meta = {'id' => claimId.to_i,
              'type' => params[:type],
              'estimatedValue' => params[:value].to_i,
              'description' => params[:description],
              'status' => "Submitted"}
      # error handle if type == nil
      if (meta['type'].nil?)
        meta['type'] = 'Auto'
      end
      client.create_metadata(@claimFile, meta, scope: :enterprise, template: 'insuranceClaim')
      flash[:notice] = "Claim ##{claimId} successfully submitted. Await company approval."
      session[:claimPage] = 'submitted'
    rescue Exception => e
      ap e
      puts "error. Folder not found"
      flash[:error] = "Error. Something went wrong."
      session[:claimPage] = 'newClaim'
    end


    redirect_to create_claim_path
  end


  def claim_reset

    client = user_client
    mixpanel_tab_event("Submit A Claim", "Reset Workflow")
    begin
      @submittedClaimsFolder = Rails.cache.fetch("/claims-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files/Claims")
      end
      @claims = client.folder_items(@submittedClaimsFolder, fields: [:id, :name])
    rescue
      puts "folder not yet created"
    end

    @claims.each do |c|
      client.delete_file(c)
    end

    redirect_to create_claim_path
  end


end
