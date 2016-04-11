class DicomViewerController < SecuredController

  skip_before_filter :verify_authenticity_token

  def show
    @user_access_token = user_client.access_token
    session[:current_page] = "dicom_viewer"
  end

  def view
    @file_id = params[:file_id]
    @user_access_token = user_client.access_token
  end

end
