class Robot < ApplicationRecord
  belongs_to :account
  has_many :trades, dependent: :nullify

  validates :key, :name, presence: true

  # The trade comment identifies the robot. MT5 writes "[sl 1.2345]" and "[tp 1.2345]"
  # on exits, which never name one.
  def self.key_for(comment)
    key = comment.to_s.strip.downcase
    key unless key.empty? || key.start_with?("[")
  end
end
