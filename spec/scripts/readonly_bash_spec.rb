require "spec_helper"
require "json"
require "open3"

RSpec.describe "Read-only agents Bash gate" do
  project = File.expand_path("../..", __dir__)

  define_method(:run_hook) do |name, tool_input|
    _, error, status = Open3.capture3({ "CLAUDE_PROJECT_DIR" => project }, File.join(project, ".claude/hooks", name),
                                      stdin_data: JSON.generate(tool_input:))
    [ status.exitstatus, error ]
  end

  describe "readonly_bash" do
    [
      "git diff origin/main...HEAD",
      "git log --all -p -G 'sk-ant-'",
      "git grep -n -i -E 'broker|server' HEAD",
      "git show 'HEAD:docs/PLAN.md'",
      "git rev-list --objects --all",
      "unzip -p spec/fixtures/files/mt5_report_sample.xlsx",
      "gitleaks git --redact"
    ].each do |command|
      it "allows #{command}" do
        expect(run_hook("readonly_bash", { command: }).first).to eq(0)
      end
    end

    [
      "touch x",
      "git commit -m x",
      "git push",
      "git -c core.pager=sh log",
      "git log && rm -rf tmp",
      "git log; rm x",
      "git log\nrm x",
      "git log | sh",
      "git log > notes.txt",
      "git log $(rm x)",
      "git log `rm x`",
      "git log \"'\" ; rm x ; \"'\"",
      "git log \\' ; rm x ; \\'",
      "git diff --output=notes.txt",
      "git diff '--output=notes.txt'",
      "git diff --outp notes.txt",
      "git show --ext-diff",
      "git grep -Osh pattern",
      "git grep --open-files-in-pager=sh pattern",
      "unzip report.xlsx",
      "unzip -p report.xlsx -d out",
      "gitleaks git --report-path out.json",
      "gitleaks git -r out.json",
      ""
    ].each do |command|
      it "blocks #{command.inspect}" do
        expect(run_hook("readonly_bash", { command: }).first).to eq(2)
      end
    end
  end
end
