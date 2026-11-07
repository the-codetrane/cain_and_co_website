module Admin
  # Base controller for the admin area. This is the single access chokepoint: every
  # Admin:: controller must inherit from here so the whole admin area requires an admin.
  # (ApplicationController is public-by-default — see the comment there.)
  class BaseController < ApplicationController
    before_action :require_authentication
    before_action :require_admin

    layout "admin"

    private

    # Checked per request, so revoking admin takes effect on a live session immediately.
    def require_admin
      redirect_to no_access_path, status: :see_other unless Current.user.admin?
    end
  end
end
