require 'set'

module ImportFromTodoist
  class Importer
    def initialize(todoist_api_token, github_api_token, github_repo_name, no_cache)
      @todoist_api = ImportFromTodoist::Todoist::Api.new(todoist_api_token, no_cache: no_cache)
      github_repo_api = ImportFromTodoist::Github::Repo.new(github_repo_name, github_api_token)
      @system = ImportFromTodoist::System.new(@todoist_api, github_repo_api)
    end

    def sync(project_names_to_import)
      # This method describes the high-level operations that are being done to migrate the state in Todoist into GitHub.
      # It describes **what** is going to done, while all the details of **how** it is done are hidden elsewhere (in system.rb mostly).

      todoist_projects = todoist_api.projects(include_archived = true)
      projects_to_process = Set.new(todoist_projects.select { |project| project_names_to_import.include?(project.name) })
      projects_ids_to_process = projects_to_process.map(&:id)

      puts "Going to process Todoist Projects: #{projects_to_process.map(&:name).join(', ')}"

      puts 'Syncing Todoist tasks.'
      todoist_api.tasks(projects_ids_to_process).each do |task|
        issue = system.issue(task.id)

        # Associate an Issue with a Project by creating a project card for it
        system.sync_project_card(system.project(task.project_id), issue)
      end

      puts 'Syncing Todoist comments.'
      todoist_api.comments.each do |comment|
        next unless projects_ids_to_process.include?(comment.project_id)
        _comment = system.comment(system.issue(comment.task_id), comment) # TODO: Process comments in same order as they appear in Todoist
      end

      puts 'Syncing Todoist project comments.'
      todoist_api.project_comments.each do |comment|
        next unless projects_ids_to_process.include?(comment.project_id)
        _comment = system.project_comment(system.project(comment.project_id), comment) # TODO: Process comments in same order as they appear in Todoist
      end
    end

    private

    attr_reader :todoist_api
    attr_reader :system
  end
end
