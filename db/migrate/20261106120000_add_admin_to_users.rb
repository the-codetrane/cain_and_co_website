class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false

    # Until now every account was implicitly an admin, so existing ones keep that access.
    up_only { execute "UPDATE users SET admin = TRUE" }
  end
end
