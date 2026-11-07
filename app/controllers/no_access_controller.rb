class NoAccessController < ApplicationController
  # Holding page for signed-in accounts without admin. It's a real page that non-admins are
  # redirected to, not a 403 rendered in place: Turbo doesn't update the URL for an error
  # response, which would strand an invitee on their used invitation link.
  layout "minimal"

  before_action :require_authentication

  def show
    redirect_to admin_root_path if Current.user.admin?
  end
end
