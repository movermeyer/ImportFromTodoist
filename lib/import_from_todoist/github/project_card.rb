# frozen_string_literal: true

module ImportFromTodoist
  module Github
    class ProjectCard < Struct.new(:id, :note, :content_id, :content_type)
      private_class_method :new

      def self.from_github(hash)
        note = hash['note']
        note ? new(hash.fetch('id'), note, nil, nil) : new(hash.fetch('id'), nil, hash.fetch('content_id'), hash.fetch('content_type'))
      end

      def self.from_todoist_project_comment(comment, collaborator)
        new(nil, ImportFromTodoist::Github::DescriptionHelper.generate_github_description(comment.id,
                                                                                          description: comment.content,
                                                                                          context: ImportFromTodoist::Github::DescriptionHelper.generate_comment_context(comment, collaborator)),
            nil, nil)
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
