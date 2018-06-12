module ImportFromTodoist
  module Todoist
    class Project < Struct.new(:id, :name, :is_archived, :is_deleted)
      private_class_method :new

      def self.from_todoist(hash)
        new(hash.fetch('id'), hash.fetch('name'), hash.fetch('is_archived'), hash.fetch('is_deleted'))
      end
    end
  end
end
