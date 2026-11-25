require "rails_helper"

RSpec.describe "Background job configuration" do
  it "uses Sidekiq as the Active Job adapter outside the test environment" do
    # config/environments/test.rb swaps in the :test adapter, so check the shared config file.
    expect(Rails.root.join("config/application.rb").read)
      .to include("config.active_job.queue_adapter = :sidekiq")
    expect(%w[development production].map { |env| Rails.root.join("config/environments/#{env}.rb").read })
      .to all(satisfy { |source| !source.match?(/^\s*config\.active_job\.queue_adapter/) })
  end

  it "has Sidekiq listen on the default and mailers queues" do
    config = YAML.safe_load(
      ERB.new(Rails.root.join("config/sidekiq.yml").read).result,
      permitted_classes: [ Symbol ]
    )

    expect(config[:queues]).to include("default", "mailers")
  end
end
