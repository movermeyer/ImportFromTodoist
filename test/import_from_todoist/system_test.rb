# frozen_string_literal: true

require 'date'
require 'minitest/autorun'
require_relative '../../lib/import_from_todoist'

# Mock out the GitHub API

module ImportFromTodoist
  class SystemTest < Minitest::Test
    # System is designed to not do computation of values, but just make the
    # appropriate calls to the APIs in the correct order.
    # So in these tests we don't care much about the resulting values, but mainly
    # that the API calls occured. Tests of the proper value creation is done in the
    # tests of the object classes (ex. label_test.rb).

    def setup
      @github_api = Minitest::Mock.new
      @github_api.expect :issues, []
      @github_api.expect :projects, []
      @github_api.expect :milestones, []
      @github_api.expect :comments, []

      @todoist_api = Minitest::Mock.new
    end

    def teardown
      @github_api.verify
      @todoist_api.verify
    end

    def test_sync_project_with_empty_repo
      system = System.new(@todoist_api, @github_api)

      project_id = 123
      todoist_project = ImportFromTodoist::Todoist::Project.send(:new, 'Test Project', false, false)
      @todoist_api.expect :project, todoist_project, [123]

      desired_github_project = ImportFromTodoist::Github::Project.from_todoist_project(todoist_project)

      @github_api.expect :create_project, desired_github_project, [desired_github_project]

      @github_api.expect :project_columns, [], [desired_github_project]
      @github_api.expect :create_project_column, nil, [desired_github_project, ImportFromTodoist::Github::ProjectColumn.from_name('To Do')]
      @github_api.expect :create_project_column, nil, [desired_github_project, ImportFromTodoist::Github::ProjectColumn.from_name('Comments')]

      @github_api.expect :update_project, desired_github_project, [desired_github_project, {}]
      assert_equal desired_github_project, system.project(project_id)
    end

    def test_sync_project_with_differing_existing_project
      project_id = 123
      todoist_project = ImportFromTodoist::Todoist::Project.send(:new, project_id, 'Test Project', false, false)
      @todoist_api.expect :project, todoist_project, [123]
      desired_github_project = ImportFromTodoist::Github::Project.from_todoist_project(todoist_project)

      existing_description = ImportFromTodoist::Github::DescriptionHelper.generate_github_description(todoist_project.id)
      existing_github_project = ImportFromTodoist::Github::Project.send(:new, 9999, 'Old Project', existing_description, 'closed')

      @github_api.projects # Hack to clear the first call in `setup``. TODO: Figure out how it's supposed to be done.
      @github_api.expect :projects, [existing_github_project]
      system = System.new(@todoist_api, @github_api)

      @github_api.expect :project_columns, [ImportFromTodoist::Github::ProjectColumn.from_name('To Do')], [existing_github_project]
      @github_api.expect :create_project_column, nil, [existing_github_project, ImportFromTodoist::Github::ProjectColumn.from_name('Comments')]

      @github_api.expect :update_project, desired_github_project, [existing_github_project, { name: 'Test Project', state: 'open' }]
      assert_equal desired_github_project, system.project(project_id)
    end

    def test_sync_milestone_with_empty_repo
      system = System.new(@todoist_api, @github_api)
      task = ImportFromTodoist::Todoist::Task.send(:new, 123, 'Test Task', 1_234_567_890, false, DateTime.iso8601('2018-06-10T00:00:00Z'), [], 0)
      desired_github_milestone = ImportFromTodoist::Github::Milestone.from_todoist_task(task)

      @github_api.expect :create_milestone, desired_github_milestone, [desired_github_milestone]
      @github_api.expect :update_milestone, desired_github_milestone, [desired_github_milestone, {}]
      assert_equal desired_github_milestone, system.milestone(task)
    end

    def test_sync_milestone_with_differing_existing_milestone
      task = ImportFromTodoist::Todoist::Task.send(:new, 123, 'Test Task', 1_234_567_890, false, DateTime.iso8601('2018-06-10T00:00:00Z'), [], 0)
      desired_github_milestone = ImportFromTodoist::Github::Milestone.from_todoist_task(task)

      existing_description = ImportFromTodoist::Github::DescriptionHelper.generate_github_description(task.id)
      existing_github_milestone = ImportFromTodoist::Github::Milestone.send(:new, 1_233_456, 10, 'Old Task Name', existing_description, 'closed', DateTime.iso8601('2018-06-11T11:11:11Z'))

      @github_api.milestones # Hack to clear the first call in `setup``. TODO: Figure out how it's supposed to be done.
      @github_api.expect :milestones, [existing_github_milestone]
      system = System.new(@todoist_api, @github_api)

      @github_api.expect :update_milestone, desired_github_milestone, [existing_github_milestone, { title: 'Test Task', state: 'open', due_on: '2018-06-09T07:00:00Z' }]
      assert_equal desired_github_milestone, system.milestone(task)
    end

    def test_sync_label_with_empty_repo
      system = System.new(@todoist_api, @github_api)
      label = ImportFromTodoist::Todoist::Label.send(:new, 123, 'Test Label', '555555')
      desired_github_label = ImportFromTodoist::Github::Label.from_todoist_label(label)

      @github_api.expect :label, nil, ['Test Label']
      @github_api.expect :create_label, desired_github_label, [desired_github_label]
      @github_api.expect :update_label, desired_github_label, [desired_github_label, {}]
      assert_equal desired_github_label, system.label(label)
    end

    def test_sync_label_differing_existing_label
      system = System.new(@todoist_api, @github_api)
      label = ImportFromTodoist::Todoist::Label.send(:new, 123, 'Test Label', '555555')
      desired_github_label = ImportFromTodoist::Github::Label.from_todoist_label(label)
      existing_github_label = ImportFromTodoist::Github::Label.send(:new, 456, 'Test Label', '000000')

      @github_api.expect :label, existing_github_label, ['Test Label']
      @github_api.expect :update_label, desired_github_label, [existing_github_label, { color: '555555' }]
      assert_equal desired_github_label, system.label(label)
    end
  end
end
