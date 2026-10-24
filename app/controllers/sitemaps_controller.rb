class SitemapsController < ApplicationController
  def show
    @products = Product.published.by_name
    @shows = Show.upcoming
    expires_in 1.hour, public: true
    render formats: :xml
  end
end
