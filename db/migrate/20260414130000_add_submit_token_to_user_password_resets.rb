class AddSubmitTokenToUserPasswordResets < ActiveRecord::Migration[5.2]
  def change
    change_table :user_password_resets, bulk: true do |t|
      t.string :submit_digest
      t.datetime :submit_valid_until
    end
  end
end
