require "rails_helper"

RSpec.describe "Account imports" do
  include ActiveJob::TestHelper

  let(:report) { fixture_file_upload("mt5_report_sample.xlsx") }

  def upload(file = report)
    post account_imports_path, params: { account_import: { report: file } }
  end

  it "requires sign-in" do
    expect { upload }.not_to change(AccountImport, :count)
    expect(response).to redirect_to(new_session_path)
  end

  it "is closed to the demo user" do
    sign_in create(:user, :demo)

    expect { upload }.not_to change(AccountImport, :count)
    expect(response).to redirect_to(root_path)
    get new_account_import_path
    expect(response).to redirect_to(root_path)
  end

  it "stores the report, queues the job and shows live status" do
    sign_in

    expect { upload }.to have_enqueued_job(ImportAccountReportJob)

    expect(response).to redirect_to(account_import_path(AccountImport.last))
    follow_redirect!
    expect(response.body).to include("turbo-cable-stream-source", "Queued")
  end

  it "shows the summary after the job runs" do
    sign_in
    perform_enqueued_jobs { upload }

    get account_import_path(AccountImport.last)
    expect(response.body).to include("Completed", "View account")

    get account_path(Account.last)
    expect(response.body).to include("••••4567")
    expect(response.body).not_to include("1234567", "Sample Owner")
  end

  it "explains why a file was refused" do
    sign_in

    upload fixture_file_upload("mt5_report_sample.xlsx").tap { _1.instance_variable_set(:@original_filename, "report.html") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(".xlsx file")
  end

  it "ignores a string in place of a file" do
    sign_in

    expect { upload "forged-signed-id" }.not_to change(AccountImport, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "does not serve uploaded files" do
    expect(Rails.application.routes.routes.map { _1.path.spec.to_s }.grep(/active_storage/)).to be_empty
  end
end
