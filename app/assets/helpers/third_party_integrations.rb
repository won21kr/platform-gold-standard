module ThirdPartyIntegrations
  def send_grid_method

    puts "MADE IT TO THE METHOD: #{session[:sharedLink]}"
    client = SendGrid::Client.new do |c|
      c.api_user = 'carycheng77'
      c.api_key =  'CaryCheng77' #'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'
    end

    mail = SendGrid::Mail.new do |m|
      m.to = "carycheng77@gmail.com"
      m.from = "carycheng77@gmail.com"
      m.subject = 'Here is your customized Box Platform Standard'
      m.text = session[:sharedLink]
    end

    puts client.send(mail)
    # {"message":"success"}
    redirect_to request_for_proposal_path
  end
end
