require 'faraday'
require 'multi_json'
require 'optparse'
require 'set'

TODOIST_DATA_DIR = 'todoist_data'.freeze
TODOIST_PROJECT_DATA = File.join(TODOIST_DATA_DIR, 'projects.json')
TODOIST_TASK_DATA = File.join(TODOIST_DATA_DIR, 'tasks.json')
TODOIST_ALL_DATA = File.join(TODOIST_DATA_DIR, 'all.json')

TODOIST_SYNC_API_URL = 'https://todoist.com'.freeze
TODOIST_REST_API_URL = 'https://beta.todoist.com'.freeze

GITHUB_API_URL = 'https://api.github.com'.freeze
GITHUB_API_VERSION = { 'Accept' => 'application/vnd.github.v3+json, application/vnd.github.inertia-preview+json' }.freeze

SYNC_MAX_POST_BODY_LIMIT = 1024 * 1024 # 1 MiB
SYNC_MAX_HEADER_LIMIT = 64 * 1024 # 64 KiB
SYNC_COMMANDS_PER_MINUTE = 100
SYNC_REQUESTS_PER_MINUTE = 50

TODOIST_COLORS = %w[
  019412
  a39d01
  e73d02
  e702a4
  9902e7
  1d02e7
  0082c5
  555555
  008299
  03b3b2
  ac193d
  82ba00
  111111
].freeze


def diff_hashes(hash1, hash2)
  #TODO: There is probably a better way to do this.
  differences = {}
  hash1.each do |key, value|
    if hash2[key] != value
      differences[key] = value 
    end
  end

  differences
end

def create_github_project_column(project_id, name, github_api_token)
  conn = Faraday.new(url: GITHUB_API_URL)

  body = {
    'name' => name
  }

  github_response = conn.post do |req|
    req.url "/projects/#{project_id}/columns"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers = req.headers.merge(GITHUB_API_VERSION)
    req.body = MultiJson.dump(body)
  end

  MultiJson.load(github_response.body)
end

def create_github_project_json(todoist_project)
  {
    'name' => todoist_project['name'],
    'body' => generate_github_description('', todoist_project['id'])
    'state' => todoist_project['is_deleted'] == 1 || todoist_project['is_archived'] == 1 ? 'closed' : 'open'
  }
end

def create_github_project(repo, github_api_token, todoist_project)
  puts "Creating new GitHub Project: #{todoist_project['name']}"

  conn = Faraday.new(url: GITHUB_API_URL)

  body = {
    'name' => todoist_project['name'],
    'body' => generate_github_description('', todoist_project['id'])
  }

  github_response = conn.post do |req|
    req.url "/repos/#{repo}/projects"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers = req.headers.merge(GITHUB_API_VERSION)
    req.body = MultiJson.dump(body)
  end

  project_json = MultiJson.load(github_response.body)
  project_id = project_json['id']

  create_github_project_column(project_id, 'To do', github_api_token)

  project_json
end

def get_todist_id(description)
  match = description.match(/TODOIST_ID: (\d+)/)
  todist_id = match.captures.first.to_i if match
end

def generate_github_description(description, todoist_id)
  # Generates a description that includes a GitHub Markdown comment (ie.
  # hack, see https://stackoverflow.com/a/20885980/6460914). That way, the
  # Todoist id can be embedded for easy cross-referencing in future runs.
  ''"#{description}

[//]: # (Warning: DO NOT DELETE!)
[//]: # (The below comment is important for making Todoist imports work. For more details, see TODO: Add URL)
[//]: # (TODOIST_ID: #{todoist_id})
  "''
end

def update_project(github_project_id, changes_needed, github_api_token)
  return if changes_needed.empty?

  conn = Faraday.new(url: GITHUB_API_URL)

  github_response = conn.patch do |req|
    req.url "/projects/#{github_project_id}"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers = req.headers.merge(GITHUB_API_VERSION)
    req.body = MultiJson.dump(changes_needed)
  end

  MultiJson.load(github_response.body)
end

def diff_project(todoist_project, github_project)
  changes_needed = {}

  # Project's name may have changed
  changes_needed['name'] = todoist_project['name'] if todoist_project['name'] != github_project['name']

  # Project may have been deleted/archived/unarchived
  state = todoist_project['is_deleted'] == 1 || todoist_project['is_archived'] == 1 ? 'closed' : 'open'
  changes_needed['state'] = state if state != github_project['state']

  changes_needed
end

def get_milestones_from_repo(repo, github_api_token)
  conn = Faraday.new(url: GITHUB_API_URL)

  github_response = conn.get do |req|
    req.url "/repos/#{repo}/milestones"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers.merge(GITHUB_API_VERSION)
  end

  puts github_response.status, github_response.body
end

def get_projects_from_repo(repo, github_api_token)
  conn = Faraday.new(url: GITHUB_API_URL)

  # TODO: Remove. It was for Fiddler debugging
  # conn = Faraday.new(url: GITHUB_API_URL, proxy: 'http://127.0.0.1:8888') do |f|
  #   f.adapter :net_http do |http| # yields Net::HTTP
  #     http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  #   end
  # end

  github_response = conn.get do |req|
    req.url "/repos/#{repo}/projects"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers = req.headers.merge(GITHUB_API_VERSION)
    req.params['state'] = 'all'
  end

  MultiJson.load(github_response.body)
end

def get_issues_from_repo(repo, github_api_token)
  conn = Faraday.new(url: GITHUB_API_URL)

  github_response = conn.get do |req|
    req.url "/repos/#{repo}/issues"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers.merge(GITHUB_API_VERSION)
  end

  MultiJson.load(github_response.body)
end

def get_everything_from_todoist(todoist_api_token)
  puts 'Fetching everything from Todoist'

  conn = Faraday.new(url: TODOIST_SYNC_API_URL)
  todoist_response = conn.get '/api/v7/sync',
                              token: todoist_api_token,
                              sync_token: '*',
                              resource_types: '["all"]'
  # TODO: Error handling
  open(TODOIST_ALL_DATA, 'w') do |output|
    output.write(todoist_response.body)
  end
end

def get_projects_from_todoist(todoist_api_token, include_archived = false)
  projects = get_from_todoist(todoist_api_token, 'projects')

  if include_archived
    puts 'Fetching archived projects from Todoist'
    conn = Faraday.new(url: TODOIST_SYNC_API_URL)
    todoist_response = conn.get '/api/v7/projects/get_archived', # TODO: Should be made into POST request, as per https://developer.todoist.com/sync/v7/#sync
                                token: todoist_api_token
    # TODO: Error handling
    projects += MultiJson.load(todoist_response.body)
  end

  projects
end

def get_from_todoist(todoist_api_token, resource_type)
  puts "Fetching #{resource_type} from Todoist"

  conn = Faraday.new(url: TODOIST_SYNC_API_URL)
  todoist_response = conn.get '/api/v7/sync', # TODO: Should be made into POST request, as per https://developer.todoist.com/sync/v7/#sync
                              token: todoist_api_token,
                              sync_token: '*',
                              resource_types: MultiJson.dump([resource_type])
  # TODO: Error handling
  MultiJson.load(todoist_response.body)[resource_type]
end

def get_todoist_projects(todoist_api_token)
  # TODO: Remove. This was only an optimization during development in order to avoid hitting Todoist too much.

  unless File.exist?(TODOIST_PROJECT_DATA)
    projects = get_projects_from_todoist(todoist_api_token, include_archived = true)
    open(TODOIST_PROJECT_DATA, 'w') do |output|
      output.write(MultiJson.dump(projects))
    end
  end

  projects = nil
  open(TODOIST_PROJECT_DATA, 'r') do |input|
    projects = MultiJson.load(input.read)
  end

  projects
end

def process_projects(project_names_to_import, github_repo, todoist_api_token, github_api_token)
  todoist_projects = get_todoist_projects(todoist_api_token)
  projects_to_process = todoist_projects.select { |project| project_names_to_import.include?(project['name']) }
  projects_to_process = projects_to_process.map { |project| { project['id'] => project } }.reduce { |acc, first| acc.merge(first) }

  puts "Found #{projects_to_process.length} Todoist projects to process."

  github_projects = get_projects_from_repo(github_repo, github_api_token)
  github_projects = github_projects.map { |project| { project['id'] => project } }.reduce { |acc, first| acc.merge(first) }

  puts "Found #{github_projects.length} GitHub projects in '#{github_repo}'."

  todoist_project_to_github_project = {}
  github_projects.each do |_project_id, project|
    todist_id = get_todist_id(project['body'])
    # puts "GitHub project '#{project['name']}' (#{project_id}) has a Todoist project ID of #{todist_id}"
    todoist_project_to_github_project[todist_id] = project['id'] if todist_id
  end

  # Create missing projects
  projects_to_process.each do |todoist_project_id, todoist_project|
    puts "Checking for a GitHub project that matches Todoist Project '#{todoist_project['name']}' (#{todoist_project_id})"
    next if todoist_project_to_github_project.include? todoist_project_id
    new_project_json = create_github_project(github_repo, github_api_token, todoist_project)
    new_project_id = new_project_json['id']
    todoist_project_to_github_project[todoist_project_id] = new_project_id
    github_projects[new_project_id] = new_project_json
  end

  # Update projects
  projects_to_process.each do |todoist_project_id, todoist_project|
    puts "Checking for updates to Todoist Project '#{todoist_project['name']}' (#{todoist_project_id})"
    github_project_id = todoist_project_to_github_project[todoist_project_id]
    changes_needed = diff_project(todoist_project, github_projects[github_project_id])
    puts "Project changes needed: #{changes_needed}"
    update_project(github_project_id, changes_needed, github_api_token)
  end

  # TODO: Delete projects that were previously imported, but no longer exist in Todoist?
  # Or maybe just update their descriptions?

  todoist_project_to_github_project
end

def get_todoist_resources(todoist_api_token, resource_type)
  # TODO: Remove. This was only an optimization during development in order to avoid hitting Todoist too much.
  cache_file = File.join(TODOIST_DATA_DIR, "#{resource_type}.json")
  unless File.exist?(cache_file)
    resources = get_from_todoist(todoist_api_token, resource_type)
    open(cache_file, 'w') do |output|
      output.write(MultiJson.dump(resources))
    end
  end

  resources = nil
  open(cache_file, 'r') do |input|
    resources = MultiJson.load(input.read)
  end

  resources
end

def create_github_issue(repo, github_api_token, todoist_task)
  puts "Creating new GitHub Issue: #{todoist_task['content']}"

  conn = Faraday.new(url: GITHUB_API_URL)

  body = {
    'title' => todoist_task['content'],
    'body' => generate_github_description('', todoist_task['id']), # TODO: Add Todoist task creation date.
    # 'assignees' #TODO:
    # 'milestone' #TODO:
    # 'labels' => #TODO:
  }

  github_response = conn.post do |req|
    req.url "/repos/#{repo}/issues"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers = req.headers.merge(GITHUB_API_VERSION)
    req.body = MultiJson.dump(body)
  end

  MultiJson.load(github_response.body)
end

def process_tasks(todoist_project_to_github_project, github_repo, todoist_api_token, github_api_token)
  todoist_tasks = get_todoist_resources(todoist_api_token, 'items') # In Todoist API v7, tasks are called items
  tasks_to_process = todoist_tasks.select { |task| todoist_project_to_github_project.include?(task['project_id']) }
  tasks_to_process = tasks_to_process.map { |task| { task['id'] => task } }.reduce { |acc, first| acc.merge(first) } # TODO: Better way?

  puts "Found #{tasks_to_process.length} Todoist tasks to process."

  github_issues = get_issues_from_repo(github_repo, github_api_token)
  github_issues = github_issues.map { |project| { project['id'] => project } }.reduce { |acc, first| acc.merge(first) }

  puts "Found #{github_issues.length} GitHub issues in '#{github_repo}'."

  todoist_task_to_github_issue = {}
  github_issues.each do |_issue_id, issue|
    todist_id = get_todist_id(issue['body'])
    todoist_task_to_github_issue[todist_id] = issue['id'] if todist_id
  end

  # TODO: Search for "GitLab"

  # Create issues missing from GitHub
  tasks_to_process.each do |todoist_task_id, todoist_task|
    puts "Checking for a GitHub issue that matches Todoist Task '#{todoist_task['content']}' (#{todoist_task_id})"
    next if todoist_task_to_github_issue.include? todoist_task_id
    new_issue_json = create_github_issue(github_repo, github_api_token, todoist_task)
    new_issue_id = new_issue_json['id']
    todoist_task_to_github_issue[todoist_task_id] = new_issue_id
    github_issues[new_issue_id] = new_issue_json
  end

  labels_to_process = tasks_to_process.map { |_todoist_task_id, todoist_task| todoist_task['labels'] }.flatten
  labels_to_process
end

# TODO: Add "Dry run flag"
# TODO: Add "sync deletes" flag
# TODO: Add support for nested projects + issues

def create_github_label_json(todoist_label)
  {
    'name' => todoist_label['name'], # TODO: Error handling while missing fields (ie. no nils allowed)
    'color' => TODOIST_COLORS[todoist_label['color']] # TODO: Error handling for unknown colors
  }
end

def create_github_label(repo, github_api_token, todoist_label)
  puts "Creating new GitHub Label: #{todoist_label['name']}"

  conn = Faraday.new(url: GITHUB_API_URL)

  github_response = conn.post do |req|
    req.url "/repos/#{repo}/labels"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers = req.headers.merge(GITHUB_API_VERSION)
    req.body = MultiJson.dump(create_github_label_json(todoist_label))
  end

  MultiJson.load(github_response.body)
end

def update_label(github_repo, github_label_name, changes_needed, github_api_token)
  return if changes_needed.empty?

  conn = Faraday.new(url: GITHUB_API_URL)

  github_response = conn.patch do |req|
    req.url "/repos/#{github_repo}/labels/#{github_label_name}"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers = req.headers.merge(GITHUB_API_VERSION)
    req.body = MultiJson.dump(changes_needed)
  end

  MultiJson.load(github_response.body)
end

def get_labels_from_repo(repo, github_api_token)
  conn = Faraday.new(url: GITHUB_API_URL)

  github_response = conn.get do |req|
    req.url "/repos/#{repo}/labels"
    req.headers['Authorization'] = "token #{github_api_token}"
    req.headers.merge(GITHUB_API_VERSION)
  end

  MultiJson.load(github_response.body)
end

def process_labels(labels_to_process, github_repo, todoist_api_token, github_api_token)
  todoist_labels = get_todoist_resources(todoist_api_token, 'labels')
  labels_to_process = todoist_labels.select { |label| labels_to_process.include?(label['id']) } # TODO: What is the return type if none are selected?
  labels_to_process = labels_to_process.map { |label| { label['name'] => label } }.reduce { |acc, first| acc.merge(first) } # TODO: Better way?

  puts "Found #{labels_to_process.length} Todoist labels to process."

  github_labels = get_labels_from_repo(github_repo, github_api_token)
  github_labels = github_labels.map { |label| { label['name'] => label } }.reduce { |acc, first| acc.merge(first) }

  puts "Found #{github_labels.length} GitHub labels in '#{github_repo}'."

  # Create labels missing from GitHub
  labels_to_process.each do |todoist_label_name, todoist_label|
    puts "Checking for a GitHub label that matches Todoist label '#{todoist_label['name']}' (#{todoist_label['id']})"
    next if github_labels.include? todoist_label_name
    new_label_json = create_github_label(github_repo, github_api_token, todoist_label)
    new_label_name = new_label_json['name']
    github_labels[new_label_name] = new_label_json
  end

  # Update labels
  labels_to_process.each do |todoist_label_name, todoist_label|
    puts "Checking for updates to Todoist Label '#{todoist_label['name']}' (#{todoist_label['id']})"
    changes_needed = diff_hashes(create_github_label_json(todoist_label), github_labels[todoist_label_name])
    puts "Label changes needed: #{changes_needed}"
    update_label(github_repo, todoist_label_name, changes_needed, github_api_token) # GitHub doesn't allow for updating labels by id
  end
end

def main(project_names_to_import, github_repo)
  Dir.mkdir TODOIST_DATA_DIR unless File.exist?(TODOIST_DATA_DIR)

  todoist_api_token = nil
  open('.todoist_api_token', 'r') do |input|
    todoist_api_token = input.read.chomp
  end

  github_api_token = nil
  open('.github_auth_token', 'r') do |input|
    github_api_token = input.read.chomp
  end

  todoist_project_to_github_project = process_projects(project_names_to_import, github_repo, todoist_api_token, github_api_token)
  labels_to_process = process_tasks(todoist_project_to_github_project, github_repo, todoist_api_token, github_api_token)
  process_labels(labels_to_process, github_repo, todoist_api_token, github_api_token)

  # tasks_json.each do |task|
  #   puts task['content'] if projects_to_process.include? task['project_id']
  # end

  # github_issues = get_issues_from_repo(repo, github_api_token)

  # Add or update comments to projects

  # TODO: Delete projects that were previously imported, but no longer exist in Todoist?
  # Note that this is really a sync feature, and not an import feature.

  # Create missing Milestones

  # Create or update tasks

  # Associate Tasks to Projects
  # TODO: Can you associate an issue with a closed project/milestone through the API?
  # Associate Tasks to Milestones

  # Close any milestones that are ours, but have no issues
  # TODO: Or all the issues are also closed?
  # Note that this is really a sync feature, and not an import feature.
end

if $PROGRAM_NAME == __FILE__
  options = { projects: Set.new }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

    opts.on('--projects x,y,z', Array, 'Which Todoist projects to import tasks from.') do |list|
      options[:projects] = list.to_set
    end

    opts.on('--repo user/repo', String, 'Which GitHub repo to import tasks into (ex. movermeyer/TestRepo).') do |repo|
      options[:repo] = repo
    end

    opts.on('-h', '--help', 'Prints this help') do
      puts opts
      exit
    end
  end.parse!
  main(options[:projects], options[:repo])
end
