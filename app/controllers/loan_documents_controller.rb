class LoanDocumentsController < SecuredController


  def show

    client = user_client
    session[:current_page] = "loan_docs"
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"
    docStatus = Hash.new
    @docStatus = {"Loan Agreement" => "Missing", "W2 Form" => "Missing",
                  "Tax Return" => "Missing", "Loan Image" => "file_toupload.png",
                  "W2 Image" => "file_toupload.png", "Tax Image" => "file_toupload.png"}
    ap docStatus

    # get loan documents folder, if it doesn't exist create one
    begin
      @loanFolder = client.folder_from_path(path)
    rescue
      parent = client.folder_from_path("#{session[:userinfo]['info']['name']} - Shared Files")
      @loanFolder = client.create_folder("Loan Documents", parent)
      # client.add_collaboration(@loanFolder, {id: ENV['EMPL_ID'], type: :user}, :viewer)
      puts "created new loan docs folder..."
    end

    @loanItems = client.folder_items(@loanFolder, fields: [:id, :name, :modified_at])

    # iterate throug loan folder to check out documents
    @loanItems.each do |file|

      name = file.name.split(".").first
      imageName = name.split(" ").first + " Image"


      task = client.file_tasks(file, fields: [:is_completed]).first

      if(task != nil and task.is_completed)

      elsif(task != nil and !task.is_completed)
        #task not completed yet
        @docStatus[name] = "Received #{DateTime.strptime(file.modified_at).strftime("%m/%d/%y at %l:%M %p")}; In review"
        @docStatus[imageName] = "file_process.png"


      else
        puts  "Error: should never be here!"

      end
      #
      #
      #
      # case file.name.split(".").first
      #
      #   when "Loan Agreement"
      #     match = "yes"
      #
      #   when "W2 Form"
      #     match = "yes"
      #
      #   when "Tax Return"
      #     match = "yes"
      #
      # end

    end



  end

  # upload files to parameter specified folder ID
  def loan_upload

    puts "uploading file..."

    #http://www.dropzonejs.com/
    client = user_client
    path = "#{session[:userinfo]['info']['name']} - Shared Files/Loan Documents"

    uploaded_file = params[:file]
    name = params[:file_name]
    fileName = params[:file_name]

    folder = client.folder_from_path(path)
    # ap folder
    # ap uploaded_file
    # puts fileName

    temp_file = File.open(Rails.root.join('tmp', uploaded_file.original_filename), 'wb')
    begin
      temp_file.write(uploaded_file.read)
      temp_file.close

      box_user = Box.user_client(session[:box_id])
      box_file = client.upload_file(temp_file.path, folder)

      ext = box_file.name.split(".").last
      fileName = fileName + "." + ext

      uploadedFile = client.update_file(box_file, name: fileName)
      msg = "Please review and complete the task"
      task = client.create_task(uploadedFile, action: :review, message: msg)
      client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])
      #box_user.create_metadata(box_file, session[:meta])

    rescue => ex
      puts ex.message
    ensure
      File.delete(temp_file)
    end

    flash[:notice] = "#{name} Successfully Uploaded!"
    respond_to do |format|
      format.json{ render :json => {} }
    end
  end


end
