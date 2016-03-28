class EventstreamController < SecuredController

  def show
    session[:current_page] = "eventstream"
    threads = []

    user = user_client
    admin = Box.admin_client
    ap user

    # get user/admin tokens
    @user_access_token = user.access_token
    @ent_access_token = admin.access_token

    now = Time.now.utc
    start_date = now - (60*60*24) # one day ago

    # get user eventstream position and last 20 events
    threads << Thread.new do
      @user_events = []
      results = user.user_events(0, stream_type: :all)
      initPosition = results.next_stream_position
      results1 = user.user_events(initPosition, stream_type: :all)
      @user_stream_pos = results1.next_stream_position

      @user_events = results["events"].reverse[0..50]
      # ap @user_events
      # ap @user_events
    end

    # get enterprise events and enterprise eventstream position
    threads << Thread.new do
      results = admin.enterprise_events(created_after: start_date, created_before: now, limit: 50)
      # ap results["events"].size
      @enterprise_events = results["events"].reverse[0..75]
      @enterprise_stream_pos = results.next_stream_position
    end

    threads.each { |thr| thr.join }
  end

end
