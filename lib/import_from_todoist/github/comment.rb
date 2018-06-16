# frozen_string_literal: true

require_relative 'description_helper'
module ImportFromTodoist
  module Github
    class Comment < Struct.new(:id, :body)
      private_class_method :new

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('body'))
      end

      def self.from_todoist_comment(comment, collaborator)
        new(nil, ImportFromTodoist::Github::DescriptionHelper.generate_github_description(comment.id,
                                                                                          description: comment.content,
                                                                                          context: ImportFromTodoist::Github::DescriptionHelper.generate_comment_context(comment, collaborator)))
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
