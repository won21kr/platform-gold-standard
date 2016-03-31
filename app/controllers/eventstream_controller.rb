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

      # get most recent chunk of events
      temp = user.user_events(0, stream_type: :all)
      while (temp.chunk_size != 0)
        if (temp.chunk_size != 0)
          results = temp
        end

        temp = user.user_events(temp.next_stream_position, stream_type: :all)
      end

      # remove all of those damn previews events!
      results["events"] = remove_preview_events(results["events"], "ITEM_PREVIEW")

      # get next stream position and extract 50 unique events
      @user_stream_pos = results.next_stream_position
      @user_events = results["events"].reverse[0..50].uniq
    end

    # get enterprise events and enterprise eventstream position
    threads << Thread.new do
      results = admin.enterprise_events(created_after: start_date, created_before: now, limit: 400)
      # remove all of those damn previews events!
      results["events"] = remove_preview_events(results["events"], "PREVIEW")
      @enterprise_events = results["events"].reverse[0..75].uniq
      @enterprise_stream_pos = results.next_stream_position
    end

    threads.each { |thr| thr.join }
  end

  # remove all of the extra preview events
  def remove_preview_events(events, eventType)
    results = []
    prev = nil

    events.each do |r|

      if (!prev.nil? and r.event_type == eventType and
          DateTime.strptime(r.created_at).strftime("%M").to_i - DateTime.strptime(prev.created_at).strftime("%M").to_i <= 0)
        # repeat, do nothing
      else
        prev = r
        results << r
      end
    end
    # return results
    results
  end

end
