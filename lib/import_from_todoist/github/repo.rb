# frozen_string_literal: true

require 'erb'
include ERB::Util

module ImportFromTodoist
  module Github
    class Repo
      GITHUB_API_URL = 'https://api.github.com'.freeze
      GITHUB_API_VERSION = { 'Accept' => 'application/vnd.github.v3+json, application/vnd.github.inertia-preview+json' }.freeze

      attr_reader :name

      def initialize(name, api_token)
        @name = name
        @api_token = api_token

        @labels_by_name = Hash[labels.map { |label| [label.name, label] }]
      end

      def project_cards(column)
        response = connection.get("/projects/columns/#{url_encode(column.id)}/cards", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::ProjectCard.from_github(patch_project_card_content(json)) }
      end

      def project_columns(project)
        response = connection.get("/projects/#{url_encode(project.id)}/columns", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::ProjectColumn.from_github(json) }
      end

      def projects
        response = connection.get("/repos/#{name}/projects", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::Project.from_github(json) }
      end

      def milestones
        response = connection.get("/repos/#{name}/milestones", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::Milestone.from_github(json) }
      end

      def issues
        response = connection.get("/repos/#{name}/issues", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::Issue.from_github(json) }
      end

      def comments
        response = connection.get("/repos/#{name}/issues/comments", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::Comment.from_github(json) }
      end

      def comments_on_issue(issue)
        response = connection.get("/repos/#{name}/issues/#{url_encode(issue.number)}/comments", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::Comment.from_github(json) }
      end

      def label(label_name)
        @labels_by_name[label_name]
      end

      def labels
        response = connection.get("/repos/#{name}/labels", state: 'all')
        JSON.parse(response.body).map { |json| ImportFromTodoist::Github::Label.from_github(json) }
      end

      def create_project_column(project, column)
        puts "Creating new column '#{column.name}' for project '#{project.name}'"

        response = connection.post do |req|
          req.url "/projects/#{url_encode(project.id)}/columns"
          req.body = JSON.dump(column.creation_hash)
        end

        ImportFromTodoist::Github::ProjectColumn.from_github(JSON.load(response.body))
      end

      def create_project(project)
        puts "Creating new GitHub Project: #{project.name}"

        response = connection.post do |req|
          req.url "/repos/#{name}/projects"
          req.body = JSON.dump(project.creation_hash)
        end

        ImportFromTodoist::Github::Project.from_github(JSON.load(response.body))
      end

      def update_project(project, changes_needed) # TODO: Rework? Better signature? (project, changes_needed)?
        return project if changes_needed.empty?
        response = connection.patch do |req|
          req.url "/projects/#{url_encode(project.id)}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::Project.from_github(JSON.load(response.body))
      end

      def create_issue(issue)
        puts "Creating new GitHub Issue: #{issue.title}"

        response = connection.post do |req|
          req.url "/repos/#{name}/issues"
          req.body = JSON.dump(issue.creation_hash)
        end

        ImportFromTodoist::Github::Issue.from_github(JSON.load(response.body))
      end

      def update_issue(issue, changes_needed)
        return issue if changes_needed.empty?
        puts "Updating Issue \##{issue.number}: #{changes_needed}"
        response = connection.patch do |req|
          req.url "/repos/#{name}/issues/#{url_encode(issue.number)}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::Issue.from_github(JSON.load(response.body))
      end

      def create_label(label)
        puts "Creating new GitHub Label: #{label.name}"

        response = connection.post do |req|
          req.url "/repos/#{name}/labels"
          req.body = JSON.dump(label.creation_hash)
        end

        ImportFromTodoist::Github::Label.from_github(JSON.load(response.body))
      end

      def update_label(label, changes_needed)
        return label if changes_needed.empty?
        puts "Updating Label '#{label.name}': #{changes_needed}"
        response = connection.patch do |req|
          req.url "/repos/#{name}/labels/#{url_encode(label.name)}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::Label.from_github(JSON.load(response.body))
      end

      def create_milestone(milestone)
        puts "Creating new GitHub milestone: #{milestone.title}"

        response = connection.post do |req|
          req.url "/repos/#{name}/milestones"
          req.body = JSON.dump(milestone.creation_hash)
        end

        ImportFromTodoist::Github::Milestone.from_github(JSON.load(response.body))
      end

      def create_comment(comment, issue)
        puts "Creating new comment on issue: #{issue.title} (\##{issue.number})"

        response = connection.post do |req|
          req.url "/repos/#{name}/issues/#{url_encode(issue.number)}/comments"
          req.body = JSON.dump(comment.creation_hash)
        end

        ImportFromTodoist::Github::Comment.from_github(JSON.load(response.body))
      end

      def update_comment(comment, changes_needed)
        return comment if changes_needed.empty?
        puts "Updating comment '#{comment.id}'"
        response = connection.patch do |req|
          req.url "/repos/#{name}/issues/comments/#{url_encode(comment.id)}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::Comment.from_github(JSON.load(response.body))
      end

      def patch_project_card_content(project_card_hash)
        # Adds the `content_id` and `content_type` fields.
        # Unlike every other endpoint, the project card response is not
        # a similar structure to what gets sent in the creation request.
        # Specifically `content_id` and `content_type` are not returned as part
        # of the response. You can still get this information by checking out
        # the `content_url`.
        content_url = project_card_hash['content_url']
        if content_url
          response = Faraday.get do |req|
            req.url content_url
            req.headers['Authorization'] = "token #{api_token}"
            req.headers.merge!(GITHUB_API_VERSION)
          end

          target = JSON.load(response.body)
          project_card_hash['content_id'] = target.fetch('id')
          project_card_hash['content_type'] = content_url.include?('issues') ? 'Issue' : 'PullRequest'
        end

        project_card_hash
      end

      def create_project_card(comment, column)
        puts "Creating new card on project column: #{column.name} (\##{column.id})"

        response = connection.post do |req|
          req.url "/projects/columns/#{url_encode(column.id)}/cards"
          req.body = JSON.dump(comment.creation_hash)
        end

        ImportFromTodoist::Github::ProjectCard.from_github(patch_project_card_content(JSON.load(response.body)))
      end

      def update_project_card(project_card, changes_needed)
        return project_card if changes_needed.empty?
        puts "Updating project card '#{project_card.id}'"
        response = connection.patch do |req|
          req.url "/projects/columns/cards/#{url_encode(project_card.id)}"
          req.body = JSON.dump(changes_needed)
        end

        ImportFromTodoist::Github::ProjectCard.from_github(patch_project_card_content(JSON.load(response.body)))
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
