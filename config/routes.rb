Rails.application.routes.draw do
  scope module: :users do
    scope path: 'salasanan_uusiminen' do
      get '/' => 'password_resets#new', as: 'new_password_reset'
        post 'generoi' => 'password_resets#generate_token', as: 'generate_token_for_password_reset'
        get 'kirjoita' => 'password_resets#type_token', as: 'type_token_for_password_reset'
        get 'luo_uusi/:id/:token' => 'password_resets#typed_token', as: 'email_link_for_typed_token_for_password_reset'
        post 'luo_uusi' => 'password_resets#typed_token', as: 'typed_token_for_password_reset'
        post 'uusi_luotu' => 'password_resets#typed_new_password_for_password_reset', as: 'typed_new_password_for_password_reset'
        get 'peru/:user_id/:reset_token' => 'password_resets#cancel', as: 'cancel_password_reset'
    end
  end
end
