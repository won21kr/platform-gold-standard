class MedicalCredentialingController < SecuredController

  skip_before_filter :verify_authenticity_token

  # main controller for onboarding workflow
  def show

    # determine if the credentialist is logged in, if so, redirect to their own page
    if session[:box_id] == ENV['CRED_SPECIALIST']
      puts "credentialist logged in..."
      redirect_to credentialist_path
    else

      client = user_client
      session[:current_page] = "medical_credentialing"
      # tab_usage(session[:current_page])

      # get medical folder path
      path = "#{session[:userinfo]['info']['name']}\ -\ Medical\ Credentialing"

      # get medical credentialing folder, if it doesn't exist create one + add collaboration
      begin
        @medFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/medical_folder", :expires_in => 10.minutes) do
          client.folder_from_path(path)
        end
      rescue
        @medFolder = client.create_folder("#{session[:userinfo]['info']['name']} - Medical Credentialing", Boxr::ROOT)
        client.add_collaboration(@medFolder, {id: ENV['CRED_SPECIALIST'], type: :user}, :editor)
        puts "created new med credentialing folder..."
      end

      # check current status of medical credentialing Workflow
      @status = workflow_status(path, @medFolder)

      # perform actions based on current workflow status state
      case @status

        # wait for form submission
        when "toFill"
          session[:progress] = 0
          session[:med_task_status] = 1
          @message = "Step 1. Fill out your personal information"

        # Upload medical documents
        when "toUpload"
          session[:progress] = 1
          session[:med_task_status] = 1
          @message = "Step 2. Upload Documents"

        # wait for cred specialist approval
        when "pendingApproval"
          @medFiles = client.folder_items(@medFolder, fields: [:name, :id, :created_at, :modified_at]).files
          session[:progress] = 2
          session[:med_task_status] = 1
          @message = "Step 3. Wait for credentialing specialist's approval"

        # submission approved
        when "approved"
          session[:progress] = 3
          session[:med_task_status] = 0
          @medFiles = client.folder_items(@medFolder, fields: [:name, :id, :created_at, :modified_at]).files
          @message = "Medical credentialing request approved! Approval documents will now be sent."
        else
          puts "Error: Something went wrong..."
      end
    end
  end

  # submit medical form data
  def medical_form_submit

    puts "submitting form"
    client = user_client

    if(params[:formSubmit] == "true")
      # use form variables to fill out html template file,
      # convert html file to a pdf and upload to Box
      filename = "tmp/Medical Application Form.pdf"

      # the "Doc" module code can be found in app/models/
      doc = Doc.new({:id => params[:id], :name => params[:name],
                     :date => params[:date], :specialty => params[:specialty],
                     :degree => params[:degree],
                     :username => session[:userinfo]['info']['name']})

      path = "#{session[:userinfo]['info']['name']}\ -\ Medical\ Credentialing"
      doc.configure_pdf(client, filename, path, ENV['MEDICAL_FORM'])
    end

    flash[:notice] = "Thanks for submitting! Please upload credentials for review."
    redirect_to medical_path
  end

  # upload medical credentialing documents
  def medical_upload

    client = user_client
    session[:current_page] = "medical_credentialing"

    # get medical folder path
    path = "#{session[:userinfo]['info']['name']}\ -\ Medical\ Credentialing"
    medFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/medical_folder", :expires_in => 10.minutes) do
      client.folder_from_path(path)
    end
    medDocs = client.folder_items(medFolder, fields: [:name, :id])

    if (medDocs.size > 1)
      flash[:notice] = "Thanks for uploading! A medical credentialing specialist will review your submission"
    else
      flash[:error] = "You must upload documents to continue."
    end
    redirect_to medical_path
  end

  # reset credentialing workflow, delete credentialing folder
  def reset_workflow

    puts "reset workflow..."
    client = user_client

    # get workflow folder paths, delete folder
    path = "#{session[:userinfo]['info']['name']}\ -\ Medical\ Credentialing"
    folder = client.folder_from_path(path)
    items = client.folder_items(folder, fields: [:id])

    items.each do |f|
      client.delete_file(f)
    end

    redirect_to medical_path
  end

  # upload files to parameter specified folder ID
  def med_upload

    puts "uploading file..."

    #http://www.dropzonejs.com/
    uploaded_file = params[:file]
    folder = params[:folder_id]

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_user = Box.user_client(session[:box_id])
      box_file = box_user.upload_file(temp_file.path, folder)
    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "Successfully Uploaded!"
    respond_to do |format|
      format.json{ render :json => {} }
    end
  end

  # page for the medical credentialist
  def credentialist

    client = user_client
    session[:current_page] = "medical_credentialing"
    @medicalArray = Hash.new
    @empty = true

    rootFolders = client.root_folder_items(fields: [:id, :name])

    # fill array with files!!!
    rootFolders.each do |folder|
      if (folder.name.include? "Medical Credentialing")
        files = client.folder_items(folder, fields: [:name, :id, :created_at, :modified_at, :parent])
        @medicalArray.store(folder.name, files)

        if (files.size > 0)
          @empty = false
        end
      end
    end

  end

  # Complete the task and remove credentialist collaboration from folder
  def approve_request
    puts "approve request"

    client = user_client

    # get credential folder from id and get Med application file
    folder = Rails.cache.fetch("/#{session[:box_id]}/#{params[:folder_id]}/request_folder", :expires_in => 15.minutes) do
      client.folder_from_id(params[:folder_id], fields: [:name])
    end
    file = client.file_from_path("#{folder.name}/Medical Application Form.pdf")
    clientName = folder.name.split(" ").first
    task = client.file_tasks(file).first

    # complete file task assignment and remove collaboration from folder
    assignment = client.task_assignments(task).first
    client.update_task_assignment(assignment, resolution_state: :completed)
    collab = client.folder_collaborations(folder).first
    client.remove_collaboration(collab)

    flash[:notice] = "Medical credentialing for #{clientName} approved!"
    redirect_to medical_path
  end


  private

  # determine what the current workflow status
  # return the workflow status
  def workflow_status(path, medFolder)

    # either "toFill", "toUpload", "pendingApproval", "Approved"
    status = nil
    client = user_client

    medDocs = client.folder_items(medFolder, fields: [:name, :id])

    # if the medical credentialing form doc has been generated, check if the task has been approved
    begin
      taskFile = client.file_from_path(path + "/Medical\ Application\ Form.pdf")
      task = client.file_tasks(taskFile, fields: [:is_completed])
    rescue
      puts "file doesn't exist yet..."
    end

    # the form has not yet been filled out
    if(medDocs.size == 0)
      status = "toFill"

    # the form has been filled out, yet to upload additional documents
    elsif(medDocs.size == 1)
      status = "toUpload"

    # the form has been filled out, and at least 1 document has been uploaded
  elsif(medDocs.size > 1 and task.first.is_completed == false)
      status = "pendingApproval"

    # reviewal process has been approved
  elsif(medDocs.size > 1 and task.first.is_completed == true)
      status = "approved"
    else
      puts "Error: something went wrong..."
    end

    # return the status
    status
  end

  def set_preview_url(id)
    @previewURL = user_client.embed_url(id)
  end


end
