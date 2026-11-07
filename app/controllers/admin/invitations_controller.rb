module Admin
  class InvitationsController < BaseController
    def new
      @invitation = Invitation.new
    end

    def create
      @invitation = Invitation.issue(**invitation_params.to_h.symbolize_keys)

      if @invitation.persisted? && @invitation.errors.none?
        InvitationMailer.with(invitation: @invitation).invite.deliver_later
        redirect_to admin_users_path, notice: "Invitation sent to #{@invitation.email}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # Destroying the row is what kills the link: the token only resolves to a live record.
    def destroy
      invitation = Invitation.find(params[:id])
      invitation.destroy
      redirect_to admin_users_path, notice: "Invitation to #{invitation.email} cancelled.", status: :see_other
    end

    private

    def invitation_params
      params.expect(invitation: [ :email, :admin ])
    end
  end
end
