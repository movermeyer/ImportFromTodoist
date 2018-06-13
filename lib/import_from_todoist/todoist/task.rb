module ImportFromTodoist
  module Todoist
    class Task < Struct.new(:id, :content, :project_id, :completed, :due_on, :labels, :priority)
      private_class_method :new

      # For display to end users, "very urgent" is 1
      # The API returns 1-4, with 4 being "very urgent"
      MAX_PRIORITY = 4

      def self.from_todoist(hash)
        priority = hash['priority']
        new(hash.fetch('id'),
            hash.fetch('content'),
            hash.fetch('project_id'),
            (hash.fetch('checked', 0) == 1 || !hash['completed_date'].nil?), # TODO: Remove nil check?
            hash['due_on'],
            hash.fetch('labels', []),
            priority ? (MAX_PRIORITY - priority + 1) : nil)
      end
    end
  end
end
