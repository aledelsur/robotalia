require "spec_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# Runs the real script and commit guard in a throwaway git repository.
RSpec.describe "Privacy checks before a commit" do
  project = File.expand_path("../..", __dir__)
  script = File.join(project, "script/check_staged_privacy")
  guard = File.join(project, ".claude/hooks/guard_commit.sh")

  # Built at run time so that this file does not trip the check itself.
  let(:api_key) { [ "sk", "ant", "x" * 24 ].join("-") }
  let(:private_key) { "-----BEGIN #{'PRIVATE'} KEY-----\nabc\n" }

  around do |example|
    Dir.mktmpdir do |dir|
      @repo = dir
      git "init", "-q"
      git "config", "user.email", "test@example.com"
      git "config", "user.name", "Test"
      example.run
    end
  end

  def git(*command)
    output, status = Open3.capture2e("git", *command, chdir: @repo)
    raise output unless status.success?
  end

  def write(path, content = "puts 1\n")
    file = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, content)
  end

  def stage(path, content = "puts 1\n")
    write(path, content)
    git "add", "-f", path
  end

  describe "script/check_staged_privacy" do
    define_method(:check) do |*options|
      _, error, status = Open3.capture3(script, *options, chdir: @repo)
      [ status.exitstatus, error ]
    end

    it "passes ordinary files, the env examples and synthetic fixtures" do
      %w[app/models/trade.rb .env.example .env.deploy.example spec/fixtures/files/sample.xlsx
         public/404.html app/views/accounts/show.html.erb config/credentials.yml.enc].each { stage(_1) }

      expect(check).to eq([ 0, "" ])
    end

    %w[private/report.xlsx .env .env.deploy config/master.key config/credentials/production.key
       server.pem strategy.pine report.xlsx docs/History.html data/bars.csv].each do |path|
      it "blocks #{path}" do
        stage(path)

        status, error = check
        expect(status).to eq(2)
        expect(error).to include(path)
      end
    end

    it "blocks API keys and private keys in any file" do
      stage("notes.md", "key: #{api_key}\n")
      stage("deploy.txt", private_key)

      status, error = check
      expect(status).to eq(2)
      expect(error).to include("notes.md: contains an Anthropic API key", "deploy.txt: contains a private key")
      expect(error).not_to include(api_key)
    end

    it "blocks values copied from the ignored env files, without printing them" do
      write(".env.deploy", "ROBOTALIA_DATABASE_PASSWORD=\"s3cret-database-value\"\n")
      stage("config/database.yml", "password: s3cret-database-value\n")

      status, error = check
      expect(status).to eq(2)
      expect(error).to include("the value of ROBOTALIA_DATABASE_PASSWORD")
      expect(error).not_to include("s3cret-database-value")
    end

    it "reads the staged content, not the later working copy" do
      stage("notes.md", api_key)
      write("notes.md", "clean\n")

      expect(check.first).to eq(2)
    end

    it "allows deleting a forbidden file" do
      stage("report.xlsx")
      git "commit", "-qm", "add"
      git "rm", "-q", "report.xlsx"

      expect(check.first).to eq(0)
    end

    it "checks unstaged changes only when the commit would include them" do
      stage("notes.md", "clean\n")
      git "commit", "-qm", "add"
      write("notes.md", api_key)

      expect(check.first).to eq(0)
      expect(check("--all").first).to eq(2)
    end

    it "checks untracked files only when the command would add them" do
      write("private/report.xlsx")

      expect(check.first).to eq(0)
      expect(check("--untracked").first).to eq(2)
    end

    it "blocks the commit when it cannot run" do
      Dir.mktmpdir do |outside|
        _, _, status = Open3.capture3({ "GIT_CEILING_DIRECTORIES" => File.dirname(outside) }, script, chdir: outside)
        expect(status.exitstatus).to eq(2)
      end
    end
  end

  describe ".claude/hooks/guard_commit.sh" do
    before do
      FileUtils.mkdir_p(File.join(@repo, "script"))
      FileUtils.cp(script, File.join(@repo, "script"))
    end

    define_method(:run_guard) do |command|
      input = JSON.generate(tool_name: "Bash", tool_input: { command: })
      Open3.capture3({ "CLAUDE_PROJECT_DIR" => @repo }, guard, stdin_data: input).last.exitstatus
    end

    it "ignores other commands" do
      stage("private/report.xlsx")

      expect(run_guard("git status")).to eq(0)
      expect(run_guard("bundle exec rspec")).to eq(0)
    end

    it "blocks a commit with a forbidden file staged" do
      stage("private/report.xlsx")

      expect(run_guard("git commit -m 'Add report'")).to eq(2)
      expect(run_guard("cd . && git -c core.pager=cat commit -m x")).to eq(2)
    end

    it "checks files that the same command adds" do
      write("private/report.xlsx")

      expect(run_guard("git add -A && git commit -m x")).to eq(2)
    end

    it "checks unstaged changes for git commit -am" do
      stage("notes.md", "clean\n")
      git "commit", "-qm", "add"
      write("notes.md", api_key)

      expect(run_guard("git commit -am x")).to eq(2)
    end

    it "refuses to force-add private files" do
      expect(run_guard("git add -f private/report.xlsx")).to eq(2)
      expect(run_guard("git add --force .env")).to eq(2)
      expect(run_guard("git add app/models/trade.rb")).to eq(0)
    end
  end
end
