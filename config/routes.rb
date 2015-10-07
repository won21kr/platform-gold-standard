Rails.application.routes.draw do

  get "/" => "home#show", :as => 'home'

  get "/dashboard" => "dashboard#show", :as => 'dashboard'
  get "/dashboard/:id" => "dashboard#show", :as => 'dashboard_id'

  get "/doc/:id" => "dashboard#doc", :as => 'doc'
  get "/thumbnail/:id" => 'dashboard#thumbnail', :as => "thumbnail"
  get "/download/:id" => 'dashboard#download', :as => "download"
  get "/preview/:id" => 'dashboard#preview', :as => "preview"

  get "/new-claim/" => "dashboard#new_claim", :as => "new_claim"
  post "/claim_upload/:id/" => "dashboard#upload_claim", :as => "claim_upload"
  get "/display-claim/:id" => "dashboard#display_claim", :as => "display_claim"
  post "/display-claim/:id" => "dashboard#display_claim", :as => "display_claim_post"
  post "/upload/:folder_id" => "dashboard#upload", :as => "upload"

  get "/auth0/failure" => "auth0#failure"
  get "/auth0/callback" => "auth0#callback"

  get '/logout' => 'home#logout', :as => "logout"
  get '/reset-logins' => 'home#reset_logins', :as => "reset_logins"


  get '/config' => "config#show", :as => 'config'
  get '/config/:reset' => "config#show", :as => "reset_config"
  post '/config' => "config#show", :as => "save_config"

end
