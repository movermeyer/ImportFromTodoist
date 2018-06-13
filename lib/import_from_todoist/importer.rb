require 'set'

module ImportFromTodoist
  class Importer
    attr_reader :todoist_api
    attr_reader :system

    def initialize(todoist_api_token, github_api_token, github_repo_name, no_cache)
      @todoist_api = ImportFromTodoist::Todoist::Api.new(todoist_api_token, no_cache: no_cache)
      @system = ImportFromTodoist::System.new(todoist_api_token, github_api_token, github_repo_name, no_cache) # TODO: Clean up no_cache so it isn't called twice
    end

    def import(project_names_to_import)
      todoist_projects = todoist_api.projects(include_archived = true)
      projects_to_process = Set.new(todoist_projects.select { |project| project_names_to_import.include?(project.name) })
      projects_ids_to_process = projects_to_process.map(&:id)

      puts "Going to process Todoist Projects #{projects_ids_to_process.map { |i| i }}"

      # Create the matching issues
      todoist_api.tasks(projects_ids_to_process).each do |task|
        next unless projects_ids_to_process.include?(task.project_id)
        issue = system.issue(task.id)
        system.project_card(system.project(task.project_id), issue)
        #TODO: Remove the card from every other project.
      end

      todoist_api.comments.each do |comment|
        next unless projects_ids_to_process.include?(comment.project_id)
        # TODO: Add comments in same order
        # TODO: Convert Todoist emoji to GitHub emoji
        # TODO: Add reactions?
        # TODO: Handle attachments
        system.comment(system.issue(comment.task_id), comment)
      end

      todoist_api.project_comments.each do |comment|
        next unless projects_ids_to_process.include?(comment.project_id)
        # puts comment
        # TODO: Add comments in same order
        # TODO: Convert Todoist emoji to GitHub emoji
        # TODO: Add reactions?
        # TODO: Handle attachments
        system.project_comment(system.project(comment.project_id), comment)
      end
    end
  end
end
