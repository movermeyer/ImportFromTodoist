# frozen_string_literal: true

module ImportFromTodoist
  module Github
    class Project < Struct.new(:id, :name, :body, :state)
      private_class_method :new

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('name'), hash.fetch('body'), hash.fetch('state'))
      end

      def self.from_todoist_project(project)
        state = project.is_deleted == 1 || project.is_archived == 1 ? 'closed' : 'open'
        new(nil, project.name, ImportFromTodoist::Github::DescriptionHelper.generate_github_description(project.id), state)
      end

      def creation_hash
        { name: name, body: body }
      end

      def mutable_value_hash
        to_h.keep_if { |key, _value| key != :id }
      end
    end
  end
end
