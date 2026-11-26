class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true
  validate :only_one_account_per_role

  scope :owners, -> { where(demo: false) }

  def owner?
    !demo?
  end

  private
    def only_one_account_per_role
      return unless User.where(demo: demo).where.not(id: id).exists?

      errors.add(:base, "Robotalia has a single #{demo? ? "demo" : "owner"} account")
    end
end
