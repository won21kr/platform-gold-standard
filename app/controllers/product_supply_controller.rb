class ProductSupplyController < SecuredController

  skip_before_filter :verify_authenticity_token

  def show

    client = user_client
    threads = []
    @supplies = Hash.new

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

    redirect_to product_supply_path
  end



end
