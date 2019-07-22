require 'yaml'
require 'fileutils'
require 'set'

# @group Helpers

def repo_path
  `git rev-parse --show-toplevel`.strip
end

def self_path
  File.expand_path(File.dirname(__FILE__))
end

def relative_self_path
  File.dirname(__FILE__)
end

def copy_clang_format
  FileUtils.remove "#{repo_path}/.clang-format" if File.exist? "#{repo_path}/.clang-format"
  FileUtils.copy_entry("#{self_path}/.clang-format", "#{repo_path}/.clang-format", remove_destination: true)
end

def copy_swiftlint_file
  FileUtils.copy_entry("#{self_path}/.swiftlint.yml", "#{repo_path}/.swiftlint.yml", remove_destination: true)
end

# @group Interface

def exclude_test_folders_for_swiftlint
  require 'find'
  require 'pathname'
  test_folders = []
  repo_pathname = Pathname.new repo_path
  Find.find("#{repo_path}") do |dir|
    next unless File.directory? dir
    next unless dir.end_with?("test", "Test", "Tests", "tests")
    next if dir.include?("Pods")
    dir_pathname = Pathname.new dir
    relative_dir_pathname = dir_pathname.relative_path_from repo_pathname
    test_folders << relative_dir_pathname.to_s
  end

  swiftlint_config_path = "#{repo_path}/.swiftlint.yml"
  swiftlint_config_data = YAML.load(File.open(swiftlint_config_path))
  test_folders.each { |dir| swiftlint_config_data["excluded"].unshift dir }

  File.open(swiftlint_config_path, 'w') { |f| YAML.dump(swiftlint_config_data, f) }
end

def install_podfile_hooks
  podfile_path = "#{repo_path}/Podfile"
  unless File.file? podfile_path
    puts "Could not find Podfile, skipping it's update for configuration"
    return
  end

  script_lines = [
    "  installer.pods_project.targets.each do |target|",
    "    next unless target.name.include?(\"Pods-\")",
    "    next if (target.name.include?(\"Tests\") || target.name.include?(\"tests\"))",
    "    puts \"Updating \#{target.name}\"",
    "    target.build_configurations.each do |config|",
    "      xcconfig_path = config.base_configuration_reference.real_path",
    "      # read from xcconfig to build_settings dictionary",
    "      build_settings = Hash[*File.read(xcconfig_path).lines.map{|x| x.split(/\s*=\s*/, 2)}.flatten]",
    "      # write build_settings dictionary to xcconfig",
    "      File.open(xcconfig_path, \"w\") do |file|",
    "        file.puts \"#include \\\"../../../#{relative_self_path}/Configurations/Common.xcconfig\\\"\\n\"",
    "        build_settings.each do |key,value|",
    "          file.puts \"\#{key} = \#{value}\"",
    "        end",
    "      end",
    "    end",
    "  end"
  ]

  # First check is the desired hook is already set up
  existed_podfile_lines = []
  File.readlines(podfile_path).each do |line|
    existed_podfile_lines << line.chomp
  end

  # Stop method if the hook is already installed
  return if Set.new(script_lines).subset? Set.new(existed_podfile_lines)

  if File.foreach(podfile_path).grep(/post_install/).any?
    # There is already post_install hook in the podfile
    lines_to_install = []
    File.readlines(podfile_path).each do |line|
      lines_to_install << line
      lines_to_install += script_lines if line.include? "post_install do |installer|"
    end
    File.open(podfile_path, "w") do |file|
      lines_to_install.each do |line|
        file.puts line
      end
    end
  else
    # there is no post_install hook in the podfile yet
    lines_to_install = ["\n", "# Thanks http://stackoverflow.com/a/31804504/2487302", "post_install do |installer|"] +
                       script_lines +
                       ["end"]
    File.open(podfile_path, "a") do |file|
      lines_to_install.each do |line|
        file.puts line
      end
    end
  end
end

copy_clang_format
copy_swiftlint_file
exclude_test_folders_for_swiftlint
install_podfile_hooks
