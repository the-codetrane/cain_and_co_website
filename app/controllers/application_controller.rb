class ApplicationController < ActionController::Base
  include Authentication

  # This is a public, account-free band site: fans never log in. The site is therefore
  # public by default, and the single admin area re-requires authentication in
  # Admin::BaseController. All admin controllers MUST inherit from Admin::BaseController.
  # Accounts are invite-only (Admin › Users) and never fan-facing.
  allow_unauthenticated_access

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
