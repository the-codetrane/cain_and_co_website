class RobotsController < ApplicationController
  def show
    expires_in 24.hours, public: true
    render formats: :text
  end
end
