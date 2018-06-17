Hello,

I ran out of time in my 1.5 week project sprint. To give you an example of what I usually write, [here is an example](https://github.com/closeio/ciso8601/blob/master/CONTRIBUTING.md) of a CONTRIBUTING file that I wrote for another project I manage.

A pull request would be welcome for this. See [this issue](https://github.com/movermeyer/ImportFromTodoist/issues/1).

----

<!-- Generated with "Markdown T​O​C" extension for Visual Studio Code -->
<!-- TOC -->

- [Testing](#testing)
    - [Testing Dependencies](#testing-dependencies)
    - [Test Directory Structure](#test-directory-structure)
    - [Running the Tests](#running-the-tests)

<!-- /TOC -->

# Testing

## Testing Dependencies
The tests use the `minitest` gem. You can install the testing gems using bundler:

```
bundler install
```

## Test Directory Structure
Tests are stored in the `test` directory. The directory structure mirrors that of the `lib` directory.

## Running the Tests
Install the 

Running the tests is done by running each of the test files:

```
ruby test/import_from_todoist/system_test.rb
ruby test/import_from_todoist/todoist/label_test.rb
```

There is likely an easier way to find and run all the tests with one command (similar to Python's test runners), bt being new to Ruby, I ran out of time and didn't learn of it. If you know how to do this, feel free to submit a PR to this document.

