class AddResetValidUntilToUserPasswordResets < ActiveRecord::Migration[5.2]
  def change
    add_column :user_password_resets, :reset_valid_until, :datetime
  end
end
