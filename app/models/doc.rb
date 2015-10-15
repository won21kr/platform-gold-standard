class Doc < SecuredController
  include AbstractController::Rendering
  self.view_paths = 'app/views'

  def initialize(info)
    @info = info
  end

  def pdferize

    # insert variables into haml page, then generate pdf
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

  private

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end

end
