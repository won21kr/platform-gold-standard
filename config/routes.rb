Rails.application.routes.draw do

  # home page
  get "/" => "home#show", :as => 'home'
  get "/login" => "home#login", :as => "login"

  # dashboard
  get "/dashboard" => "dashboard#show", :as => 'dashboard'
  get "/dashboard/:id" => "dashboard#show", :as => 'dashboard_id'
  get "/delete/:id" => "dashboard#delete_file", :as => "delete_file"
  get "/download/:id" => 'dashboard#download', :as => "download"
  get "/share/:id" => "dashboard#share_file", :as => "share_file"
  get "/unshare/:id" => "dashboard#unshare_file", :as => "unshare_file"
  post "/upload/:folder_id" => "dashboard#upload", :as => "upload"
  post "/edit_name/:folder_id" => "dashboard#edit_filename", :as => "edit_name"

  # view page
  get "/view_doc/:id" => "view#show", :as => "view_doc"
  get "/download_file/:id" => 'view#download', :as => "download_file"
  post "/comment/:id" => "view#comment", :as => "comment"
  get "/preview/:id" => 'view#preview', :as => "preview"
  get "/no_support" => 'view#no_support', :as => "no_support"

  get "/doc/:id" => "dashboard#doc", :as => 'doc'
  get "/thumbnail/:id" => 'dashboard#thumbnail', :as => "thumbnail"

  # search page
  post "/resources" => "search#show", :as => "search"
  get "/resources" => "search#show", :as => "resources"
  get "/resources/:folder_id" => "search#show", :as => "resources1"
  post "/resources/:folder_id" => "search#show", :as => "sub_resource"

  # workflow
  get "/onboarding-tasks" => "workflow#show", :as => "workflow"
  post "/onboarding-tasks" => "workflow#form_submit", :as => "form_submit"
  get "docusign_response/:envelope_id" => "workflow#docusign_response", :as => "docusign_response"
  get "/onboarding-tasks/reset-workflow" => "workflow#reset_workflow", :as => "reset_workflow"

  #ProductCatalog ( Box View API)
  # get "/catalog/:id" => "catalog#home", :as => "catalog"
  get "/catalog" => "catalog#show", :as => "catalog_id"

  # Upload and Sign
  get "/upload-sign" => "uploadsign#show", :as => "uploadsign"
  post "/upload-sign/:folder_id" => "uploadsign#sign_upload", :as => "sign_upload"
  get "/upload-sign-docusign/:id" => "uploadsign#start_docusign", :as => "start_docusign_id"
  get "uploadsign_docusign_response/:envelope_id" => "uploadsign#uploadnsign_docusign_response", :as => "uploadnsign_docusign_response"
  get "/reset-upload-sign" => "uploadsign#reset_uploadnsign", :as => "reset_uploadnsign"
  get "/delete_uploadnsign/:id" => "uploadsign#delete_file", :as => "delete_uploadnsign_file"

  # medical credentialing
  get "/medical-credentialing" => "medical_credentialing#show", :as => "medical"
  post "/medical-credentialing" => "medical_credentialing#medical_form_submit", :as => "medical_submit"
  get "/medical-credentialing-submit-upload" => "medical_credentialing#medical_upload", :as => "medical_upload"
  post "/medical-upload/:folder_id" => "medical_credentialing#med_upload", :as => "med_upload"
  get "/reset-medical" => "medical_credentialing#reset_workflow", :as => "reset_medical_flow"
  get "/medical-credentialist" => "medical_credentialing#credentialist", :as => "credentialist"
  get "/credentialist-approve/:folder_id" => "medical_credentialing#approve_request", :as => "approve_request"

  # loan documents
  get "/loan-documents" => "loan_documents#show", :as => "loan_docs"
  post "/loan-documents/:file_name" => "loan_documents#loan_upload", :as => "loan_upload"
  get "/copy-from-vault/:file_id" => "loan_documents#copy_from_vault", :as => "copy_from_vault"
  get "/reset-loan-docs" => "loan_documents#reset_loan", :as => "reset_loan_docs"
  get "/loan-agreement-sign/:file_id" => "loan_documents#loan_docusign", :as => "loan_docusign"
  get "docusign_response_loan/:envelope_id" => "loan_documents#docusign_response_loan", :as => "docusign_response_loan"

  # create a claim
  get "/create-claim" => "create_claim#show", :as => "create_claim"


  get "/auth0/failure" => "auth0#failure"
  get "/auth0/callback" => "auth0#callback"

  get '/logout' => 'home#logout', :as => "logout"
  get '/reset-logins' => 'home#reset_logins', :as => "reset_logins"

  # config page
  get '/config' => "config#show", :as => 'config'
  get '/config-reset' => "config#reset_config", :as => "reset_config"
  post '/config' => "config#post_config", :as => "save_config"

  # salesforce shared vault
  get "salesforce" => "salesforce#show", :as => 'salesforce'
  get "/salesforce/:id" => "salesforce#show", :as => 'salesforce_id'


end
