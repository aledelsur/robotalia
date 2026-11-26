class AccountImport < ApplicationRecord
  MAX_REPORT_SIZE = 10.megabytes

  belongs_to :account, optional: true
  has_one_attached :report

  enum :status, %w[queued processing completed failed].index_by(&:itself), default: "queued", validate: true

  validate :report_is_an_xlsx_file, on: :create

  def finished?
    completed? || failed?
  end

  private
    def report_is_an_xlsx_file
      if !report.attached?
        errors.add(:report, "is missing: choose a file")
      elsif report.filename.extension.downcase != "xlsx"
        errors.add(:report, "must be an .xlsx file (in MT5: History, Report, Open XML)")
      elsif report.byte_size > MAX_REPORT_SIZE
        errors.add(:report, "is larger than 10 MB")
      end
    end
end
