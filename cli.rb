require 'optparse'
require 'set'

require_relative 'lib/import_from_todoist'

if $PROGRAM_NAME == __FILE__
  options = { projects: Set.new }

  OptionParser.new do |opts|
    opts.banner = ''"Import Todoist Tasks into GitHub Issues.
Usage: #{$PROGRAM_NAME} [options]
"''

    opts.on('--projects x,y,z', Array, 'Which Todoist projects to import tasks from.') do |list|
      options[:projects] = list.to_set
    end

    opts.on('--repo user/repo', String, 'Which GitHub repo to import tasks into (ex. movermeyer/TestRepo).') do |repo|
      options[:repo] = repo
    end

    opts.on('--no-cache', TrueClass, 'Delete any caches prior to running') do |no_cache| # TODO: Remove along with caching?
      options[:no_cache] = no_cache
    end

    opts.on('-h', '--help', 'Prints this help') do
      puts opts
      exit
    end
  end.parse!

  todoist_api_token = nil
  open('.todoist_api_token', 'r') do |input|
    todoist_api_token = input.read.chomp
  end

  github_api_token = nil
  open('.github_auth_token', 'r') do |input|
    github_api_token = input.read.chomp
  end

  ImportFromTodoist::Importer.new(todoist_api_token, github_api_token, options[:repo], no_cache = options[:no_cache]).import(options[:projects])
end
