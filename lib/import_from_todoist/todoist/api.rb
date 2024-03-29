# frozen_string_literal: true

require 'fileutils'

module ImportFromTodoist
  module Todoist
    class Api
      TODOIST_SYNC_API_URL = 'https://todoist.com'
      TODOIST_REST_API_URL = 'https://beta.todoist.com'

      TODOIST_CACHE_DIR = '.todoist_cache'

      def initialize(api_token, cache_dir: TODOIST_CACHE_DIR, no_cache: false)
        @api_token = api_token
        @cache_dir = cache_dir
        FileUtils.rm_rf(@cache_dir) if no_cache
        Dir.mkdir @cache_dir unless File.exist?(@cache_dir)

        @projects_by_id = Hash[projects(include_archived: false).map { |project| [project.id, project] }]
        @labels_by_id = Hash[labels.map { |label| [label.id, label] }]
        @tasks_by_id = Hash[tasks.map { |task| [task.id, task] }]
        @collaborators_by_id = Hash[collaborators.map { |collaborator| [collaborator.id, collaborator] }]
      end

      def project(project_id)
        @projects_by_id[project_id]
      end

      def label(label_id)
        @labels_by_id[label_id]
      end

      def projects(include_archived: false)
        projects = get_from_todoist('projects')

        if include_archived
          # TODO: cache this fetch too?
          puts 'Fetching archived projects from Todoist'
          response = sync_api_connection.get '/api/v7/projects/get_archived', token: api_token
          # TODO: Error handling, see https://github.com/movermeyer/ImportFromTodoist/issues/22
          
          projects += JSON.parse(response.body)
        end

        projects = projects.map { |hash| ImportFromTodoist::Todoist::Project.from_todoist(hash) }
      end

      def task(task_id)
        @tasks_by_id[task_id]
      end

      def completed_tasks(project_ids: nil)
        project_ids ||= []
        results = []

        cache_file = File.join(@cache_dir, 'completed_tasks.json')

        if File.exist? cache_file
          open(cache_file, 'r') do |fin|
            results += JSON.parse(fin.read)
          end
        else
          if project_ids.empty? # TODO: Nicer logic
            response = sync_api_connection.get('/api/v7/completed/get_all', token: api_token)
            # TODO: Error handling, see https://github.com/movermeyer/ImportFromTodoist/issues/22
            results += JSON.parse(response.body)['items']
          else
            project_ids.each do |project_id|
              response = sync_api_connection.get('/api/v7/completed/get_all', token: api_token, project_id: project_id)
              # TODO: Error handling, see https://github.com/movermeyer/ImportFromTodoist/issues/22
              results += JSON.parse(response.body)['items']
            end
          end
          open(cache_file, 'w') do |fout|
            fout.write(JSON.dump(results))
          end
        end

        results
      end

      def tasks(project_ids: nil)
        # TODO: Move caching to caching layer. See https://github.com/movermeyer/ImportFromTodoist/issues/20
        cache_file = File.join(@cache_dir, 'tasks.json')

        results = []
        if File.exist? cache_file
          open(cache_file, 'r') do |fin|
            results = JSON.parse(fin.read).map { |hash| ImportFromTodoist::Todoist::Task.from_todoist(hash) }
          end
        else
          # In Sync API (v7), tasks are called 'items'
          #
          # TODO: Is there a way to filter sync requests by project_id server side?
          tasks = get_from_todoist('items')
          tasks += completed_tasks(project_ids: project_ids)

          # Getting the due date from the SYNC API (v7) is not easy. So we instead get it from the REST v8 API.
          # We can't just use the REST v8 API, since it doesn't expose all of the fields we need.
          response = rest_api_connection.get('/API/v8/tasks')
          # TODO: Error handling, see https://github.com/movermeyer/ImportFromTodoist/issues/22
          open(File.join(@cache_dir, 'tasks_rest_api.json'), 'w') do |fout|
            fout.write(JSON.dump(JSON.parse(response.body)))
          end

          due_dates = JSON.parse(response.body).each_with_object({}) do |task, hash|
            due = task.fetch('due', {})
            hash[task['id']] = due['datetime'] || due['date']
          end
          merged_hashes = tasks.map { |hash| hash.merge('due_on' => due_dates[hash.fetch('id')]) }
          open(cache_file, 'w') do |fout|
            fout.write(JSON.dump(merged_hashes))
          end
          results = merged_hashes.map { |hash| ImportFromTodoist::Todoist::Task.from_todoist(hash) }
        end
        project_ids ? results.select { |task| project_ids.include? task.project_id } : results
      end

      def project_comments(project_ids: nil)
        # In Sync API (v7), comments are called 'notes'
        #
        # While project_notes appear in the response for the "all" resource type,
        # the API doesn't understand "project_notes" as a resource type.
        # I never found a way to get the API to return just the "project_notes".
        # So we ask for everything and filter it on our side.
        #
        # TODO: Get attachments, see https://github.com/movermeyer/ImportFromTodoist/issues/4
        comments = get_from_todoist('all')['project_notes'].map { |hash| ImportFromTodoist::Todoist::Comment.from_todoist(hash) }
        project_ids ? comments.select { |comment| project_ids.include?(comment.project_id) } : comments
      end

      def comments(project_ids: nil)
        # In Sync API (v7), comments are called 'notes'
        #
        # TODO: Get attachments, see https://github.com/movermeyer/ImportFromTodoist/issues/4
        comments = get_from_todoist('notes').map { |hash| ImportFromTodoist::Todoist::Comment.from_todoist(hash) }
        project_ids ? comments.select { |comment| project_ids.include?(comment.project_id) } : comments
      end

      def collaborator(collaborator_id)
        @collaborators_by_id[collaborator_id]
      end

      def collaborators
        get_from_todoist('collaborators').map { |hash| ImportFromTodoist::Todoist::Collaborator.from_todoist(hash) }
      end

      private

      def labels
        get_from_todoist('labels').map { |hash| ImportFromTodoist::Todoist::Label.from_todoist(hash) }
      end

      attr_reader :api_token

      def connection(url)
        Faraday.new(url: url) do |faraday|
          faraday.adapter :net_http
          faraday.headers['Authorization'] = "Bearer #{api_token}"
        end
      end

      def sync_api_connection
        @sync_connection ||= connection(TODOIST_SYNC_API_URL)
      end

      def rest_api_connection
        @rest_connection ||= connection(TODOIST_REST_API_URL)
      end

      def get_from_todoist(resource_type)
        cache_file = File.join(@cache_dir, "#{resource_type}.json")

        if File.exist? cache_file
          puts "Fetching Todoist '#{resource_type}' from file cache"
          open(cache_file, 'r') do |fin|
            JSON.parse(fin.read)
          end
        else
          puts "Fetching #{resource_type} from Todoist"
          response = sync_api_connection.get '/api/v7/sync',
                                                     token: api_token,
                                                     sync_token: '*',
                                                     resource_types: JSON.dump([resource_type])
          # TODO: Error handling, see https://github.com/movermeyer/ImportFromTodoist/issues/22

          resources = JSON.parse(response.body)
          resources = resources[resource_type] if resource_type != 'all'
          open(cache_file, 'w') do |fout|
            fout.write(JSON.dump(resources))
          end
          resources
        end
      end
    end
  end
end
