class ProductSupplyController < SecuredController

  DOCUSIGN_CLIENT = DocusignRest::Client.new
  skip_before_filter :verify_authenticity_token

  def show

    client = user_client
    threads = []
    @supplies = Hash.new
    session[:current_page] = "product_supply"
    # get order form path
    path = "#{session[:userinfo]['info']['name']}\ -\ Order\ Forms"

    # get medical supply folder
    folder = Rails.cache.fetch("/folder/supplies/#{ENV['MEDICAL_SUPPLIES']}", :expires_in => 20.minutes) do
      client.folder_from_id(ENV['MEDICAL_SUPPLIES'], fields: [:id, :name, :description])
    end

    # get all supply products
    medItems = Rails.cache.fetch("/folder/supplies/#{ENV['MEDICAL_SUPPLIES']}/items", :expires_in => 20.minutes) do
      client.folder_items(folder, fields: [:id, :name, :description])
    end

    # iterate through supply products and populate hash
    medItems.each do |item|
      threads << Thread.new do
        itemFolder = Rails.cache.fetch("/folder/supplies/#{ENV['MEDICAL_SUPPLIES']}/#{item.id}", :expires_in => 20.minutes) do
          client.folder_from_id(item.id, fields: [:id, :name, :description])
        end

        files = Rails.cache.fetch("/files/supplies/#{ENV['MEDICAL_SUPPLIES']}/#{item.id}", :expires_in => 20.minutes) do
          client.folder_items(itemFolder).files
        end

        image = files.select{ |f| f.name.split('.').first == "default image" }.first
        dataSheets = files.select{ |f| f.name.split('.').first != "default image" }

        @supplies.store(itemFolder.id, {folderName: itemFolder.name, image: image, sheets: dataSheets})
      end
    end

    threads.each {|thr| thr.join}

    # get order forms folder, if it doesn't exist create one
    begin
      @orderFormFolder = Rails.cache.fetch("/folder/#{session[:box_id]}/order_forms", :expires_in => 20.minutes) do
        client.folder_from_path(path)
      end
    rescue
      @orderFormFolder = client.create_folder("#{session[:userinfo]['info']['name']} - Order Forms", Boxr::ROOT)
    end
    @orderHistory = client.folder_items(@orderFormFolder, fields: [:id, :name, :created_at])

    if (params[:page_redirect] == "orders")
      @currentPage = params[:page_redirect]
    end

  end


  def update_cart

    cartItems = params[:cart]
    cart = Array.new

    if cartItems.nil?
      cart = []
    else
      cartItems.each do |c|
        cart.push(c[1])
      end
    end

    render partial: 'cart', locals: {cartItems: cart}
  end

  def order_supplies

    orders = JSON.parse(params[:orders].tr("=", ":").tr(">", ""))
    client = user_client

    filename = "tmp/Order Form #{DateTime.now}.pdf"

    # the "Doc" module code can be found in app/models/
    doc = Doc.new({:orders => orders,
                   :username => session[:userinfo]['info']['name']})

    path = "#{session[:userinfo]['info']['name']}\ -\ Order\ Forms"
    doc.configure_pdf(client, filename, path, ENV['ORDER_FORM'])

    flash[:notice] = "Thanks for filling out your order! Please review and sign your order form."
    redirect_to product_supply_path(page_redirect: "orders")
  end

  # start order docusign process
  def order_docusign

    fileId = params[:file_id]
    envelope_response = create_docusign_envelope(fileId)

    # set up docusign view, fetch url
    recipient_view = DOCUSIGN_CLIENT.get_recipient_view(
      envelope_id: envelope_response["envelopeId"],
      name: "Marcus Doe",
      email: "mmitchell+standard@box.com",
      return_url: docusign_response_order_url(envelope_response["envelopeId"])
    )

    @url = recipient_view["url"]
  end

  # create docusign envelope for order form
  def create_docusign_envelope(box_doc_id)

    box_user = user_client

    box_file = box_user.file_from_id(box_doc_id)
    raw_file = box_user.download_file(box_file)
    temp_file = Tempfile.open("box_doc_", Rails.root.join('tmp'), :encoding => 'ascii-8bit')

    begin
      temp_file.write(raw_file)
      temp_file.close

      puts "doc client"
      ap DOCUSIGN_CLIENT
      envelope = DOCUSIGN_CLIENT.create_envelope_from_document(
        email: {
          subject: "Signature Requested",
          body: "Please electronically sign this document."
        },
        # If embedded is set to true in the signers array below, emails
        # don't go out to the signers and you can embed the signature page in an
        # iFrame by using the client.get_recipient_view method
        signers: [
          {
            embedded: true,
            name: 'Marcus Doe',
            email: 'mmitchell+standard@box.com',
            role_name: 'Client',
            sign_here_tabs: [{anchor_string: "Signature:", anchor_x_offset: '100', anchor_y_offset: '0'}]
          }
        ],
        files: [
          {path: temp_file.path, name: "#{box_file.name}"}
        ],
        status: 'sent'
      )

      session[envelope["envelopeId"]] = {box_doc_id: box_file.id, box_doc_name: box_file.name}
    rescue => ex
      puts "Error in creating envo"
    ensure
      temp_file.delete
    end

    envelope
  end

  # docusign response for order form
  def docusign_response_order
    utility = DocusignRest::Utility.new

    if params[:event] == "signing_complete"
      temp_file = Tempfile.open(["docusign_response_",".pdf"], Rails.root.join('tmp'), :encoding => 'ascii-8bit')

      begin
        DOCUSIGN_CLIENT.get_document_from_envelope(
          envelope_id: params["envelope_id"],
          document_id: 1,
          local_save_path: temp_file.path
        )

        box_info = session[params["envelope_id"]]

        box_user = user_client
        completedPath = "#{session[:userinfo]['info']['name']}\ -\ Order\ Forms"
        signed_folder = box_user.folder_from_path(completedPath)
        file = box_user.upload_file(temp_file.path, signed_folder)
        box_user.update_file(file, name: "Order Form #{DateTime.now} - SIGNED.pdf")

        box_user.delete_file(box_info[:box_doc_id])

      ensure
        temp_file.delete
      end

      flash[:notice] = "Order form signed and submitted to a company representative."
      render :text => utility.breakout_path(product_supply_path(page_redirect: "orders")), content_type: 'text/html'
    else
      flash[:error] = "You chose not to sign the document."
      render :text => utility.breakout_path(product_supply_path(page_redirect: "orders")), content_type: 'text/html'
    end
  end

  def product_supply_reset

    client = user_client
    path = "#{session[:userinfo]['info']['name']}\ -\ Order\ Forms"

    begin
      @ordersFolder = Rails.cache.fetch("/orders-folder/#{session[:box_id]}", :expires_in => 15.minutes) do
        client.folder_from_path(path)
      end
      @orders = client.folder_items(@ordersFolder, fields: [:id, :name])
    rescue
      puts "folder not yet created"
    end

    @orders.each do |c|
      client.delete_file(c)
    end

    redirect_to product_supply_path
  end


end
