class EventstreamController < SecuredController

  def show
    session[:current_page] = "eventstream"
    threads = []

    user = user_client
    admin = Box.admin_client

    # get user/admin tokens
    @user_access_token = user.access_token
    @ent_access_token = admin.access_token

    now = Time.now.utc
    start_date = now - (60*60*24) # one day ago

    # get user eventstream position and last 20 events
    threads << Thread.new do
      results = user.user_events(0, stream_type: :all)
      @user_events = results["events"].reverse[0..50]
      @user_stream_pos = results.next_stream_position
      ap @user_events
    end

    # get enterprise events and enterprise eventstream position
    threads << Thread.new do
      results = admin.enterprise_events(created_after: start_date,
                                        created_before: now,
                                        limit: 20)
      @enterprise_events = results["events"].reverse[0..50]
      @enterprise_stream_pos = results.next_stream_position
      # ap @enterprise_events
      # ap @enterprise_stream_pos

    end

    # ap @user_stream_pos

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

    threads.each { |thr| thr.join }
  end

end
