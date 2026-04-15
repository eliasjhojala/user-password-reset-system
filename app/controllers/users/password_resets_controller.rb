class Users::PasswordResetsController < ApplicationController

  skip_before_action :require_login rescue nil

  def new
    skip_authorization
  end

  def generate_token
    skip_authorization
    reset_user = User::PasswordReset.request_reset(contact: reset_contact) if reset_contact.present?
    @password_reset_user_id = reset_user.id if reset_user
    flash_notice
    flash.discard(:notice)
    render :type_token
  end

  def type_token
    skip_authorization
  end

  def typed_token
    skip_authorization
    if request.get?
      # GET from email/SMS link: render a safe landing page (no token validation).
      # Link-preview bots only issue GETs, so the token is never consumed here.
      @token = params[:token]
      @id = params[:id]
      render :token_landing
    else
      user = User::PasswordReset.user_for_identifier(id: params[:id].presence)
      if user.present?
        user_id = user.id
        if User::PasswordReset.token_allowed(token: params[:token], user_id: user_id)
          User::PasswordReset.consume_reset_token!(user_id: user_id)
          flash_success
          @user = user
          @submit_token = User::PasswordReset.generate_submit_token!(user_id: user_id)
          render :new_password
          return
        end
      end
      flash_error
      render :type_token
    end
  end

  def typed_new_password_for_password_reset
    skip_authorization
    user = User::PasswordReset.user_for_identifier(id: params[:id].presence)
    if user.blank?
      flash_error '.wrong_code'
      redirect_to type_token_for_password_reset_path(password_reset_redirect_id_params)
      return
    end

    user_id = user.id
    unless User::PasswordReset.submit_token_valid?(user_id: user_id, token: params[:submit_token])
      @submit_token_expired = true
      render :new_password
      return
    end

    if user.update(user_password_params)
      User::PasswordReset.consume_submit_token!(user_id: user_id)
      User::PasswordReset.delete_token_for_user(user_id)
      User::PasswordReset.log_password_reset_completed!(user)
      unless UserPasswordResetSystem.settings[:run_after_password_reset_success]
        flash_success
        redirect_to root_path
      else
        after_password_reset_success user
      end
    else
      @user = user
      @submit_token = params[:submit_token]
      render :new_password
    end
  end

  def user_password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  private

  def reset_contact
    params[:contact].to_s.strip.presence
  end

  def password_reset_redirect_id_params
    id = params[:id].presence
    id ? { id: id } : {}
  end

end
