module ImportFromTodoist
  module Github
    class Comment < Struct.new(:id, :body)
      private_class_method :new

      def self.generate_github_description(todoist_comment, todoist_collaborator, description = '') # TODO: Remove
        # Generates a description that includes a GitHub Markdown comment (ie.
        # hack, see https://stackoverflow.com/a/20885980/6460914). That way, the
        # Todoist id can be embedded for easy cross-referencing in future runs.
        ''"#{description}

---

**Originally written**#{todoist_collaborator ? " **by** `#{todoist_collaborator.full_name}`" : ''} at `#{todoist_comment.post_time}`
**Imported from [Todoist](TODO: Url)**

[//]: # (Warning: DO NOT DELETE!)
[//]: # (The below comment is important for making Todoist imports work. For more details, see TODO: Add URL)
[//]: # (TODOIST_ID: #{todoist_comment.id})"''
      end

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('body'))
      end

      def self.from_todoist_comment(comment, collaborator)
        new(nil, generate_github_description(comment, collaborator, comment.content))
      end

      def creation_hash
        { body: body }
      end

      def mutable_value_hash
        creation_hash
      end
    end
  end
end
