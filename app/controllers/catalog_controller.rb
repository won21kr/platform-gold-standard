########################### COMMMENTING OUT DUE TO VIEW API DEPRECATE #############################
###################################################################################################
##################################################################################################

# class CatalogController < SecuredController
#   before_action :set_gon
#   # main catalog controller

  # HOME PAGE CODE - Commenting out due to design decision
 #  def home
 #    # get user client to make API calls
 #    client = user_client
 #    session[:current_page] = "catalog"
 #
 #    # Get root Product Catalog Folder from cache
 #    @product_catalog = Rails.cache.fetch("/product_catalog_folder/#{ENV['PRODUCT_CATALOG_FOLDER']}", :expires_in => 15.minutes) do
 #      client.folder_from_id(ENV['PRODUCT_CATALOG_FOLDER'], fields: [:id, :name, :size])
 #
 #      @file1 = Rails.cache.fetch("/product_catalog_folder/file/#{ENV['PRODUCT_CATALOG_FILE1']}", :expires_in => 15.minutes) do
 #        client.file_from_id(ENV['PRODUCT_CATALOG_FILE1'], fields: [:id])
 #      end
 #
 #      puts @file1
 #    end
 #
 #    # get file id's from the product_catalog_folder
 #    #
 #    # @files = client.folder_items(@myFolder, fields: [:name, :id]).files
 #    #
 #
 #    # @fileId = '41372508334'
 #    # session[:fileId] = @fileId
 #    #
 #    # @file = client.file_from_id(@fileId)
 # end

# def show
#     # get user client obj and file ID
#     client = user_client
#     session[:current_page] = "catalog"
#
#
#     @product_catalog = Rails.cache.fetch("/product_catalog_folder/#{ENV['PRODUCT_CATALOG_FOLDER']}", :expires_in => 15.minutes) do
#       client.folder_from_id(ENV['PRODUCT_CATALOG_FOLDER'], fields: [:id, :name, :size])
#     end
#
#  end
#
#  def set_gon
#      puts "In GON Product Catalog controller............"
#      gon.current_catalog_file = session[:catalog_file]
#      ap gon.current_catalog_file
#
#  end
#
#   def thumbnail
#
#     image = Rails.cache.fetch("/image_thumbnail/#{params[:id]}", :expires_in => 10.minutes) do
#       puts "miss!"
#       user_client.thumbnail(params[:id], min_height: 256, min_width: 256)
#     end
#
#     send_data image, :type => 'image/png', :disposition => 'inline'
#   end
#
# end
