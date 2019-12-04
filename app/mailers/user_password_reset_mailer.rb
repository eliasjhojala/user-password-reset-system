class UserPasswordResetMailer < ApplicationMailer
  
  def password_reset_email(**options)
    @user = options[:user]
    @email = options[:email]
    @reset_token = options[:reset_token]
    @change_link = options[:change_link]
    @cancel_link = options[:cancel_link]
    @domain = options[:domain]
    mail(to: @email, subject: I18n.t("mailers.user_password_reset_mailer.password_reset_email.subject"))
  end
  
end
