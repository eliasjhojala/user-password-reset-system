class CreateUserPasswordResets < ActiveRecord::Migration[5.2]
  def change
    create_table :user_password_resets do |t|
      t.belongs_to :user
      t.string :reset_digest
      t.timestamps
    end
  end
end
