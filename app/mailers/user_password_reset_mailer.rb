class UserPasswordResetMailer < ApplicationMailer
  
  def password_reset_email(**options)
    @user = params[:user]
    @email = params[:email]
    @reset_token = params[:reset_token]
    @change_link = params[:change_link]
    @domain = params[:domain]
    mail(to: @email, subject: I18n.t("mailers.user_password_reset_mailer.password_reset_email.subject"))
  end
  
end
