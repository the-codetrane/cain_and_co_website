class InvitationsController < ApplicationController
  # Public by default via ApplicationController: the signed token is the credential.
  # Viewing the form changes nothing, so mail scanners that prefetch links can't use up
  # an invite; only submitting a password does.
  layout "minimal"

  before_action :set_invitation

  def edit
  end

  def update
    user = @invitation.accept(params.permit(:password, :password_confirmation))

    if user.persisted?
      start_new_session_for user
      redirect_to admin_root_url, notice: "Welcome! Your account is ready."
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_invitation
    @invitation = Invitation.find_by_token_for(:acceptance, params[:token])
    return if @invitation

    redirect_to new_session_path, alert: "This invitation link is invalid or has expired. Ask an admin to send a new one."
  end
end
