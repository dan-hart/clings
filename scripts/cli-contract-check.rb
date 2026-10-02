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
  run = lambda do |arguments, success|
    output, error, status = Open3.capture3(environment, binary, *arguments)
    abort "Example unexpectedly #{status.success? ? 'passed' : 'failed'}: #{arguments.inspect}: #{error}" unless status.success? == success
    if arguments.include?("--json")
      response = JSON.parse(output)
      abort "Invalid schema envelope: #{arguments.inspect}" unless response["schemaVersion"] == 1 && response["success"] == success && response.key?("data")
      abort "Failure missing actionable error: #{arguments.inspect}" if !success && (!response.dig("error", "code").is_a?(String) || !response.dig("error", "message").is_a?(String))
      abort "Invalid-input example must exit 1: #{arguments.inspect}" if !success && status.exitstatus != 1
    end
    output
  end
  run.call(["add", "Draft guide tomorrow by friday #docs", "--parse-only", "--json"], true)
  run.call(["add", "Task", "--when", "2026-02-30", "--parse-only", "--json"], false)
  run.call(["add", "Task next friday 13pm", "--parse-only", "--json"], false)
  run.call(["template", "save", "docs-prep", "Prepare documentation tomorrow", "--tags", "docs"], true)
  run.call(["add", "Prepare guide", "--template", "docs-prep", "--parse-only", "--json"], true)
  run.call(["views", "save", "docs", "tags CONTAINS 'docs'", "--note", "Documentation queue"], true)
  run.call(["views", "list", "--json"], true)
  run.call(["template", "list", "--json"], true)
  run.call(["undo", "--show", "--json"], true)
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
