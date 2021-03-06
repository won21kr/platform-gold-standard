class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper :all
  helper_method :get_med_task_status
  before_action :check_config
  require 'mixpanel'

  # get med credential workflow status
  def get_med_task_status

    client = user_client
    puts "get med task status"

    # if the medical credentialing form doc has been generated, check if the task has been approved
    begin
      taskFile = client.file_from_path("#{session[:userinfo]['info']['name']}\ -\ Medical\ Credentialing/Medical\ Application\ Form.pdf")
      task = client.file_tasks(taskFile, fields: [:is_completed])
    rescue
      puts "file doesn't exist yet..."
    end
    # ap task

    if(task.nil?)
      session[:med_task_status] = 1
    elsif(task.first.is_completed == false)
      session[:med_task_status] = 1
    elsif(task.first.is_completed == true)
      session[:med_task_status] = 0
    else
      session[:med_task_status] = 1
    end

    session[:med_task_status]
  end

  # Get user client obj using App User ID
  def user_client
    Box.user_client(session[:box_id])
  end

  # Capture tab event
  def mixpanel_tab_event(tab, event)
    company = session[:company].nil? ? "NA" : session[:company]
    tracker = Mixpanel.client
    event = tracker.track(session[:box_id], 'Tab Usage', {:tab => tab,
                                                :event => event,
                                                :company => company})
  end

  private

  def check_config
    unless params.blank?
      insert_query(params)
    end
  end

  # fetches config query from encoded URL and updates the config session variables
  def insert_query(query)
    session[:okta] = query['okta'] unless query['okta'].blank?
    session[:company] = query['company'] unless query['company'].blank?
    session[:logo] = query['logo'] unless query['logo'].blank?
    session[:navbar_color] = '#' + query['back_color'] unless query['back_color'].blank?
    session[:industry] = query['industry'] unless query['industry'].blank?

    session[:alt_text] = query['alt_text'] unless query['alt_text'].blank?
    begin
      if session[:alt_text].blank?
        session[:alt_text_hash] = nil
      else
        session[:alt_text_hash] = JSON.parse(session[:alt_text])
        #puts "Successfully parsed alt_text: #{session[:alt_text]}"
      end
    rescue
      session[:alt_text_hash] = nil
      puts "Failed to parse alt_text: #{session[:alt_text]}"
    end

    session[:vault] = query['vault'] unless query['vault'].blank?
    session[:resources] = query['resources'] unless query['resources'].blank?
    session[:onboarding] = query['onboarding'] unless query['onboarding'].blank?
    session[:medical_credentialing] = query['med_credentialing'] unless query['med_credentialing'].blank?
    session[:loan_docs] = query['loan_docs'] unless query['loan_docs'].blank?
    session[:background] = query['background'] unless query['background'].blank?
    session[:upload_sign] = query['upload_sign'] unless query['upload_sign'].blank?
    session[:create_claim] = query['create_claim'] unless query['create_claim'].blank?
    # session[:request_for_proposal] = query['request_for_proposal'] unless query['request_for_proposal'].blank?
    session[:tax_return] = query['tax_return'] unless query['tax_return'].blank?
    session[:dicom_viewer] = query['dicom_viewer'] unless query['dicom_viewer'].blank?
    # session[:media_content] = query['media_content'] unless query['media_content'].blank?
    session[:eventstream] = query['eventstream'] unless query['eventstream'].blank?
    session[:product_supply] = query['product_supply'] unless query['product_supply'].blank?
  end
end
