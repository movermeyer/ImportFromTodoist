<!-- TOC -->

- [Introduction](#introduction)
- [Overview](#overview)
- [Associating objects across changes](#associating-objects-across-changes)
    - [Tasks](#tasks)
        - [Task Creation](#task-creation)
        - [Issue and Milestone State](#issue-and-milestone-state)
        - [Changing Project of Task](#changing-project-of-task)
        - [Other relationships](#other-relationships)
    - [Projects](#projects)
        - [Project Creation](#project-creation)
        - [Project State](#project-state)
        - ["To Do" Column](#to-do-column)
        - ["Comments" Column](#comments-column)
        - [Other relationships](#other-relationships-1)
    - [Labels](#labels)
        - [Non-uniqueness](#non-uniqueness)
    - [Comments](#comments)

<!-- /TOC -->

# Introduction

Todoist offers a lot of functionality. `import_from_todoist` tries to maintain as much of that functionality as possible, by defining a mapping between the Todoist Data Model (Tasks, Projects, Due Dates, Labels etc.) and the GitHub Issues data model (Issues, Projects, Milestones, Labels).

This document will describe the mapping that `import_from_todoist` uses when importing data from Todoist into GitHub Issues.

(For a walk-through of how the design decisions of this mapping were made, [see this document](design_decisions.md).)

# Overview

(TODO: A diagram of the over-all data model)

# Associating objects across changes

A mechanism was needed in order to track updates to Todoist objects across multiple runs of `import_from_todoist`.

For example, if a Todoist user changed the name of a Task, then the changed should be replicated to the corresponding Issue in GitHub Issues.

This requires storing some state that captures the mapping between Todoist objects and their corresponding GitHub Issues objects.

The solution implemented uses a hidden Markdown "comment" within the description attributes of Issues, Projects, Project Cards, Milestones, and Comments:

Example:
```
This is an example value of a `body` attribute of a GitHub Project.

[//]: # (Warning: DO NOT DELETE!)
[//]: # (The below comment is important for making Todoist imports work. For more details, see https://github.com/movermeyer/ImportFromTodoist/blob/master/docs/data_mapping.md#associating-objects-across-changes)
[//]: # (TODOIST_ID: 1234567890)
```

Users will only see this hidden comment if they manually edit the descriptions of these objects. Even then, the comment was designed to explain its importance, directing curious users to this page where they could read more.

## Tasks

### Task Creation

When you create a Task in Todoist:
* A corresponding Issue is created in GitHub Issues.
* If the task has a due date, a corresponding Milestone is created with that due date
* If the task has any labels, a corresponding [Label](#label) is created for each of them.
* A project card is created in the "To Do" column of the GitHub Project corresponding to the Task's Project

### Issue and Milestone State

The `state` of a GitHub Issue and Milestone depends on the state of the corresponding Todoist Task:

| Todoist Project state   | Corresponding GitHub Issue state   | Corresponding GitHub Milestone state | Notes |
| ----------------------  | ---------------------------------- | ------------------------------------ | ----- |
| Unarchived (ie. Normal) | `open`                             | `open`                               |       |
| Archived                | `closed`                           | `closed`                             | [Not implemented yet](https://github.com/movermeyer/ImportFromTodoist/issues/8) |
| Deleted                 | `closed`                           | `closed`                             | [Not implemented yet](https://github.com/movermeyer/ImportFromTodoist/issues/8) |

### Changing Project of Task

When you change the project of a Task:

* A corresponding project card is made in the corresponding new project
* The corresponding project card in the original project is deleted ([Not implemented yet](https://github.com/movermeyer/ImportFromTodoist/issues/8))

### Other relationships

Other attributes of GitHub Issues are kept in sync with their Todoist counterpart's. 
Changes made to these attributes in Todoist are replicated within the GitHub Issue.

| [Todoist Task attribute](https://developer.todoist.com/sync/v7/#items) | Corresponding [GitHub Issue attribute](https://developer.github.com/v3/issues/#edit-an-issue) | Corresponding [GitHub Milestone attribute](https://developer.github.com/v3/issues/milestones/#update-a-milestone) |
| ------------------------- | ------------------------------------ | ---------------------------------------- |
| Task Name (`content`)     | Issue Title (`title`)                | Milestone Title (`title`)                |
| Task Due date (`due`)     |                                      | Milestone Due Date (`due_on`)            |


## Projects

### Project Creation

When you create a project in Todoist:
* A corresponding Project is created in GitHub Issues. 
* 2 columns are added to the GitHub project (["To Do"](#to-do-column) and ["Comments"](#comments-column))

### Project State

The `state`  of a GitHub project depends on the state of the corresponding Todoist Project:

| Todoist Project state   | Corresponding GitHub Project state |
| ----------------------  | ---------------------------------- |
| Unarchived (ie. Normal) | `open`                             |
| Archived                | `closed`                           |
| Deleted                 | `closed`                           |

### "To Do" Column

The "To-Do" column contains a Project Card for every Issue that corresponds to a Task within the corresponding Todoist Project.
If the order of the Tasks is changed within the corresponding Todoist Project, then the order of the Issues within the "To Do" column are also changed to match (This is not implemented yet, [see this](https://github.com/movermeyer/ImportFromTodoist/issues/14)).

### "Comments" Column

The "Commments" column contains a Project Card for every Project comment that exists on the corresponding Todoist Project.
The order of the cards within the column match the order of the comments within Todoist.

### Other relationships

Other attributes of GitHub projects are kept in sync with their Todoist counterpart's. 
Changes made to these attributes in Todoist are replicated within the GitHub Project.

| [Todoist Project attribute](https://developer.todoist.com/sync/v7/#projects) | Corresponding [GitHub Project attribute](https://developer.github.com/v3/projects/#update-a-project) |
| ------------------------- | -------------------------------------- |
| Project Name (`name`)     | Project Name (`name`)                  |

## Labels

Whenever a Task is processed that has an associated Label, a corresponding Label is created in GitHub Issues\
Changes made to the Label's attributes in Todoist are replicated to the corresponding GitHub Label.

| [Todoist Label attribute](https://developer.todoist.com/sync/v7/#labels) | Corresponding [GitHub Label attribute](https://developer.github.com/v3/issues/labels/#update-a-label) |
| ------------------------- | -------------------------------------- |
| Label Name (`name`)       | Label Name (`name`)                    |
| Label Color (`color`)     | Label Name (`color`)                   |

### Non-uniqueness

Because there is no attribute to store the [ID Mapping Comment](#associating-objects-across-changes) in, if you change the name of a Label in Todoist, the existing Label in GitHub Issues will not be modified. Instead, a new Label with the new name will be created.

To prevent a possible proliferation of unused Labels in GitHub Issues, `import_from_todoist` deletes any Label in GitHub Issues that is no longer referenced from any Issue ( [Not implemented yet](https://github.com/movermeyer/ImportFromTodoist/issues/8)). 


## Comments

When you create a comment on a **task** in Todoist:
* A corresponding comment is created on the GitHub Issue associated with the task. 

When you create a comment on a **project** in Todoist:
* A "note" Project Card is added to the ["Comments" column](#comments-column) is of the GitHub Project associated with the Todoist Project. 

Changes made to the Label's attributes in Todoist are replicated to the corresponding GitHub Label.

| [Todoist Comment attribute](https://developer.todoist.com/sync/v7/#notes) | Corresponding [GitHub Issue Comment attribute](https://developer.github.com/v3/issues/comments/#edit-a-comment) | Corresponding [GitHub Project Card attribute](https://developer.github.com/v3/projects/cards/#update-a-project-card) |
| ------------------------- | -------------------------------------- | -------------------------------------- |
| Comment Content (`content`) | Comment Content (`body`)  | Card Content (`note`)                  |