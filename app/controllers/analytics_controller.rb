class AnalyticsController < ApplicationController

  def show
    session[:current_page] = "analytics"
  end


end
