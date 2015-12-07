Rails.application.routes.draw do

  # vault
  get "/" => "home#show", :as => 'home'
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

  # upload and sign
  get "/upload-sign" => "uploadsign#show", :as => "uploadsign"
  get "/upload-sign/:id" => "uploadsign#show", :as => "uploadsign_id"
  get "/docusign/:id" => "uploadsign#start_docusign", :as => "start_docusign_id"
  get "/docusign" => "uploadsign#start_docusign", :as => "start_docusign"
  get "uploadsign_docusign_response/:envelope_id" => "uploadsign#uploadsign_docusign_response", :as => "uploadsign_docusign_response"

  get "/auth0/failure" => "auth0#failure"
  get "/auth0/callback" => "auth0#callback"

  get '/logout' => 'home#logout', :as => "logout"
  get '/reset-logins' => 'home#reset_logins', :as => "reset_logins"


  get '/config' => "config#show", :as => 'config'
  get '/config-reset' => "config#reset_config", :as => "reset_config"
  post '/config' => "config#post_config", :as => "save_config"

end
