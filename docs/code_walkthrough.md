<!-- Generated with "Markdown T​O​C" extension for Visual Studio Code -->
<!-- TOC -->

- [Code Walkthrough](#code-walkthrough)
    - [Introduction](#introduction)
    - [Overview](#overview)
    - [cli.rb](#clirb)
    - [importer.rb](#importerrb)
    - [Object classes](#object-classes)
    - [API Access Classes](#api-access-classes)
        - [A quick note about caching](#a-quick-note-about-caching)
    - [system.rb](#systemrb)
- [TODO: Rename system.](#todo-rename-system)
- [TODO: Add section on testing](#todo-add-section-on-testing)

<!-- /TOC -->

# Code Walkthrough

## Introduction

This document will give you an overview of how the code is structured, as well as the general flow of execution.

**Note**: This page documents the code **as it is** (at the time of submission for evaluation). The current codebase does not have the cleanest separation of concerns, and at times this document may point that out. See [Next Steps](next_steps.md) for some discussion of potential refactoring work.  

## Overview



## cli.rb

This is the entry-point for `import_from_todoist`, and the script that handles user interaction. It parses and validates the command-line arguments that the user provides, before calling `Importer.sync` to start the processing.

## importer.rb

This file describes the high-level operations that are being done to sync the state of GitHub Issues with the Todoist state. The goal of this file was to be very readable, allowing a developer to read the high-level concepts without having to know anything about how it works. It relies heavily on [`system.rb`](#systemrb) to achieve this.

## Object classes

The `lib/import_from_todoist/todoist` and `lib/import_from_todoist/github` directories contain files that describe classes to represent the different objects within Todoist and GitHub Issues (respectively):

## API Access Classes

There are also files that contain classes for accessing each of the APIs:

* Todoist API: `Api` ([`api.rb`](https://github.com/movermeyer/ImportFromTodoist/blob/master/lib/import_from_todoist/todoist/api.rb))
* GitHub API: `Repo` ([`repo.rb`](https://github.com/movermeyer/ImportFromTodoist/blob/master/lib/import_from_todoist/github/repo.rb))

These classes handle all of the interactions with their respective APIs. They are the gatekeepers of network access.

Access to the Todoist API is entirely **read-only**. Access to the GitHub API is both read and write.

It is their responsibility to isolate all the quirks of the APIs, the network error handling, and the rate-limiting logic from the rest of the application.

### A quick note about caching
Caching of objects to avoid unnecessary network requests is an area of the codebase that wasn't well implemented.
Some of the caching is done in memory, while some is written to disk. The responsibility of caching was not well encapsulated, so there is caching of objects in both these API access classes, as well as in [`system.rb`](#systemrb). In an ideal implementation (and if I had more time), the caching would be done be a separate "caching layer" that sat between `system.rb` and the API accessors. 

## system.rb

This file contains all of the "business logic" of how to process Todoist objects to sync the state in GitHub Issues.
It makes use of all the 

The interface it exposes to the [`Importer`](#importerrb) mirrors the objects in GitHub so `Importer` can simply declare the objects that it wants to ensure are synced in GitHub Issues, leaving `System` to make sure it happens. 

`System` uses the [Object classes](#object-classes) to build the desired GitHub objects from the Todoist objects, and makes the call to the [API access classes](#api-access-classes) to create or update the state in GitHub Issues.

As [mentioned above](#a-quick-note-about-caching), the current code has `System` doing caching that it shouldn't be. This would be moved into the caching layer if refactored.


#TODO: Rename system.

#TODO: Add section on testing