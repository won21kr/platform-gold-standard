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

  # view page
  get "/view_doc/:id" => "view#show", :as => "view_doc"
  get "/download_file/:id" => 'view#download', :as => "download_file"
  post "/comment/:id" => "view#comment", :as => "comment"
  get "/preview/:id" => 'dashboard#preview', :as => "preview"


  get "/doc/:id" => "dashboard#doc", :as => 'doc'
  get "/thumbnail/:id" => 'dashboard#thumbnail', :as => "thumbnail"

  # search page
  post "/resources" => "search#show", :as => "search"
  get "/resources" => "search#show", :as => "resources"
  get "/resources/:folder_id" => "search#show", :as => "resources1"
  post "/resources/:folder_id" => "search#show", :as => "sub_resource"

  # workflow
  get "/onboarding-tasks" => "workflow#show", :as => "workflow"
  post "/onboarding-tasks" => "workflow#show", :as => "workflow_post"
  get "docusign_response/:envelope_id" => "workflow#docusign_response", :as => "docusign_response"

  get "/auth0/failure" => "auth0#failure"
  get "/auth0/callback" => "auth0#callback"

  get '/logout' => 'home#logout', :as => "logout"
  get '/reset-logins' => 'home#reset_logins', :as => "reset_logins"


  get '/config' => "config#show", :as => 'config'
  get '/config/:reset' => "config#show", :as => "reset_config"
  post '/config' => "config#show", :as => "save_config"

end
