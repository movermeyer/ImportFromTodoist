module ImportFromTodoist
  module Todoist
    class Collaborator < Struct.new(:id, :email, :full_name, :timezone)
      private_class_method :new

      def self.from_todoist(hash)
        new(hash.fetch('id'),
            hash.fetch('email'),
            hash.fetch('full_name'),
            hash.fetch('timezone'))
      end
    end
  end
end
