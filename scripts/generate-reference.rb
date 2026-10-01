#!/usr/bin/env ruby
# Generated documentation uses the pinned ArgumentParser metadata schema.
require "json"
require "open3"

binary = ARGV.shift || ".build/debug/clings"
mode = ARGV.shift || "--check"
abort "Usage: generate-reference.rb BINARY [--check|--write|--stdout]" unless ARGV.empty? && %w[--check --write --stdout].include?(mode)
output, error, status = Open3.capture3(binary, "--experimental-dump-help")
abort "Could not read command metadata: #{error}" unless status.success?
metadata = JSON.parse(output)
abort "Unsupported ArgumentParser metadata schema" unless metadata["serializationVersion"] == 0

commands = []
walk = lambda do |command, parents|
  next if command["shouldDisplay"] == false
  path = parents + [command.fetch("commandName")]
  commands << [path, command]
  command.fetch("subcommands", []).each { |child| walk.call(child, path) }
end
walk.call(metadata.fetch("command"), [])
escape = ->(text) { text.to_s.gsub("|", "\\|").gsub(/\s+/, " ").strip }
lines = ["# Generated command reference", "", "Generated from ArgumentParser's command tree. Do not edit by hand.", "Run `ruby scripts/generate-reference.rb .build/debug/clings --write` after changing help or arguments.", "Narrative recipes live in [the command guide](command-reference.md).", ""]
commands.each do |path, command|
  lines += ["## `#{path.join(' ')}`", "", escape.call(command["abstract"]), ""]
  aliases = command.fetch("aliases", [])
  lines += ["Aliases: #{aliases.map { |name| "`#{name}`" }.join(', ')}.", ""] unless aliases.empty?
  arguments = command.fetch("arguments", []).reject { |argument| argument["shouldDisplay"] == false }
  unless arguments.empty?
    lines += ["| Argument | Description |", "| --- | --- |"]
    arguments.each do |argument|
      names = argument.fetch("names", []).map do |name|
        prefix = name["kind"] == "long" ? "--" : "-"
        "#{prefix}#{name.fetch('name')}"
      end
      label = names.empty? ? "<#{argument.fetch('valueName', 'value')}>" : names.join(", ")
      label += " <#{argument['valueName']}>" if argument["kind"] == "option"
      label += "..." if argument["isRepeating"]
      lines << "| `#{escape.call(label)}` | #{escape.call(argument['abstract'])} |"
    end
    lines << ""
  end
end
rendered = lines.join("\n") + "\n"
target = File.expand_path("../docs/cli/generated-reference.md", __dir__)
case mode
when "--write" then File.write(target, rendered)
when "--stdout" then puts rendered
when "--check"
  abort "Generated reference is stale; regenerate and commit it" unless File.exist?(target) && File.read(target) == rendered
end
warn "Command reference: #{commands.length} command paths verified" unless mode == "--stdout"
