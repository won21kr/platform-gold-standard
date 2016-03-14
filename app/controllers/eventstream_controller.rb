class EventstreamController < SecuredController

  def show
    session[:current_page] = "eventstream"

    user = user_client
    admin = Box.admin_client

    now = Time.now.utc
    start_date = now - (60*60*24) # one day ago

    # user_stream_pos = user.user_events('now', stream_type: :all).next_stream_position - 100
    @user_events = user.user_events(0, stream_type: :all, limit: 20)["events"]
    # ap @user_events


    # box_client = HTTPClient.new
    # headers = {"Authorization" => "Bearer #{admin.access_token}"}
    # uri = 'https://api.box.com/2.0/events'
    # query = {}
    # query['stream_type'] = 'admin_logs'
    # query["limit"] = 5
    # query['stream_position'] = 0
    #
    # res = box_client.get(uri, query: query, header: headers)
    # ap res

    # result = admin.enterprise_events(created_after: start_date, created_before: now, limit: 10)




  end

end
