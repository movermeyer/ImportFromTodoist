# def create_github_project_column(project_id, name, github_api_token)
#   conn = Faraday.new(url: GITHUB_API_URL)

#   body = {
#     'name' => name
#   }

#   github_response = conn.post do |req|
#     req.url "/projects/#{project_id}/columns"
#     req.headers['Authorization'] = "token #{github_api_token}"
#     req.headers = req.headers.merge(GITHUB_API_VERSION)
#     req.body = JSON.dump(body)
#   end

#   JSON.parse(github_response.body)
# end

module ImportFromTodoist
  module Github
    class Project < Struct.new(:id, :name, :body, :state)
      private_class_method :new

      def self.generate_github_description(todoist_id, description = '') # TODO: Remove
        # Generates a description that includes a GitHub Markdown comment (ie.
        # hack, see https://stackoverflow.com/a/20885980/6460914). That way, the
        # Todoist id can be embedded for easy cross-referencing in future runs.
        ''"#{description}

[//]: # (Warning: DO NOT DELETE!)
[//]: # (The below comment is important for making Todoist imports work. For more details, see TODO: Add URL)
[//]: # (TODOIST_ID: #{todoist_id})"''
      end

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('name'), hash.fetch('body'), hash.fetch('state'))
      end

      def self.from_todoist_project(project)
        state = project.is_deleted == 1 || project.is_archived == 1 ? 'closed' : 'open'
        new(nil, project.name, generate_github_description(project.id), state)
      end

      def creation_hash
        { name: :name, body: :body }
      end

      def mutable_value_hash
        to_h.keep_if { |key, _value| key != :id }
      end
    end
  end
end
