class Users::PasswordResetsController < ApplicationController

  skip_before_action :require_login rescue nil
  
  def new
    skip_authorization
  end
  
  def generate_token
    skip_authorization
    User::PasswordReset.new_for_email(params[:email])
    flash_notice
    render :type_token
  end
  
  def typed_token
    skip_authorization
    query = if params[:email].present?
      { email: params[:email] }
    elsif params[:id].present?
      { id: params[:id] }
    end
    users = User.respond_to?(:custom_where_by) ? User.custom_where_by(**query) : User.where(**query)
    user = users.order(id: :asc).first
    user_id = user.id
    if User::PasswordReset.token_allowed(token: params[:token], user_id: user_id)
      flash_success
      @username = user.username
      render :new_password
    else
      flash_error
      render :type_token
    end
  end
  
  def typed_new_password_for_password_reset
    skip_authorization
    if params[:id].present?
      user_id = params[:id]
    else
      users = User.respond_to?(:custom_where_by) ? User.custom_where_by(email: params[:email]) : User.where(email: params[:email])
      user_id = users.order(id: :asc).first.id
    end
    if User::PasswordReset.token_allowed(token: params[:token], user_id: user_id)
      user = User.find user_id
      if user.update(user_password_params)
        flash_success
        User::PasswordReset.delete_token_for_user(user_id)
        redirect_to root_path
      else
        error('.passwords_not_identical')
        render :new_password
      end
    else
      error('.wrong_code')
      redirect_to type_token_for_password_reset_path
    end
  end
  
  def user_password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
  
  def cancel
    skip_authorization
    if User::PasswordReset.cancel_if_allowed(token: params[:reset_token], user_id: params[:user_id])
      flash_success
    else
      flash_error
    end
    redirect_to root_path
  end
  
end
