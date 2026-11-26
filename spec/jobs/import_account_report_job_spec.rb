require "rails_helper"

RSpec.describe ImportAccountReportJob do
  let(:import) do
    AccountImport.new.tap do |record|
      record.report.attach(io: file_fixture("mt5_report_sample.xlsx").open, filename: "report.xlsx")
      record.save!
    end
  end

  def broadcasts = ActionCable.server.pubsub.broadcasts(import.to_gid_param)

  it "runs on Sidekiq's default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "imports the report and broadcasts each status change" do
    described_class.perform_now(import)

    expect(import.reload).to be_completed
    expect(import.finished_at).to be_present
    expect(broadcasts.size).to eq(2)
    expect(broadcasts.last).to include("Completed")
  end

  it "fails with a readable message when the file is not a report" do
    import.report.attach(io: StringIO.new("nope"), filename: "report.xlsx")

    described_class.perform_now(import)

    expect(import.reload).to be_failed
    expect(import.error_messages.first).to match(/could not be read/)
    expect(broadcasts.last).to include("Failed")
  end

  it "marks the import failed and re-raises on an unexpected error" do
    allow_any_instance_of(Mt5Report::Importer).to receive(:call).and_raise(RuntimeError, "secret detail")

    expect { described_class.perform_now(import) }.to raise_error(RuntimeError)
    expect(import.reload).to be_failed
    expect(import.error_messages.join).not_to include("secret detail")
  end
end
