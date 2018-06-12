module ImportFromTodoist
  class Importer
    attr_reader :todoist_api
    attr_reader :github_repo

    def initialize(todoist_api_token, github_api_token, github_repo_name, no_cache)
      @todoist_api = ImportFromTodoist::Todoist::Api.new(todoist_api_token, no_cache: no_cache)
      @github_repo = ImportFromTodoist::Github::Repo.new(github_repo_name, github_api_token)
    end

    def import(project_names_to_import)
      todoist_project_to_github_project = process_projects(project_names_to_import)
      labels_to_process, due_dates = process_tasks(todoist_project_to_github_project)
      process_labels(labels_to_process)
      # process_milestones(due_dates)

      # TODO: Comments, Milestones, Priorities, connections between them all
      # Assignees, ordering within milestons and projects
      # Sync deletes.
    end

    private

    def diff_hashes(hash1, hash2)
      # Something like `{ a: 1 }.to_a & { a: 1, b: 2 }.to_a` or set difference, left_align
      # TODO: There is probably a better way to do this.
      differences = {}
      hash1.each do |key, value|
        differences[key] = value if hash2[key] != value
      end

      differences
    end

    def get_todist_id(description)
      match = description.match(/TODOIST_ID: (\d+)/)
      todist_id = match.captures.first.to_i if match
    end

    def process_projects(project_names_to_import)
      todoist_projects = todoist_api.projects(include_archived = true)
      projects_to_process = todoist_projects.select { |project| project_names_to_import.include?(project.name) }
      projects_to_process = projects_to_process.map { |project| { project.id => project } }.reduce { |acc, first| acc.merge(first) }

      puts "Found #{projects_to_process.length} Todoist projects to process."

      github_projects = github_repo.projects
      github_projects = github_projects.map { |project| { project.id => project } }.reduce { |acc, first| acc.merge(first) }

      puts "Found #{github_projects.length} GitHub projects in '#{github_repo.name}'."

      todoist_project_to_github_project = {}
      github_projects.each do |project_id, project|
        todist_id = get_todist_id(project.body)
        # puts "GitHub project '#{project['name']}' (#{project_id}) has a Todoist project ID of #{todist_id}"
        todoist_project_to_github_project[todist_id] = project_id if todist_id
      end

      puts todoist_project_to_github_project

      # Create missing projects
      projects_to_process.each do |todoist_project_id, todoist_project|
        puts "Checking for a GitHub project that matches Todoist Project '#{todoist_project['name']}' (#{todoist_project_id})"
        next if todoist_project_to_github_project.include? todoist_project_id
        new_github_project = github_repo.create_project(ImportFromTodoist::Github::Project.from_todoist_project(todoist_project))
        todoist_project_to_github_project[todoist_project_id] = new_github_project.id
        github_projects[new_github_project.id] = new_github_project
      end

      # Update projects
      projects_to_process.each do |todoist_project_id, todoist_project|
        puts "Checking for updates to Todoist Project '#{todoist_project['name']}' (#{todoist_project_id})"
        github_project_id = todoist_project_to_github_project[todoist_project_id]
        changes_needed = diff_hashes(ImportFromTodoist::Github::Project.from_todoist_project(todoist_project).mutable_value_hash, github_projects[github_project_id].mutable_value_hash)
        puts "Project changes needed: #{changes_needed}"
        github_repo.update_project(github_project_id, changes_needed)
      end

      # TODO: Delete projects that were previously imported, but no longer exist in Todoist?
      # Or maybe just update their descriptions?

      todoist_project_to_github_project
    end

    def process_tasks(todoist_project_to_github_project)
      todoist_tasks = todoist_api.tasks
      tasks_to_process = todoist_tasks.select { |task| todoist_project_to_github_project.include?(task.project_id) }
      tasks_to_process = tasks_to_process.map { |task| { task.id => task } }.reduce { |acc, first| acc.merge(first) } # TODO: Better way?

      puts "Found #{tasks_to_process.length} Todoist tasks to process."

      github_issues = github_repo.issues
      github_issues = github_issues.map { |project| { project.id => project } }.reduce { |acc, first| acc.merge(first) }

      puts "Found #{github_issues.length} GitHub issues in '#{github_repo.name}'."

      todoist_task_to_github_issue = {}
      github_issues.each do |_issue_id, issue|
        todist_id = get_todist_id(issue.body)
        todoist_task_to_github_issue[todist_id] = issue.id if todist_id
      end

      # TODO: Search for "GitLab"

      # Create issues missing from GitHub
      tasks_to_process.each do |todoist_task_id, todoist_task|
        puts "Checking for a GitHub issue that matches Todoist Task '#{todoist_task.content}' (#{todoist_task_id})"
        next if todoist_task_to_github_issue.include? todoist_task_id
        new_issue = github_repo.create_issue(ImportFromTodoist::GitHub::Issue.from_todoist(todoist_task))
        new_issue_id = new_issue.id
        todoist_task_to_github_issue[todoist_task_id] = new_issue_id
        github_issues[new_issue_id] = new_issue
      end

      # Update issues
      tasks_to_process.each do |todoist_task_id, todoist_task|
        puts "Checking for updates to Todoist Task '#{todoist_task['content']}' (#{todoist_task_id})"
        github_issue_id = todoist_task_to_github_issue[todoist_task_id]
        changes_needed = diff_hashes(ImportFromTodoist::Github::Issue.from_todoist_task(todoist_task).mutable_value_hash, github_issues[github_issue_id].mutable_value_hash)
        puts "Issue changes needed: #{changes_needed}"
        github_repo.update_issue(github_issues[github_issue_id].number, changes_needed) # GitHub doesn't allow for updating issues by id
      end

      labels_to_process = tasks_to_process.map { |_todoist_task_id, todoist_task| todoist_task.labels }.flatten
      due_dates = tasks_to_process.keep_if { |_todoist_task_id, todoist_task| todoist_task.due_on }.map { |_todoist_task_id, todoist_task| todoist_task.due_on }
      [labels_to_process, due_dates]
    end

    # TODO: Add "Dry run flag"
    # TODO: Add "sync deletes" flag
    # TODO: Add support for nested projects + issues

    def process_labels(labels_to_process)
      todoist_labels = todoist_api.labels
      labels_to_process = todoist_labels.select { |label| labels_to_process.include?(label.id) }

      # TODO: remove
      # labels_to_process = labels_to_process.map { |label| { label['name'] => label } }.reduce { |acc, first| acc.merge(first) } # TODO: Better way?
      # store = labels_to_process.reduce({}) do |hash, label|
      #   hash[label['name']] = label
      #   hash

      #   hash.tap { |hsh| hsh[label['name']] = label }
      # end
      labels_to_process = labels_to_process.each_with_object({}) do |label, hash|
        hash[label.name] = label
      end

      puts "Found #{labels_to_process.length} Todoist labels to process."

      github_labels = github_repo.labels
      github_labels = github_labels.map { |label| { label['name'] => label } }.reduce { |acc, first| acc.merge(first) }

      puts "Found #{github_labels.length} GitHub labels in '#{github_repo.name}'."

      # Create labels missing from GitHub
      labels_to_process.each do |todoist_label_name, todoist_label|
        puts "Checking for a GitHub label that matches Todoist label '#{todoist_label.name}' (#{todoist_label.id})"
        next if github_labels.include? todoist_label_name
        new_label = github_repo.create_label(ImportFromTodoist::Github::Label.from_todoist(todoist_label))
        github_labels[new_label.name] = new_label
      end

      # Update labels
      labels_to_process.each do |todoist_label_name, todoist_label|
        puts "Checking for updates to Todoist Label '#{todoist_label['name']}' (#{todoist_label['id']})"
        changes_needed = diff_hashes(ImportFromTodoist::Github::Label.from_todoist_label(todoist_label).mutable_value_hash, github_labels[todoist_label_name].mutable_value_hash)
        puts "Label changes needed: #{changes_needed}"
        github_repo.update_label(todoist_label_name, changes_needed) # GitHub doesn't allow for updating labels by id
      end
    end

    def process_milestones(due_dates)
      github_milestones = github_repo.milestones.map { |label| { label['title'] => label } }.reduce { |acc, first| acc.merge(first) }

      puts "Found #{github_milestones.length} GitHub labels in '#{github_repo.name}'."

      # Create labels missing from GitHub
      due_dates.each do |due_date|
        puts "Checking for a GitHub milestone that matches Todoist due date: #{due_date}"
        next if github_milestones.include? due_date
        new_milestone = github_repo.create_milestone(ImportFromTodoist::Github::Milestone.from_due_date(due_date))
        github_labels[new_label.name] = new_label
      end

      # Update labels
      labels_to_process.each do |todoist_label_name, todoist_label|
        puts "Checking for updates to Todoist Label '#{todoist_label['name']}' (#{todoist_label['id']})"
        changes_needed = diff_hashes(ImportFromTodoist::Github::Label.from_todoist_label(todoist_label).mutable_value_hash, github_labels[todoist_label_name].mutable_value_hash)
        puts "Label changes needed: #{changes_needed}"
        github_repo.update_label(todoist_label_name, changes_needed) # GitHub doesn't allow for updating labels by id
      end
    end
  end
end
