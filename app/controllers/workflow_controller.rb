class WorkflowController < SecuredController

  skip_before_filter :verify_authenticity_token

  # main controller for onboarding workflow
  def show

    client = user_client
    approvalPath = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Pending\ Approval/"
    sigReqPath = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Signature\ Required/"
    session[:progress] = 0

    approvalFolder = client.folder_from_path(approvalPath)
    sigReqFolder = client.folder_from_path(sigReqPath)

    # check where we are in the onboarding workflow process
    @pendingApproval = client.folder_items(approvalFolder).files
    @sigRequired = client.folder_items(sigReqFolder).files


    if(params[:formSubmit] == "true")
      # use form variables to fill out html template file,
      # convert html file to a pdf and upload to Box

      doc = Doc.new({:tel => params[:tel],
                    :address => params[:address],
                    :bday => params[:bday],
                    :acct => params[:acct],
                    :username => session[:userinfo]['info']['name'],
                    :review_status => "pending",
                    :signature_status => "pending"
                  })

      filename = "tmp/Onboarding Contract.pdf"
      path = "#{session[:userinfo]['info']['name']}\ -\ Shared\ Files/Onboarding\ Workflow/Pending\ Approval"
      doc.configure_pdf(client, filename, path)

      session[:progress] = 33
      @pendingApproval = client.file_from_path(approvalPath, fields: [:id, :name, :expiring_embed_link])
    elsif (@pendingApproval != nil)
      task = client.file_tasks(@pendingApproval[0])
      ap task
      session[:progress] = 33
    end


  end

  public

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end


  class Doc < SecuredController
    include AbstractController::Rendering
    self.view_paths = 'app/views'

  	def initialize(info)
  		@info = info
  	end

  	def pdferize

      rendered = render_to_string(:template => 'pdfs/onboarding_doc.pdf.haml',
                                  :locals => {:info => @info})
  		WickedPdf.new.pdf_from_string(rendered)
  	end

    def configure_pdf(client, filename, path)

      # get "Pending Approval" folder
      upload_folder = client.folder_from_path(path)

      # convert haml file to pdf
      pdf = self.pdferize


  		pdf_filename = filename
  		File.open(pdf_filename, 'wb') do |f|
  			f.write(pdf)
  		end

      # upload pdf to Box
  		pdf_in_box = client.upload_file(pdf_filename, upload_folder.id)

  		# set metadata
      client.create_metadata(pdf_in_box, @info, scope: :global, template: :properties)

      # create task for uploaded customer document and assign to Company Employee
      msg = "Please review and complete the task"
      task = client.create_task(pdf_in_box, action: :review, message: msg)
      client.create_task_assignment(task, assign_to: ENV['EMPL_ID'])


  	end
  end



end
