# frozen_string_literal: true

module ImportFromTodoist
  module Github
    module DescriptionHelper
      def self.generate_github_description(todoist_id, description: '', context: '')
        # Generates a description that includes a GitHub Markdown comment (ie.
        # hack, see https://stackoverflow.com/a/20885980/6460914). That way, the
        # Todoist id can be embedded for easy cross-referencing in future runs.
        [description, context, explanation_comment(todoist_id)].reject(&:empty?).join("\n\n")
      end

      def self.generate_comment_context(todoist_comment, todoist_collaborator)
        # Generates a description that includes a GitHub Markdown comment (ie.
        # hack, see https://stackoverflow.com/a/20885980/6460914). That way, the
        # Todoist id can be embedded for easy cross-referencing in future runs.
        <<~HEREDOC
          ---

          **Originally written**#{todoist_collaborator ? " **by** `#{todoist_collaborator.full_name}`" : ''} at `#{todoist_comment.post_time}`
          **Imported from [Todoist](https://github.com/movermeyer/ImportFromTodoist)**
        HEREDOC
      end

      def self.explanation_comment(todoist_id)
        <<~HEREDOC
          [//]: # (Warning: DO NOT DELETE!)
          [//]: # (The below comment is important for making Todoist imports work. For more details, see https://github.com/movermeyer/ImportFromTodoist/blob/master/docs/data_mapping.md#associating-objects-across-changes)
          [//]: # (TODOIST_ID: #{todoist_id})
        HEREDOC
      end

      def self.get_todist_id(description)
        # Pulls out the Todoist ID from a GitHub description
        return description if description.nil?
        match = description.match(/TODOIST_ID: (\d+)/)
        todist_id = match.captures.first.to_i if match
      end
    end
  end
end
