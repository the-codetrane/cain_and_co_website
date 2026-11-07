module Admin
  class UsersController < BaseController
    def index
      @users = User.order(:email_address)
      @invitations = Invitation.order(sent_at: :desc)
    end

    # The only editable field is the admin flag. The target value is sent explicitly
    # rather than flipped here, so a click from a stale page can't do the opposite.
    def update
      @user = User.find(params[:id])

      if @user == Current.user
        redirect_to admin_users_path, alert: "You can't change your own admin access.", status: :see_other
      elsif @user.update(params.expect(user: [ :admin ]))
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(helpers.dom_id(@user), partial: "admin/users/row", locals: { user: @user })
          end
          format.html { redirect_to admin_users_path, notice: "Updated #{@user.email_address}.", status: :see_other }
        end
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence, status: :see_other
      end
    end
  end
end
