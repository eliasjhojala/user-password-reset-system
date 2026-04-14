class User::PasswordReset < ApplicationRecord
  self.table_name = 'user_password_resets'

  belongs_to :user, optional: true

  def self.log_password_setting_event(**attrs)
    UserPasswordResetSystem.settings[:log_password_setting_event]&.call(**attrs)
  end

  # contact: one string matched against username, email, and phone; reset proceeds only if exactly one User matches.
  # email / phone: explicit channels for programmatic use (e.g. admin-triggered reset from known user attributes).
  # Returns the User when instructions were sent, false otherwise (truthy/falsy compatible with prior true/false callers).
  def self.request_reset(email: nil, phone: nil, contact: nil)
    user =
      if contact.present?
        find_unique_user_for_password_reset(contact)
      else
        email = email.to_s.strip.presence
        phone = phone.to_s.strip.presence
        return false if email.blank? && phone.blank?

        find_user_for_reset_request(email: email, phone: phone)
      end
    return false unless user
    return false unless user_may_request_password_reset?(user)

    if user_has_email?(user)
      return false unless new_for_email(user.email.to_s.strip)
    else
      return false unless new_for_sms(user)
    end
    UserPasswordResetSystem.settings[:on_reset_requested]&.call(user)
    user
  end

  # Resolves the user for password-reset follow-up steps when the client sends the scoped user id
  # (e.g. hidden field after generate_token). For initiating a reset by free-text contact, use request_reset(contact: ...).
  def self.user_for_identifier(id:)
    return nil if id.blank?

    apply_password_reset_user_scope(User).find_by(id: id)
  end

  def self.new_for_email(email)
    return false unless email.present?

    users = User.respond_to?(:custom_where_by) ? User.custom_where_by(email: email) : User.where(email: email)
    users = apply_password_reset_user_scope(users)
    if users.exists?
      user = users.order(id: :asc).first
      create_token_and_send_email!(user, email)
      true
    else
      false
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

  def self.find_user_for_reset_request(email:, phone:)
    u = find_by_email(email) if email.present?
    u ||= find_by_phone(phone) if phone.present?
    u
  end

  def self.find_unique_user_for_password_reset(contact)
    ids = user_ids_matching_reset_contact(contact)
    return nil if ids.size != 1

    User.find_by(id: ids.first)
  end

  def self.user_ids_matching_reset_contact(contact)
    contact = contact.to_s.strip
    return [] if contact.blank?

    base = apply_password_reset_user_scope(User)
    down = contact.downcase
    ids = []

    if User.column_names.include?('username')
      ids.concat base.where('LOWER(username) = ?', down).pluck(:id)
    end

    if User.respond_to?(:custom_where_by)
      rel = apply_password_reset_user_scope(User.custom_where_by(email: contact))
      ids.concat(rel.pluck(:id))
    else
      ids.concat base.where('LOWER(email) = ?', down).pluck(:id)
    end

    normalizer = UserPasswordResetSystem.settings[:normalize_phone]
    normalized = normalizer ? normalizer.call(contact) : nil
    normalized = normalized.to_s.strip.presence
    raw = contact

    if normalized.present?
      ids.concat base.where(login_method: :phone, phone: normalized).pluck(:id)
      ids.concat base.where(phone: normalized).pluck(:id)
    end
    if raw.present?
      ids.concat base.where(login_method: :phone, phone: raw).pluck(:id)
      ids.concat base.where(phone: raw).pluck(:id)
    end

    ids.uniq
  end

  # Optional host hook: UserPasswordResetSystem.settings[:user_may_request_password_reset?] = ->(user) { ... }
  # Return false to refuse sending reset instructions (e.g. disabled accounts). When unset, all found users are allowed.
  def self.user_may_request_password_reset?(user)
    checker = UserPasswordResetSystem.settings[:user_may_request_password_reset?]
    return true if checker.blank?

    !!checker.call(user)
  end
  # Optional: UserPasswordResetSystem.settings[:scope_users_for_password_reset] = ->(relation) { relation.where(...) }
  # Restrict which rows participate in lookup (e.g. exclude disabled accounts).
  def self.apply_password_reset_user_scope(relation)
    merger = UserPasswordResetSystem.settings[:scope_users_for_password_reset]
    return relation unless merger.respond_to?(:call)

    merger.call(relation)
  end

  private_class_method :user_may_request_password_reset?, :find_unique_user_for_password_reset,
                       :user_ids_matching_reset_contact, :apply_password_reset_user_scope

  def self.user_has_email?(user)
    user.email.present?
  end

  def self.find_by_email(email)
    return nil if email.blank?

    users = User.respond_to?(:custom_where_by) ? User.custom_where_by(email: email) : User.where(email: email)
    users = apply_password_reset_user_scope(users)
    users.order(id: :asc).first
  end

  def self.find_by_phone(raw)
    return nil if raw.blank?

    normalizer = UserPasswordResetSystem.settings[:normalize_phone]
    normalized = normalizer ? normalizer.call(raw) : raw.strip
    return nil if normalized.blank?

    base = apply_password_reset_user_scope(User)
    base.find_by(login_method: :phone, phone: normalized) ||
      base.find_by(login_method: :phone, phone: raw.strip) ||
      base.find_by(phone: normalized) ||
      base.find_by(phone: raw.strip)
  end

  def self.new_for_sms(user)
    return false unless user.phone.present?

    send_sms = UserPasswordResetSystem.settings[:send_sms]
    return false unless send_sms

    create_token_and_deliver_sms!(user, send_sms)
    true
  end

  def self.create_token_and_send_email!(user, to_email)
    self.where(user_id: user.id).delete_all if self.where(user_id: user.id).exists?
    token = new_token
    token_digest = digest(token)
    password_reset = new
    password_reset.user = user
    password_reset.reset_digest = token_digest
    password_reset.save

    domain = Rails.application.config.action_controller.default_url_options[:host]

    UserPasswordResetMailer.with(user: user, email: to_email, reset_token: token,
      change_link: Rails.application.routes.url_helpers.email_link_for_typed_token_for_password_reset_url(user, token),
      domain: domain
    ).password_reset_email.deliver_now

    log_password_setting_event(user: user, kind: 'password_reset_instructions_sent', actor: nil, channel: 'email')
  end

  def self.create_token_and_deliver_sms!(user, send_sms)
    self.where(user_id: user.id).delete_all if self.where(user_id: user.id).exists?
    token = new_token
    token_digest = digest(token)
    password_reset = new
    password_reset.user = user
    password_reset.reset_digest = token_digest
    password_reset.save

    domain = Rails.application.config.action_controller.default_url_options[:host]
    change_link = Rails.application.routes.url_helpers.email_link_for_typed_token_for_password_reset_url(user, token)

    send_sms[to: user.phone, message: I18n.t("user.password_reset.sms_reset_instructions", change_link: change_link, token: token, domain: domain)]

    log_password_setting_event(user: user, kind: 'password_reset_instructions_sent', actor: nil, channel: 'sms')
  end

  def self.log_password_reset_completed!(user)
    log_password_setting_event(user: user, kind: 'password_reset_completed', actor: user, channel: nil)
  end
  private_class_method :create_token_and_send_email!, :create_token_and_deliver_sms!

  SUBMIT_TOKEN_TTL = 15.minutes

  # Mint a short-lived one-time token that the password-reset form submits as a hidden field,
  # preventing replay from browser history after the main reset token is consumed.
  def self.generate_submit_token!(user_id:)
    token = new_token
    where(user_id: user_id).update_all(
      submit_digest: digest(token),
      submit_valid_until: SUBMIT_TOKEN_TTL.from_now
    )
    token
  end

  def self.submit_token_valid?(user_id:, token:)
    return false if token.blank?

    record = where(user_id: user_id).where('submit_valid_until > ?', Time.current).order(id: :desc).first
    return false if record.nil? || record.submit_digest.nil?

    BCrypt::Password.new(record.submit_digest) == token
  end

  def self.consume_submit_token!(user_id:)
    where(user_id: user_id).update_all(submit_digest: nil, submit_valid_until: nil)
  end

end
