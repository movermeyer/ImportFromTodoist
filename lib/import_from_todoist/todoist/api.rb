require 'fileutils'

module ImportFromTodoist
  module Todoist
    class Api
      TODOIST_SYNC_API_URL = 'https://todoist.com'.freeze
      TODOIST_REST_API_URL = 'https://beta.todoist.com'.freeze

      TODOIST_CACHE_DIR = '.todoist_cache'.freeze

      def initialize(api_token, cache_dir: TODOIST_CACHE_DIR, no_cache: false)
        @api_token = api_token
        @cache_dir = cache_dir
        FileUtils.rm_rf(@cache_dir) if no_cache
        Dir.mkdir @cache_dir unless File.exist?(@cache_dir)
      end

      def tasks
        results = get_from_todoist('items')

        # Getting the due date from the SYNC API (v7) is not easy. So we instead get it from the REST v8 API.
        # We can't just use the REST v8 API, since it doesn't expose all of the fields we need.
        # TODO: Consider not pulling down every task.
        # TODO: Consider removing caching.
        cache_file = File.join(@cache_dir, 'tasks.json')

        if File.exist? cache_file
          open(cache_file, 'r') do |fin|
            JSON.parse(fin.read).map { |hash| ImportFromTodoist::Todoist::Task.from_todoist(hash) }
          end
        else
          todoist_response = rest_api_connection.get('/API/v8/tasks')
          due_dates = JSON.parse(todoist_response.body).each_with_object({}) do |task, hash|
            hash[task['id']] = task.fetch('due', {})['date']
          end
          merged_hashes = results.map { |hash| hash.merge('due_on' => due_dates[hash.fetch('id')]) }
          open(cache_file, 'w') do |fout|
            fout.write(JSON.dump(merged_hashes))
          end
          merged_hashes.map { |hash| ImportFromTodoist::Todoist::Task.from_todoist(hash) }
        end
      end

      def labels
        get_from_todoist('labels').map { |hash| ImportFromTodoist::Todoist::Label.from_todoist(hash) }
      end

      def projects(include_archived = false)
        projects = get_from_todoist('projects')

        if include_archived
          # TODO: cache this fetch too?
          puts 'Fetching archived projects from Todoist'
          todoist_response = sync_api_connection.get '/api/v7/projects/get_archived', token: api_token

          # TODO: Error handling
          projects += JSON.parse(todoist_response.body)
        end

        projects.map { |hash| ImportFromTodoist::Todoist::Project.from_todoist(hash) }
      end

      private

      attr_reader :api_token

      def sync_api_connection
        # @sync_connection ||= Faraday.new(url: TODOIST_SYNC_API_URL)

        # TODO: Remove. It was for Fiddler debugging
        @sync_connection ||= Faraday.new(url: TODOIST_SYNC_API_URL, proxy: 'http://127.0.0.1:8888') do |faraday|
          faraday.adapter :net_http do |http| # yields Net::HTTP
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
        end
      end

      def rest_api_connection
        # @rest_connection ||= Faraday.new(url: TODOIST_REST_API_URL)

        @rest_connection ||= Faraday.new(url: TODOIST_REST_API_URL, proxy: 'http://127.0.0.1:8888') do |faraday|
          faraday.adapter :net_http do |http| # yields Net::HTTP
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          faraday.headers['Authorization'] = "Bearer #{api_token}"
        end
      end

      def get_from_todoist(resource_type)
        cache_file = File.join(@cache_dir, "#{resource_type}.json")

        if File.exist? cache_file
          open(cache_file, 'r') do |fin|
            JSON.parse(fin.read)
          end
        else
          puts "Fetching #{resource_type} from Todoist"
          todoist_response = sync_api_connection.get '/api/v7/sync',
                                                     token: api_token,
                                                     sync_token: '*',
                                                     resource_types: JSON.dump([resource_type])

          # TODO: Error handling
          resources = JSON.parse(todoist_response.body)[resource_type]
          open(cache_file, 'w') do |fout|
            fout.write(JSON.dump(resources))
          end
          resources
        end
      end
    end
  end
end
