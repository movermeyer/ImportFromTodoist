# frozen_string_literal: true

module ImportFromTodoist
  module Github
    class Repo
      GITHUB_API_URL = 'https://api.github.com'.freeze
      GITHUB_API_VERSION = { 'Accept' => 'application/vnd.github.v3+json, application/vnd.github.inertia-preview+json' }.freeze

      attr_reader :name

      def initialize(name, api_token)
        @name = name
        @api_token = api_token
      end

      def projects
        github_response = connection.get("/repos/#{name}/projects", state: 'all')
        JSON.parse(github_response.body).map { |json| ImportFromTodoist::Github::Project.from_github(json) }
      end

      def milestones
        github_response = connection.get("/repos/#{name}/milestones", state: 'all')
        JSON.parse(github_response.body).map { |json| ImportFromTodoist::Github::Milestone.from_github(json) }
      end

      def issues
        github_response = connection.get("/repos/#{name}/issues", state: 'all')
        JSON.parse(github_response.body).map { |json| ImportFromTodoist::Github::Issue.from_github(json) }
      end

      def labels
        github_response = connection.get("/repos/#{name}/labels", state: 'all')
        JSON.parse(github_response.body).map { |json| ImportFromTodoist::Github::Label.from_github(json) }
      end

      def create_project(project)
        puts "Creating new GitHub Project: #{project.name}"

        github_response = connection.post do |req|
          req.url "/repos/#{name}/projects"
          req.body = JSON.dump(project.creation_hash)
        end

        ImportFromTodoist::Github::Project.from_github(JSON.load(github_response.body))

        # TODO: Add columns
      end

      def update_project(project_id, changes_needed) # TODO: Rework? Better signature? (project, changes_needed)?
        return if changes_needed.empty?
        github_response = connection.patch do |req|
          req.url "/projects/#{project_id}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::Project.from_github(JSON.load(github_response.body))
      end

      def create_issue(issue)
        puts "Creating new GitHub Issue: #{issue.title}"

        github_response = connection.post do |req|
          req.url "/repos/#{name}/issues"
          req.body = JSON.dump(issue.creation_hash)
        end

        ImportFromTodoist::Github::Project.from_github(JSON.load(github_response.body))
      end

      def update_issue(issue_number, changes_needed)
        return if changes_needed.empty?
        puts "Updating Issue \##{issue_number}: #{changes_needed}"
        github_response = connection.patch do |req|
          req.url "/repos/#{name}/issues/#{issue_number}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::Issue.from_github(JSON.load(github_response.body))
      end

      def create_label(label)
        puts "Creating new GitHub Label: #{issue.name}"

        github_response = connection.post do |req|
          req.url "/repos/#{name}/labels"
          req.body = JSON.dump(label.creation_hash)
        end

        ImportFromTodoist::Github::Label.from_github(JSON.load(github_response.body))
      end

      def update_label(label_name, changes_needed)
        return if changes_needed.empty?
        puts "Updating Label '#{label_name}': #{changes_needed}"
        github_response = connection.patch do |req|
          req.url "/repos/#{name}/labels/#{label_name}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::Label.from_github(JSON.load(github_response.body))
      end

      private

      attr_reader :api_token

      def connection
        # TODO: Remove. It was for Fiddler debugging
        @connection ||= Faraday.new(url: GITHUB_API_URL, proxy: 'http://127.0.0.1:8888') do |faraday|
          faraday.adapter :net_http do |http| # yields Net::HTTP
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          faraday.headers['Authorization'] = "token #{api_token}"
          faraday.headers.merge!(GITHUB_API_VERSION)
        end

        # @connection ||= Faraday.new(url: GITHUB_API_URL) do |faraday|
        #   faraday.headers['Authorization'] = "token #{api_token}"
        #   faraday.headers.merge!(GITHUB_API_VERSION)
        # end
      end
    end
  end
end
