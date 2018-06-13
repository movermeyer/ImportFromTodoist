module ImportFromTodoist
  class System
    def diff_hashes(hash1, hash2)
      # Something like `{ a: 1 }.to_a & { a: 1, b: 2 }.to_a` or set difference, left_align
      # TODO: There is probably a better way to do this.
      differences = {}
      hash1.each do |key, value|
        differences[key] = value if hash2[key] != value
      end

      differences
    end

    def get_todist_id(description)
      return description if description.nil?
      match = description.match(/TODOIST_ID: (\d+)/)
      todist_id = match.captures.first.to_i if match
    end

    def generate_github_description(todoist_id, description = '') # TODO: Remove
      # Generates a description that includes a GitHub Markdown comment (ie.
      # hack, see https://stackoverflow.com/a/20885980/6460914). That way, the
      # Todoist id can be embedded for easy cross-referencing in future runs.
      ''"#{description}

[//]: # (Warning: DO NOT DELETE!)
[//]: # (The below comment is important for making Todoist imports work. For more details, see TODO: Add URL)
[//]: # (TODOIST_ID: #{todoist_id})"''
    end

    def initialize(todoist_api_token, github_api_token, github_repo_name, no_cache)
      @todoist_api = ImportFromTodoist::Todoist::Api.new(todoist_api_token, no_cache: no_cache)
      @github_repo = ImportFromTodoist::Github::Repo.new(github_repo_name, github_api_token)

      @todoist_task_id_to_github_issue = {}
      @todoist_comment_id_to_github_comment = {}
      @todoist_project_comment_id_to_github_project_card = {}
      @todoist_project_id_to_github_project = {}
      @todoist_due_date_to_github_milestone = {}
      @todoist_label_id_to_github_label = {}
      @todoist_priority_to_github_label = {}

      @columns_by_project_id_and_column_name = {} # Cache elsewhere?
      @cards_by_column_id_and_target_id = {} # Cache elsewhere?

      # Fetch existing issues
      github_repo.issues.each do |issue|
        todist_id = get_todist_id(issue.body)
        todoist_task_id_to_github_issue[todist_id] = issue if todist_id # TODO: Only cache the ids here. repo should cache the actual objects
      end

      # Fetch existing projects
      github_repo.projects.each do |project|
        todist_id = get_todist_id(project.body)
        todoist_project_id_to_github_project[todist_id] = project if todist_id # TODO: Only cache the ids here. repo should cache the actual objects
      end

      # Fetch existing milestones
      github_repo.milestones.each do |milestone|
        todoist_due_date_to_github_milestone[milestone.title] = milestone
      end

      # Fetch existing comments
      github_repo.comments.each do |comment|
        todist_id = get_todist_id(comment.body)
        todoist_comment_id_to_github_comment[todist_id] = comment if todist_id # TODO: Only cache the ids here. repo should cache the actual objects
      end
    end

    def project_column(project, column)
      columns_by_project_id_and_column_name[project.id] ||= Hash[github_repo.project_columns(project).map { |column| [column.name, column] }]
      columns_by_project_id_and_column_name[project.id][column.name] ||= github_repo.create_project_column(project, column)
    end

    def project(todoist_project_id)
      todoist_project = todoist_api.project(todoist_project_id)
      puts "Processing #{todoist_project.name}"
      unless todoist_project_id_to_github_project.key?(todoist_project_id)
        uncommited_github_project = ImportFromTodoist::Github::Project.from_todoist_project(todoist_project) # TODO: rename?
        todoist_project_id_to_github_project[todoist_project_id] = github_repo.create_project(uncommited_github_project)
      end

      existing_project = todoist_project_id_to_github_project[todoist_project_id]

      # Ensuring Project Columns exist
      desired_project_column_names = Set['To Do', 'Comments']
      _project_columns = desired_project_column_names.map { |column_name| project_column(existing_project, ImportFromTodoist::Github::ProjectColumn.from_name(column_name)) }

      # Update Project if necessary
      desired_project = ImportFromTodoist::Github::Project.from_todoist_project(todoist_project)
      changes_needed = diff_hashes(desired_project.mutable_value_hash, existing_project.mutable_value_hash)
      todoist_project_id_to_github_project[todoist_project_id] = github_repo.update_project(existing_project, changes_needed)
    end

    def milestone(todoist_due_date)
      unless todoist_due_date_to_github_milestone.key?(todoist_due_date)
        uncommited_github_milestone = ImportFromTodoist::Github::Milestone.from_due_date(todoist_due_date) # TODO: rename?
        todoist_due_date_to_github_milestone[todoist_due_date] = github_repo.create_milestone(uncommited_github_milestone)
      end
      # TODO: Handle updates
      todoist_due_date_to_github_milestone[todoist_due_date]
    end

    def label_helper(existing_label, todoist_label)
      existing_label ||= github_repo.label(todoist_label.name)
      unless existing_label
        uncommited_github_label = ImportFromTodoist::Github::Label.from_todoist_label(todoist_label) # TODO: rename?
        existing_label = github_repo.create_label(uncommited_github_label)
      end

      # Update Label if necessary
      desired_label = ImportFromTodoist::Github::Label.from_todoist_label(todoist_label) # TODO: Collapse Create + Update into UPSERT?
      changes_needed = diff_hashes(desired_label.mutable_value_hash, existing_label.mutable_value_hash)
      github_repo.update_label(existing_label, changes_needed)
    end

    def priority(priority)
      desired_label = ImportFromTodoist::Todoist::Label.from_priority(priority)
      todoist_priority_to_github_label[priority] = label_helper(todoist_priority_to_github_label[priority], desired_label)
    end

    def label(todoist_label)
      # Does caching that isn't done in label_helper since `priority` also uses it and can't cache.
      todoist_label_id_to_github_label[todoist_label.id] = label_helper(todoist_label_id_to_github_label[todoist_label.id], todoist_label)
    end

    def issue(todoist_task_id)
      todoist_task = todoist_api.task(todoist_task_id)
      desired_issue_hash = {
        title: todoist_task.content,
        body: generate_github_description(todoist_task.id),
        labels: todoist_task.labels.map { |label_id| label(todoist_api.label(label_id)).name },
        state: todoist_task.completed ? 'closed' : 'open'
      }
      desired_issue_hash[:milestone_number] = milestone(todoist_task.due_on).number if todoist_task.due_on
      desired_issue_hash[:labels] += [priority(todoist_task.priority).name] if todoist_task.priority
      desired_issue = ImportFromTodoist::Github::Issue.from_hash(desired_issue_hash)

      unless todoist_task_id_to_github_issue.key?(todoist_task.id)
        todoist_task_id_to_github_issue[todoist_task.id] = github_repo.create_issue(desired_issue)
      end

      existing_issue = todoist_task_id_to_github_issue[todoist_task.id]

      # Update issue if necessary
      changes_needed = diff_hashes(desired_issue.mutable_value_hash, existing_issue.mutable_value_hash)
      todoist_task_id_to_github_issue[todoist_task.id] = github_repo.update_issue(existing_issue, changes_needed)
    end

    def fetch_project_cards(column)
      unless cards_by_column_id_and_target_id.key? column.id
        cards_by_column_id_and_target_id[column.id] = {}
        cards = github_repo.project_cards(column)
        cards.each do |card|
          if card.note
            todist_id = get_todist_id(card.note)
            cards_by_column_id_and_target_id[column.id][todist_id] = card if todist_id # TODO: Only cache the ids here. repo should cache the actual objects
          else
            cards_by_column_id_and_target_id[column.id][card.content_id] = card
          end
        end
      end
      cards_by_column_id_and_target_id[column.id]
    end

    def project_card(target_project, issue)
      desired_card = ImportFromTodoist::Github::ProjectCard.from_github_issue(issue)
      column = project_column(target_project, ImportFromTodoist::Github::ProjectColumn.from_name('To Do')) # TODO: Refactor out this constant "To Do"
      fetch_project_cards(column)
      cards_by_column_id_and_target_id[column.id][issue.id] ||= github_repo.create_project_card(desired_card, column)
    end

    def comment(target_issue, todoist_comment)
      desired_comment = ImportFromTodoist::Github::Comment.from_todoist_comment(todoist_comment, todoist_api.collaborator(todoist_comment.poster))

      unless todoist_comment_id_to_github_comment.key?(todoist_comment.id)
        todoist_comment_id_to_github_comment[todoist_comment.id] = github_repo.create_comment(desired_comment, target_issue)
      end

      existing_comment = todoist_comment_id_to_github_comment[todoist_comment.id]

      # Update comment if necessary
      changes_needed = diff_hashes(desired_comment.mutable_value_hash, existing_comment.mutable_value_hash)
      todoist_comment_id_to_github_comment[todoist_comment.id] = github_repo.update_comment(existing_comment, changes_needed)
    end

    def project_comment(target_project, todoist_comment)
      desired_card = ImportFromTodoist::Github::ProjectCard.from_todoist_project_comment(todoist_comment, todoist_api.collaborator(todoist_comment.poster))

      column = project_column(target_project, ImportFromTodoist::Github::ProjectColumn.from_name('Comments')) # TODO: Refactor out this constant "Comments"
      existing_cards = fetch_project_cards(column)

      unless existing_cards.key?(todoist_comment.id)
        cards_by_column_id_and_target_id[column.id][todoist_comment.id] = github_repo.create_project_card(desired_card, column)
      end

      existing_card = cards_by_column_id_and_target_id[column.id][todoist_comment.id]

      # # Update comment if necessary
      changes_needed = diff_hashes(desired_card.mutable_value_hash, existing_card.mutable_value_hash)
      cards_by_column_id_and_target_id[column.id][todoist_comment.id] = github_repo.update_project_card(existing_card, changes_needed)
    end

    private

    attr_reader :todoist_api
    attr_reader :github_repo
    attr_accessor :todoist_task_id_to_github_issue
    attr_accessor :todoist_comment_id_to_github_comment
    attr_accessor :todoist_project_comment_id_to_github_project_card
    attr_accessor :todoist_project_id_to_github_project
    attr_accessor :todoist_due_date_to_github_milestone
    attr_accessor :todoist_label_id_to_github_label
    attr_accessor :todoist_priority_to_github_label
    attr_accessor :columns_by_project_id_and_column_name # TODO: move elsewhere?
    attr_accessor :cards_by_column_id_and_target_id # TODO: move elsewhere?
  end
end
