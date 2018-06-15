module ImportFromTodoist
  module Github
    class ProjectCard < Struct.new(:id, :note, :content_id, :content_type)
      private_class_method :new

      def self.generate_github_description(todoist_comment, todoist_collaborator, description = '') # TODO: Remove
        # Generates a description that includes a GitHub Markdown comment (ie.
        # hack, see https://stackoverflow.com/a/20885980/6460914). That way, the
        # Todoist id can be embedded for easy cross-referencing in future runs.
        ''"#{description}

---

**Originally written**#{todoist_collaborator ? " **by** `#{todoist_collaborator.full_name}`" : ''} at `#{todoist_comment.post_time}`
**Imported from [Todoist](https://github.com/movermeyer/ImportFromTodoist)**

[//]: # (Warning: DO NOT DELETE!)
[//]: # (The below comment is important for making Todoist imports work. For more details, see https://github.com/movermeyer/ImportFromTodoist/blob/master/docs/data_mapping.md#associating-objects-across-changes)
[//]: # (TODOIST_ID: #{todoist_comment.id})"''
      end

      def self.from_github(hash)
        note = hash['note']
        note ? new(hash.fetch('id'), note, nil, nil) : new(hash.fetch('id'), nil, hash.fetch('content_id'), hash.fetch('content_type'))
      end

      def self.from_todoist_project_comment(todoist_comment, todoist_collaborator)
        new(nil, generate_github_description(todoist_comment, todoist_collaborator, todoist_comment.content), nil, nil)
      end

      def self.from_github_issue(github_issue)
        new(nil, nil, github_issue.id, 'Issue')
      end

      def creation_hash
        note ? { note: note } : { content_id: content_id, content_type: content_type }
      end

      def mutable_value_hash
        note ? { note: note } : {}
      end
    end
  end
end
