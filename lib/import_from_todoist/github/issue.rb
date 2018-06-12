module ImportFromTodoist
  module Github
    class Issue < Struct.new(:id, :number, :title, :body)
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
        new(hash.fetch('id'), hash.fetch('number'), hash.fetch('title'), hash.fetch('body'))
      end

      def self.from_todoist_task(task)
        new(nil, nil, task.content, generate_github_description(task.id))
      end

      def creation_hash
        { title: :title, body: :body }
      end

      def mutable_value_hash
        to_h.keep_if { |key, _value| !%i[id number].include? key }
      end
    end
  end
end
