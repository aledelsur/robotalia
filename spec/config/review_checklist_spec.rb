require "spec_helper"
require "yaml"

# The CI review and the rails-reviewer subagent must keep reading the same checklist.
RSpec.describe "Review checklist" do
  project = File.expand_path("../..", __dir__)
  checklist = ".claude/review-checklist.md"

  define_method(:read) { |path| File.read(File.join(project, path)) }

  it "is what the CI review is told to follow" do
    steps = YAML.safe_load(read(".github/workflows/claude-code-review.yml")).dig("jobs", "review", "steps")
    prompts = steps.filter_map { _1.dig("with", "prompt") }

    expect(prompts.size).to eq(1)
    expect(prompts.first).to include(checklist, "CLAUDE.md")
  end

  it "is what the rails-reviewer subagent follows" do
    expect(read(".claude/agents/rails-reviewer.md")).to include(checklist)
  end

  it "covers the project's review areas" do
    expect(read(checklist)).to include(
      "## 2. Rails 8 conventions", "## 3. Queries and indexes", "## 4. Security", "## 5. Privacy",
      "## 6. Claude API conventions", "## 7. Tests", "AiCall", "never computes or invents a metric"
    )
  end
end
