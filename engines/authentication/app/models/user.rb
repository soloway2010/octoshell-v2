# == Schema Information
#
# Table name: users
#
#  id                              :integer          not null, primary key
#  email                           :string(255)      not null
#  crypted_password                :string(255)
#  salt                            :string(255)
#  created_at                      :datetime
#  updated_at                      :datetime
#  activation_state                :string(255)
#  activation_token                :string(255)
#  activation_token_expires_at     :datetime
#  remember_me_token               :string(255)
#  remember_me_token_expires_at    :datetime
#  reset_password_token            :string(255)
#  reset_password_token_expires_at :datetime
#  reset_password_email_sent_at    :datetime
#  access_state                    :string(255)
#  deleted_at                      :datetime
#  last_login_at                   :datetime
#  last_logout_at                  :datetime
#  last_activity_at                :datetime
#  last_login_from_ip_address      :string(255)
#  language                        :string
#

class User < ActiveRecord::Base

    has_paper_trail

  authenticates_with_sorcery!
  validates :password, confirmation: true, length: { minimum: 6 }, on: :create
  validates :password, confirmation: true, length: { minimum: 6 }, on: :update, if: :password?
  validates :email, presence: true, uniqueness: true
  validate do
    errors.add(:email, :postmaster) if email[/postmaster/]
  end
  before_validation :downcase_email

  def activated?
    activation_state == "active"
  end

  def activation_pending?
    activation_state == "pending"
  end

  def password?
    password.present?
  end

  def send_activation_needed_email!
    Authentication::MailerWorker.perform_async(:activation_needed,
                               [email, activation_token, language])
  end

  def send_activation_success_email!
    Authentication::MailerWorker.perform_async(:activation_success, email)
  end

  def send_reset_password_email!
    Authentication::MailerWorker.perform_async(:reset_password,
                               [email, reset_password_token])
  end

  def last_login_from_ip_address=(arg)
    # stub
  end

  def downcase_email
    email.downcase! unless self.email.nil?
  end

  def self.delete_pending_users
    transaction do
      where("created_at < ? and activation_state = 'pending'",
            Date.today - Authentication.delete_after).each(&:destroy)
    end
  end
end
