class DicomViewerController < SecuredController

  skip_before_filter :verify_authenticity_token

  def show
    study_folders = user_client.folder_items(ENV['DICOM_FOLDER']).folders
    mixpanel_tab_event("DICOM Viewer", "Main Page")

    @studies = {}
    threads = []
    study_folders.each do |folder|
      threads << Thread.new do
        files = user_client.folder_items(folder, fields: [:modified_at, :name]).files
        boxdicom_file = files.find{|f| f.name.end_with?(".boxdicom")}
        name_parts = folder.name.split('-')
        name_parts[0] = "Anonymous "
        anonymized_folder_name = name_parts.join('-')

        @studies[anonymized_folder_name] = boxdicom_file
      end
    end
    threads.each{|t| t.join}

    #ap @studies

    @user_access_token = user_client.access_token
    session[:current_page] = "dicom_viewer"
  end

  def view
    @file_id = params[:file_id]
    @user_access_token = user_client.access_token
  end

  def upload
    mixpanel_tab_event("DICOM Viewer", "Upload DICOM")
    @dicom_folder = ENV['DICOM_FOLDER']
    @user_access_token = user_client.access_token
    session[:current_page] = "dicom_upload"
  end

end
