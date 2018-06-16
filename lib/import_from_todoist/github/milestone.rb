# frozen_string_literal: true

require 'active_support/time'
require 'date'

module ImportFromTodoist
  module Github
    class Milestone < Struct.new(:id, :number, :title, :description, :state, :due_on)
      private_class_method :new

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('number'), hash.fetch('title'), hash.fetch('description'), hash.fetch('state'), DateTime.iso8601(hash.fetch('due_on')))
      end

      def self.from_todoist_task(task)
        # The GitHub API has some strange behaviour when it comes to Milestone due dates.
        # It might be a bug (I've reported it).
        # Their API requires "due_on" to be in the format `YYYY-MM-DDTHH:MM:SSZ`.
        # But then it seems that they do a series of transformations on their side.
        # This can result in the wrong day appearing in the UI's `/milestones` endpoint.
        #
        # As best as I can tell, it seems that the API is:
        #
        # 1. Taking the user supplied timestamp (`2018-06-20T00:00:01Z`)
        # 2. Converting it to equivalent time in the `America/Los_Angeles` timezone (`2018-06-19T17:00:01-07:00`)
        # 3. Truncating the time portion of the datetime to get the start of the day (`2018-06-19T00:00:00-07:00`)
        # 4. Converting it to equivalent time in UTC (`2018-06-19T07:00:00Z`)
        # 5. Ignoring the time portion of the datetime when rendering the UI. (`2018-06-19`)
        #
        # But we expected the due date to be `2018-06-20.`
        #
        # Instead of trying to work around it, we try to apply the same transform on our side so that the timestamps match
        # and the script doesn't keep trying to update the "due_on" field.
        # If GitHub fixes this, or gives more information about what is happening, a better solution could be developed.
        due_on = task.due_on.in_time_zone('America/Los_Angeles').beginning_of_day.in_time_zone('UTC')

        new(nil, nil, task.content, ImportFromTodoist::Github::DescriptionHelper.generate_github_description(task.id), task.completed ? 'closed' : 'open', due_on)
      end

      def creation_hash
        { title: title, description: description, state: state, due_on: due_on.iso8601 }
      end

      def mutable_value_hash
        { title: title, description: description, state: state, due_on: due_on }
      end
    end
  end
end
