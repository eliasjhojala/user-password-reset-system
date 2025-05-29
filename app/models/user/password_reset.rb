class User::PasswordReset < ApplicationRecord
  self.table_name = 'user_password_resets'
  
  belongs_to :user, optional: true
  
  def self.new_for_email(email)
    return false unless email.present?
    users = User.respond_to?(:custom_where_by) ? User.custom_where_by(email: email) : User.where(email: email)
    if users.exists?
      user = users.order(id: :asc).first
      self.where(user_id: user.id).delete_all if self.where(user_id: user.id).exists?
      token = new_token
      digest = digest(token)
      password_reset = new
      password_reset.user = user
      password_reset.reset_digest = digest
      password_reset.save
      
      domain = Rails.application.config.action_controller.default_url_options[:host]
      
      UserPasswordResetMailer.with(user: user, email: user.email, reset_token: token,
        change_link: Rails.application.routes.url_helpers.email_link_for_typed_token_for_password_reset_url(user, token),
        domain: domain
      ).password_reset_email.deliver_now
      
      if (send_sms = UserPasswordResetSystem.settings[:send_sms]) && user.phone.present?
        send_sms[to: user.phone, message: I18n.t("user.password_reset.info_sms_about_asked_reset", domain: domain)]
      end
      
      return true
    else
      return false
    end
  end
  
  def self.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
 end
   
  def self.new_token
    SecureRandom.urlsafe_base64
  end
  
  def self.token_allowed(**options)
    if self.where(user_id: options[:user_id]).exists?
      correct_digest = self.where(user_id: options[:user_id]).last.reset_digest
      return BCrypt::Password.new(correct_digest) == options[:token]
    else
      return false
    end
  end

  def self.delete_token_for_user(user_id)
    self.where(user_id: user_id).delete_all if self.where(user_id: user_id).exists?
  end
  
end
