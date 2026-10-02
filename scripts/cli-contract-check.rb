#!/usr/bin/env ruby
# All checks below are read-only with respect to Things. Local definitions use
# a disposable config directory so the maintainer's configuration is untouched.
require "json"
require "open3"
require "tmpdir"

binary = File.expand_path(ARGV.shift || ".build/debug/clings")
abort "Usage: cli-contract-check.rb [BINARY]" unless ARGV.empty?
metadata_output, error, status = Open3.capture3(binary, "--experimental-dump-help")
abort error unless status.success?
metadata = JSON.parse(metadata_output)
paths = []
walk = lambda do |command, parents|
  next if command["shouldDisplay"] == false
  path = parents + [command.fetch("commandName")]
  paths << path.drop(1)
  command.fetch("subcommands", []).each { |child| walk.call(child, path) }
end
walk.call(metadata.fetch("command"), [])
paths.each do |path|
  help, error, status = Open3.capture3(binary, *path, "--help")
  abort "Help failed for #{path.join(' ')}: #{error}" unless status.success? && help.include?("USAGE:") && help.include?("--help")
end
Dir.mktmpdir("clings-doc-examples") do |directory|
  environment = {"CLINGS_CONFIG_DIR" => File.join(directory, "config")}
  run = lambda do |arguments, success, expected_exit = (success ? 0 : 1)|
    output, error, status = Open3.capture3(environment, binary, *arguments)
    abort "Example unexpectedly #{status.success? ? 'passed' : 'failed'}: #{arguments.inspect}: #{error}" unless status.success? == success
    abort "Unexpected exit #{status.exitstatus}, wanted #{expected_exit}: #{arguments.inspect}" unless status.exitstatus == expected_exit
    if arguments.include?("--json")
      response = JSON.parse(output)
      abort "Invalid schema envelope: #{arguments.inspect}" unless response["schemaVersion"] == 1 && response["success"] == success && response.key?("data")
      abort "Failure missing actionable error: #{arguments.inspect}" if !success && (!response.dig("error", "code").is_a?(String) || !response.dig("error", "message").is_a?(String))
    end
    output
  end
  run.call(["add", "Draft guide tomorrow by friday #docs", "--parse-only", "--json"], true)
  run.call(["add", "Task", "--when", "2026-02-30", "--parse-only", "--json"], false)
  run.call(["add", "Task next friday 13pm", "--parse-only", "--json"], false)
  run.call(["unknown", "--json"], false)
  run.call(["add", "--json"], false)
  run.call(["pick", "complete", "--json"], false)
  run.call(["tags", "delete", "docs", "--json"], false)
  run.call(["filter", "broken !", "--json"], false)
  run.call(["focus", "--limit", "0", "--json"], false)
  run.call(["stats", "trends", "--weeks", "9223372036854775807", "--json"], false)
  run.call(["open", "today", "--json"], false, 2)
  run.call(["review", "status", "--json"], true)
  run.call(["review", "clear", "--json"], true)
  run.call(["template", "save", "docs-prep", "Prepare documentation tomorrow", "--tags", "docs", "--json"], true)
  run.call(["add", "Prepare guide", "--template", "docs-prep", "--parse-only", "--json"], true)
  run.call(["views", "save", "docs", "tags CONTAINS 'docs'", "--note", "Documentation queue", "--json"], true)
  run.call(["views", "list", "--json"], true)
  run.call(["template", "list", "--json"], true)
  run.call(["undo", "--show", "--json"], true)
  token_output = run.call(["config", "set-auth-token", "private-example-token", "--json"], true)
  abort "Config response leaked a token" if token_output.include?("private-example-token")
  run.call(["views", "delete", "docs", "--json"], true)
  run.call(["template", "delete", "docs-prep", "--json"], true)
  run.call(["views", "run", "missing", "--json"], false)
  help, error, status = Open3.capture3(environment, binary, "today", "--json", "--help")
  abort "Help must remain native text: #{error}" unless status.success? && help.include?("USAGE:") && !help.include?("\"success\"")
  literal, error, status = Open3.capture3(environment, binary, "add", "--parse-only", "--", "--json")
  abort "Literal --json positional argument activated JSON: #{error}" unless status.success? && literal.include?("Parsed Task")
  %w[bash zsh fish].each do |shell|
    script = run.call(["completions", shell], true)
    abort "Completion missing query options for #{shell}" unless script.include?("include-logbook")
    if %w[bash zsh].include?(shell)
      _output, error, status = Open3.capture3(shell, "-n", stdin_data: script)
      abort "Invalid #{shell} completion syntax: #{error}" unless status.success?
    end
  end
end
puts "CLI contracts: #{paths.length} help paths, safe examples, and generated completions passed"
