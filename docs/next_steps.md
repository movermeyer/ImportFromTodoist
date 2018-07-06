# Introduction

There are more features needed for `import_from_todoist` to be considered complete.
Further, there are several refactorings that should be done in order to clean up code smells. 

This page will document the state of the project at the time of submission, and discuss areas that could be improved given more time.

Most of these can also be found in the [backlog in GitHub Issues](https://github.com/movermeyer/ImportFromTodoist/issues)

<!-- Generated with "Markdown T​O​C" extension for Visual Studio Code -->
<!-- TOC -->

- [Introduction](#introduction)
- [Current State](#current-state)
- [Future Considerations](#future-considerations)
    - [Caching](#caching)
    - [Error Handling](#error-handling)
    - [Logging](#logging)
    - [More Complete Tests](#more-complete-tests)
    - [Rate Limiting](#rate-limiting)
    - [Usability](#usability)
        - [Ease of installation](#ease-of-installation)
        - [Internationalization (i18n)](#internationalization-i18n)
    - [Scalability](#scalability)
        - [Bounded caches](#bounded-caches)
        - [Paging](#paging)
    - [Performance](#performance)
        - [Parallelism](#parallelism)
- [Fundamental re-architecting](#fundamental-re-architecting)

<!-- /TOC -->

# Current State

Currently, `import_from_todoist` has nearly all the necessary functionality of a complete importer.

Implemented functionality:

* Imports all the major Todoist objects ([Tasks, Projects, Comments, and Labels](#data_mapping.md)) into GitHub Issues
* Idempotently updates imported objects on successive runs

For a list of notable missing functionality, see the [README](../README.md#missing-functionality)

I feel that each of these missing features are not core to the To-Do App use case, but would have to be implemented for the project to be considered complete.

For an extensive list, see the [backlog in GitHub Issues](https://github.com/movermeyer/ImportFromTodoist/issues)

# Future Considerations

## Caching

Perhaps the biggest problem with the current codebase is the way caching is being done. It is currently being done in multiple places, and in inconsistent ways.

The caching belongs in a layer that would sit between the [`System` and the `API Access Classes`](code_walkthrough.md#a-quick-note-about-caching)

Due to time constraints, I did not manage to refactor the caching into its own layer.

See [Issue #20](https://github.com/movermeyer/ImportFromTodoist/issues/20) for details.

## Error Handling

Currently, `import_from_todoist` assumes that every network request will always succeed.

This is obviously not the case. Every network request could fail in any one of many ways, at almost any layer of the OSI model.

Things to do:
- Protect against intermittent network failures
- Protect against remote server issues (ex. `5xx` status codes)
- Protect against rate limit exceptions (See [Issue #15](https://github.com/movermeyer/ImportFromTodoist/issues/15))
- Error loudly on anything else other than successful status code

See [Issue #22](https://github.com/movermeyer/ImportFromTodoist/issues/22).

## Logging

Currently, `import_from_todoist` simply dumps all its messages to `stdout` via Ruby's `puts` operation.

There is nothing inherently wrong with writing all your messages to `stdout` (this is one of the [12 factors](https://12factor.net/) after all). But there should still be some mechanism that allows for filtering of this message stream.

Given more time, I would research a logging library for Ruby and use it to add severity levels to the messages. That way users would have a mechanism for easily filtering the output. 

See [Issue #19](https://github.com/movermeyer/ImportFromTodoist/issues/19).

## More Complete Tests

While `import_from_todoist` has tests that cover some of the objects, due to time constraints not all objects received the same testing budget.

Given more time, I would extend the tests to cover all of the classes. Further, I would integrate some CI/CD test runner (likely CircleCI or TravisCI) to run the tests against every pull request. See [Issue #13](https://github.com/movermeyer/ImportFromTodoist/issues/13)

In this same vein, once I had a deeper understanding of Ruby, I would integrate the Ruby linters into the CI/CD pipeline in order to help ensure a consistent code style. While I made use of [numerous Ruby linters](https://github.com/rubyide/vscode-ruby#linters) during the development of `import_from_todoist`, some of them are overly zealous and would have to be configured carefully before allowing them to force a build failure.

Finally I would integrate a security dependency vulnerability scanner into the CI/CD workflow. See [Issue #12](https://github.com/movermeyer/ImportFromTodoist/issues/12)

## Rate Limiting

Both [Todoist](https://developer.todoist.com/sync/v7/#limits24) and [GitHub](https://developer.github.com/v3/rate_limit/) enforce rate limits on API access.

`import_from_todoist` should be made to respect customizable rate limits, with default rate limits matching the rates prescribed in the API docs. 

`import_from_todoist` also needs to be able to understand how to "back off" in the case of the limits changing or in the face of soft limits.

See [Issue #15](https://github.com/movermeyer/ImportFromTodoist/issues/15)

## Usability

### Ease of installation

While `import_from_todoist` should be easy for Ruby developers to run, it is considerably more difficult to run for other users.

Even non-Ruby developers will have a harder time, if only because they have to install and learn to use tooling like `bundler`.

Non-developer users have a very limited chance of being able to make use of `import_from_todoist`.

Given more time, work could be done to change the way that the user interacts with the utility.

It seems likely that it would make sense to refactor the utility to be a [GitHub App](https://developer.github.com/v3/apps/), and possibly integrate it as a [Todoist Applet/Integration](https://support.todoist.com/hc/en-us/sections/115001108265-Integrations). By adding a web UI and hosting it in the cloud, `import_from_todoist` could be dramatically simpler to use.
This route was considered at the outset of the project, but was rejected due to the time constraints imposed by having to learn Ruby.

### Internationalization (i18n)

Given more time, I would research an internationalization (i18n) gem/framework for Ruby and pull out all the user-facing strings so that users of any language can benefit from `import_from_todoist`. 

See [#18](https://github.com/movermeyer/ImportFromTodoist/issues/18)

## Scalability

### Bounded caches

As part of reworking how caching is done, bounding the amount of resources used for caching will help `import_from_todoist` scale beyond the limits of machine memory.

### Paging

More effort needs to be made to make use of paging mechanisms. While the Todoist API doesn't seem to offer any nice paging mechanisms, the GitHub API does.

## Performance

### Parallelism

Even with more time, I might not implement parallel processing without consideration. Parallelism is notoriously for adding complexing and maintenance overhead to code-bases. The fact that some processing steps of `import_from_todoist` require serial processing (ex. issue comments need to be added to issues in the same order) would mean that any potential performance gains from parallelism would be bounded by [Amdahl's Law](https://en.wikipedia.org/wiki/Amdahl%27s_law). Without restructuring the entire codebase (to use a pattern or framework specifically meant for this use case), and without a real-world use demand for it, I suspect the overhead would be too much.

# Fundamental re-architecting

Fundamentally, a large portion of this utility is very similar to an ORM. Ideally, you would have objects in memory that represent records in GitHub that you manipulate and then rely on the ORM layer to handle the caching, and orchestrate the operations needed to update the API.

While the use of such a technology would not likely save you anything in terms of lines of code written, it would likely add additional structure to the code and might be able to give you nice features "out of the box" (such as [parallelism](#parallelism) or rate limiting).

Given more time, I would research potential Ruby ORM or ETL frameworks and possibly rewrite portions of `import_from_todoist` to make use of them. This work might dove-tail nicely with [refactoring the way caching is done](#caching).
