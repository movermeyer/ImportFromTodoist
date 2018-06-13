module ImportFromTodoist
  module Todoist
    class Comment < Struct.new(:id, :project_id, :task_id, :poster, :post_time, :content, :is_archived, :is_deleted)
      private_class_method :new
      # TODO: Handle attachments

      def self.from_todoist(hash)
        new(hash.fetch('id'),
            hash.fetch('project_id'),
            hash['item_id'], # If this is a project comment it doesn't have this.
            hash.fetch('posted_uid'),
            hash.fetch('posted'),
            hash.fetch('content'),
            hash.fetch('is_archived'),
            hash.fetch('is_deleted'))
      end
    end
  end
end
