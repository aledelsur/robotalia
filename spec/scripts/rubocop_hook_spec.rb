require "spec_helper"
require "json"
require "open3"
require "tempfile"

RSpec.describe "Claude Code RuboCop hook" do
  project = File.expand_path("../..", __dir__)

  define_method(:run_hook) do |name, tool_input|
    _, error, status = Open3.capture3({ "CLAUDE_PROJECT_DIR" => project }, File.join(project, ".claude/hooks", name),
                                      stdin_data: JSON.generate(tool_input:))
    [ status.exitstatus, error ]
  end

  describe "rubocop_edited.sh" do
    def lint(source, directory:, suffix: ".rb")
      Tempfile.create([ "hook_example", suffix ], directory) do |file|
        file.write(source)
        file.flush
        run_hook("rubocop_edited.sh", { file_path: file.path })
      end
    end

    it "passes a clean file" do
      expect(lint("puts [ 1 ]\n", directory: File.join(project, "tmp"))).to eq([ 0, "" ])
    end

    it "reports offenses to Claude" do
      status, error = lint("puts [1]   \n", directory: File.join(project, "spec"))

      expect(status).to eq(2)
      expect(error).to include("RuboCop found problems", "Layout/")
    end

    it "ignores other file types and files outside the project" do
      expect(lint("[1]   \n", directory: File.join(project, "spec"), suffix: ".md").first).to eq(0)
      expect(run_hook("rubocop_edited.sh", { file_path: "/tmp/outside.rb" }).first).to eq(0)
    end
  end
end
