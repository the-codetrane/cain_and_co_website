module Admin
  # Base controller for the admin area. This is the single authentication chokepoint:
  # every Admin:: controller must inherit from here so the whole admin area requires login.
  # (ApplicationController is public-by-default — see the comment there.)
  class BaseController < ApplicationController
    before_action :require_authentication

    layout "admin"
  end
end
