class DicomViewerController < SecuredController

  skip_before_filter :verify_authenticity_token

  def show

    client = user_client
    @user_access_token = client.access_token
    session[:current_page] = "dicom_viewer"
    threads = []

  end

end
