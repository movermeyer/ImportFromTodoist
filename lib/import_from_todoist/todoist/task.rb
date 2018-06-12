module ImportFromTodoist
  module Todoist
    class Task < Struct.new(:id, :content, :project_id, :due_on, :labels)
      private_class_method :new

      def self.from_todoist(hash)
        new(hash.fetch('id'), hash.fetch('content'), hash.fetch('project_id'), hash.fetch('due_on'), hash.fetch('labels'))
      end
    end
  end
end
