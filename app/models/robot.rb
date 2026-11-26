class Robot < ApplicationRecord
  belongs_to :account
  has_many :trades, dependent: :nullify

  validates :key, :name, presence: true

  # A robot trading both directions comments them apart ("M3_EURUSD_Long", "M3_EURUSD_Short").
  # The direction is not part of its identity: a trade's side already says long or short.
  DIRECTION = /\A(long|short)\z/i

  class << self
    # The trade comment identifies the robot.
    def key_for(comment)
      tokens(comment).map(&:downcase).join("_").presence
    end

    # "M3_EURUSD_Long" is "Model 3 · EURUSD".
    def name_for(comment)
      tokens(comment).map { |token| token[/\Am(\d+)\z/i, 1]&.then { "Model #{_1}" } || token.upcase }
        .join(" · ").presence
    end

    private
      # MT5 writes "[sl 1.2345]" and "[tp 1.2345]" on exits, which never name a robot.
      def tokens(comment)
        text = comment.to_s.strip
        return [] if text.start_with?("[")

        text.split(/[_\s-]+/).grep_v(DIRECTION).reject(&:empty?)
      end
  end
end
