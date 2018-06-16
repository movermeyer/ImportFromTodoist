# Introduction

There was not enough time to implement all the features needed for `import_from_todoist` to be considered complete.
Further, there are several refactorings that should be done in order to clean up code smells. 

This page will document the state of the project at the time of submission, and discuss areas that could be improved given more time.

Most of these can also be found in the [backlog in GitHub Issues](TODO:)

# Current State

Currently, `import_from_todoist` has nearly all the necessary functionality of a complete importer.

Implemented functionality:

* Import Tasks, Projects, and Comments from Todoist
* Idempotently update imported objects on successive runs

For a list of notable missing functionality, see the [README](README.md#missing-functionality)

I feel that each of these missing features are not core to the use To-Do App use case, but would have to be implemented for the project to be considered complete.

For an extensive list, see the [backlog in GitHub Issues](TODO:)

# Future Considerations


# Caching

Perhaps the biggest problem with the way the code is currently structured relates to the way caching is being done. It is currently being done in multiple places, in inconsistent ways.

The caching belongs in a layer that would sit between the [`System` and the `API Access Classes`](code_walkthrough.md#a-quick-note-about-caching)

Due to time constraints, I did not manage to refactor the caching into its own layer.

See [](TODO:) for details.

## Error Handling

(TODO: copy-paste from issue)

## Logging

Right now, `import_from_todoist` simply `puts` out all of its log messages to `stdout`. 

(TODO: reference 12 factor)

Given more time, I would research a logging library for Ruby and use it to add severity levels to the messages. That way users would have a mechanism for easily filtering the output. 

See TODO: Add link to issue

## Rate Limiting

## Internationalization i18n

Given more time, I would research an internationalization (i18n) gem/framework for Ruby and pull out all the user-facing strings so that users of any language can benefit from `import_from_todoist`. 

See [#18](https://github.com/movermeyer/ImportFromTodoist/issues/18)

## Scalability

### Bounded caches

As part of reworking how caching is done, bounding the amount of resources used for caching will help `import_from_todoist` scale beyond the limits of machine memory.

### Paging

More effort needs to be made to make use of paging mechanisms. While the Todoist API doesn't seem to offer any nice paging mechanisms, the GitHub API does.

## Performance

### Parallelism

Even with more time, I might not implement parallel processing without consideration. Parallelism is notoriously for adding complexing and maintenance overhead to code-bases. The fact that some processing steps of `import_from_todoist` require serial processing (ex. issue comments need to be added to issues in the same order) would mean that any potential performance gains from parallelism would be bounded by [Amdahl's Law](TODO: Add link). Without restruacturing the entire codebase (to use a pattern or framework specifically meant for this use case), and without a real-world use demand for it, I suspect the overhead would be too much.

# Fundamental re-architecting

Fundamentally, a large portion of this utility is very similar to an ORM. Ideally, you would have objects in memory that represent records in GitHub that you manipulate and then rely on the ORM layer to handle the caching, and orchestrate the operations needed to update the API.

While the use of such a technology would not likely save you anything in terms of lines of code written, it would likely add additional structure to the code and might be able to give you nice features "out of the box" (such as [parallelism](#parallelism) or rate limiting).

Given more time, I would research potential Ruby ORM or ETL frameworks and possibly rewrite portions of `import_from_todoist` to make use of them. This work might dove-tail nicely with [refactoring the way caching is done](#caching). 

(TODO: search for GitLab)