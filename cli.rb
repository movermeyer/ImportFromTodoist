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

    opts.on('--repo user/repo', String, 'Which GitHub repo to import tasks into (ex. octocat/Hello-World).') do |repo|
      options[:repo] = repo
    end

    opts.on('--no-cache', TrueClass, 'Delete any caches prior to running') do |no_cache| # TODO: Remove along with caching?
      options[:no_cache] = no_cache
    end

    opts.on('--allow-public', TrueClass, 'Allow this program to import into public repos. Disallowed by default due to the risk of leaking sensitive information to the whole world.') do |allow_public|
      options[:allow_public] = allow_public
    end

    # TODO: Implement this.
    # opts.on('--sync-deletes', TrueClass, 'Synchronizes destructive changes to GitHub. Tries to make GitHub Issues a perfect mirror of Todoist state.') do |sync_deletes|
    #   options[:sync_deletes] = sync_deletes
    # end

    # TODO: Implement this.
    # opts.on('--dry-run', TrueClass, 'Analyzes the changes needed, and prints the changes out for review. Does not make any changes to GitHub.') do |dry_run|
    #   options[:dry_run] = dry_run
    # end

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

  github_repo_name = options[:repo]
  allow_public = options[:allow_public]

  github_repo = ImportFromTodoist::Github::Repo.new(github_repo_name, github_api_token)
  unless allow_public || github_repo.private?
    warn ''"You have asked to import Todoist data into the '#{github_repo_name}' GitHub repo, but that is a public repo.
Any data imported into that repo will be visible to the entire internet.
Given that Todoist often contains sensitive information (ex. Doctor appointments, names of collaborators, etc.), importing into public repos is disabled by default.
You can allow importing into public repos by running #{$PROGRAM_NAME} with the `--allow-public` flag.
"''
    exit(1)
  end

  ImportFromTodoist::Importer.new(todoist_api_token, github_api_token, github_repo_name, no_cache = options[:no_cache]).sync(options[:projects])
end
