# bats-mock

[![Tests](https://github.com/mh182/bats-mock/actions/workflows/tests.yml/badge.svg)](https://github.com/mh182/bats-mock/actions/workflows/tests.yml)

A [Bats][bats-core] helper library providing mocking functionality.

```bash
load bats-mock

@test "postgres.sh starts Postgres" {
  mock="$(mock_create)"
  mock_set_side_effect "${mock}" "echo $$ > /tmp/postgres_started"

  # Assuming postgres.sh expects the `_POSTGRES` variable to define a
  # path to the `postgres` executable
  _POSTGRES="${mock}" run postgres.sh

  [[ "${status}" -eq 0 ]]
  [[ "$(mock_get_call_num ${mock})" -eq 1 ]]
  [[ "$(mock_get_call_user ${mock})" = 'postgres' ]]
  [[ "$(mock_get_call_args ${mock})" =~ -D\ /var/lib/postgresql ]]
  [[ "$(mock_get_call_env ${mock} PGPORT)" -eq 5432 ]]
  [[ "$(cat /tmp/postgres_started)" -eq "$$" ]]
}
```

For changes and version history see [CHANGELOG](CHANGELOG.md).

## Table of contents

- [Tutorial](#tutorial-using-bats-mock-for-test-driven-development-in-bash)
  - [Quick installation](#quick-installation)
  - [Writing the first mock test](#writing-the-first-mock-test)
  - [Make the test pass](#make-the-test-pass)
  - [Mocking a failure](#mocking-a-failure)
  - [Testing in a deterministic setup](#testing-in-a-deterministic-setup)
- [Installation](#installation)
- [Usage](#usage)
  - Mock generation [`mock_create`](#mock_create)
  - Mock customization [`mock_set_status`](#mock_set_status), [`mock_set_output`](#mock_set_output), and
    [`mock_set_side_effect`](#mock_set_side_effect)
  - Mock observation [`mock_get_call_num`](#mock_get_call_num), [`mock_get_call_user`](#mock_get_call_user),
    [`mock_get_call_args`](#mock_get_call_args), and [`mock_get_call_env`](#mock_get_call_env)
  - Path utilities [`path_prepend`](#path_prepend), [`path_rm`](#path_rm)
  - Mock environment [`mock_bin_dir`](#mock_bin_dir)

- [Contributing](#contributing)
- [About this fork](#about-this-fork)

## Tutorial: Using `bats-mock` for Test-Driven Development in Bash

In this tutorial, we’ll explore how to use `bats-mock`
to build and test a simple Bash script
that downloads a file from a given URL and saves it locally —
all in a **test-driven** and **side-effect-free** way.

When developing shell scripts,
we often depend on external commands or services —
for example, downloading a file with `curl`, copying files with `cp`,
or interacting with APIs.
In testing, directly invoking these real commands can lead to
**slow**, **fragile**, or even **destructive** tests.
This is where _mocks_ come in.

**Mocks** are simulated implementations of real commands
or functions that allow us to:

- Replace external dependencies with controllable stand-ins.
- Test scripts in isolation without requiring real infrastructure.
- Avoid unwanted side effects
  such as file system modifications or network calls.
- Verify how commands are called —
  including arguments, call counts, and execution order.

If you’re new to the concept of mocks,
the following resources offer great introductions:

- [_Mocks Aren’t Stubs_ by Martin Fowler](https://martinfowler.com/articles/mocksArentStubs.html)
- [_Test Doubles_ (xUnit Patterns)](http://xunitpatterns.com/Test%20Double%20Patterns.html)

### Quick installation

First, we’ll set up a minimal Bash project
and install the tools we need for testing:
`bats` along with its helper libraries, and `bats-mock`.

We’ll use a very simple project structure, shown below:

```text
tutorial/
├── src
└── test
    ├── bats
    └── test_helper
        ├── bats-assert
        ├── bats-file
        ├── bats-mock
        └── bats-support
```

Initialize the project

```bash
mkdir -p tutorial/{src,test}
cd tutorial
git init
```

Install `bats` and `bats-mock` as Git submodules and verify the setup

```bash
git submodule add https://github.com/bats-core/bats-core.git test/bats
git submodule add https://github.com/bats-core/bats-support test/test_helper/bats-support
git submodule add https://github.com/bats-core/bats-assert test/test_helper/bats-assert
git submodule add https://github.com/bats-core/bats-file test/test_helper/bats-file
git submodule add https://github.com/mh182/bats-mock test/test_helper/bats-mock

# Create alias to simplify the call to bats
alias bats=$PWD/test/bats/bin/bats
# Verify setup
bats --version
Bats 1.13.0
```

### Writing the first mock test

We’ll start our development in a **test-driven** way:
by writing a failing test before we implement the functionality.
Our goal is to test a small Bash script, `download.bash`,
that downloads a file from a given URL and stores it at a specific location.

At this point, the `src/download.bash` file doesn’t exist yet — and that’s fine!
We’ll begin by writing a test that describes what we expect the script to do.

Create `test/download.bats` with the following content:

```bash
#!/usr/bin/env bats

# We use 'run' with flags, otherwise Bats will complain with a warning.
bats_require_minimum_version 1.5.0

# Load Bats helper libraries for assertions and file operations
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-file/load'

# Load Bats Mock library for mocking commands
load 'test_helper/bats-mock/load'

setup() {
  # Get the containing directory of this file. Use $BATS_TEST_FILENAME instead
  # of ${BASH_SOURCE[0]} or $0, as those will point to the bats executable's
  # location or the preprocessed file respectively.
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  # Make executables in src/ visible to PATH
  PATH=$(path_prepend "${DIR}/../src")

  # Set the path to mocked binaries directory as the first location in PATH to
  # lookup in mock directories first. This change lives only for the duration of
  # the test and will be reset after. It does not modify the PATH outside of the
  # running test.
  PATH=$(path_prepend "${BATS_TEST_TMPDIR}")

  # Create a temporary directory for downloads
  TMP_DIR="${BATS_TEST_TMPDIR}/downloads"
  mkdir -p "${TMP_DIR}"

  # The target file we expect to be downloaded
  target="${TMP_DIR}/file.txt"
}

@test "downloads a file from URL and stores it at target location" {
  # Arrange - create a mock for curl
  mock_curl=$(mock_create curl)

  # When our script calls 'curl', we don't actually want to download anything.
  # Instead, the mock will simulate this by creating the target file.
  mock_set_side_effect "${mock_curl}" "echo 'Mock download successful' > '${target}'"

  # Act
  download.bash "https://example.com/file.txt" "${target}"

  # Assert
  assert_file_exists "${target}"
  grep -q "Mock download successful" "${target}"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 1
}
```

Now run the test.
Since the `download.bash` script isn't implemented yet,
this test fails as expected.

```bash
➜ bats test/
download.bats
 ✗ downloads a file from URL and stores it at target location
   (in test file test/download.bats, line 42)
     `download.bash "https://example.com/file.txt" "${target}"' failed with status 127
   $TUTORIAL_DIR/tutorial/test/download.bats: line 42: download.bash: command not found

1 test, 1 failure
```

### Make the test pass

With our first failing test in place,
we’ll now implement the minimal functionality required to make it pass.

Create the file `src/download.bash` with the following content:

```bash
#!/usr/bin/env bash
#
# download.bash — download a file from a URL and store it at a target location.

set -euo pipefail

main() {
    local url=$1
    local target=$2

    if [[ -z "${url}" || -z "${target}" ]]; then
        echo "Usage: $(basename "$0") <url> <target>" >&2
        exit 1
    fi

    curl -fsSL "${url}" -o "${target}"
}

main "$@"
```

Make the script executable and run the test again.

```bash
chmod +x src/download.bash

bats test
download.bats
 ✓ downloads a file from URL and stores it at target location

1 test, 0 failures
```

If you still see a failure,
ensure that the mock directory is at the beginning of your PATH
so that the test uses the mocked `curl` instead of the system one.

### Mocking a failure

Now that the happy path works,
let’s add a test for the case when the download fails —
for example, when `curl` returns an error code.

Create a new test in `test/download.bats`:

```bash
@test "fails when curl returns an error" {
  # Arrange
  mock_curl=$(mock_create curl)

  # Simulate curl failure
  mock_set_status "${mock_curl}" 22
  mock_set_output "${mock_curl}" "curl: (22) The requested URL returned error: 404 Not Found" >&2

  # Act - expect failure
  run -22 src/download.bash "https://example.com/missing.txt" "${target}"

  # Assert
  assert_output --partial "curl: (22) The requested URL returned error: 404 Not Found"
}
```

The new test passes immediately since `src/download.bash` runs with `set -e`,
which propagates the mocked failure and causes the script to exit.

`curl` default behavior on a non existing URL (404) is
to download the web-page showing the "404 Not Found" error
and return a 0 exit code.
`curl` only returns exit code 22 when the `--fail` or `-f` flag is used.

This means the test would pass
even if the real implementation forgot to use `-f` —
meaning our test would validate the wrong behavior.

This demonstrates a common risk when using mocks:
they can give a false sense of correctness
if they don’t accurately represent the real command’s behavior.

Lets add a test that verifies the arguments passed to `curl`
to ensure we are calling it correctly.

```bash
@test "curl is called with correct arguments" {
  # Arrange
  mock_curl=$(mock_create curl)
  url="https://example.com/file.txt"

  # Act - expect failure
  run download.bash "${url}" "${target}"

  assert_equal "$(mock_get_call_args "${mock_curl}")" "-fsSL ${url} -o ${target}"
}
```

### Testing in a deterministic setup

So far, our tests relied on the assumption that `curl` exists
and behaves as expected.  
However, tests should always be **deterministic** —
producing the same result regardless of the host system setup.

A deterministic setup ensures that:

- Environment differences (e.g., missing tools) don’t affect tests.
- Behavior depending on command availability can be verified explicitly.

To demonstrate this, let’s extend our script so
it uses `wget` as a fallback if `curl` isn’t available —
but first, we’ll express that expectation as a failing test.

Add a new test case in `test/download.bats`
which mocks an environment with no `curl` but installed `wget`.

```bash
@test "uses wget when curl is not available" {
  # Arrange

  # Populate $BATS_TEST_TMPDIR with minimal set of executables.
  # Note: we already added $BATS_TEST_TMPDIR to $PATH in setup().
  _=$(mock_bin_dir)

  # Create mock for wget and set side effect
  mock_wget=$(mock_create wget)
  mock_set_side_effect "${mock_wget}" "echo \"Mock wget download successful\" > \"${target}\""

  # Create PATH where curl isn't accessible → simulates curl not installed
  path_without_curl=$(path_rm curl)

  # Act - use modified PATH without curl
  PATH=${path_without_curl} run download.bash "https://example.com/file.txt" "${target}"

  # Assert
  grep -q "Mock wget download successful" "${target}"
  assert_equal "$(mock_get_call_num "${mock_wget}")" 1
}
```

The test fails since we haven't implemented the fallback to `wget` yet.

```bash
➜ bats test
download.bats
 ✓ downloads a file from URL and stores it at target location
 ✓ fails when curl returns an error
 ✓ curl is called with correct arguments
 ✗ uses wget when curl is not available
   (in test file test/download.bats, line 98)
     `grep -q "Mock wget download successful" "${target}"' failed with status 2
   grep: /tmp/bats-run-g25kpJ/test/4/downloads/file.txt: No such file or directory

4 tests, 1 failure


The following warnings were encountered during tests:
BW01: `run`'s command `download.bash https://example.com/file.txt /tmp/bats-run-g25kpJ/test/4/downloads/file.txt` exited with code 127, indicating 'Command not found'. Use run's return code checks, e.g. `run -127`, to fix this message.
      (from function `run' in file test/bats/lib/bats-core/test_functions.bash, line 420,
       in test file test/download.bats, line 95)
```

Modify `src/download.bash` and add the desired behavior.

```bash
#!/usr/bin/env bash
#
# download.bash — download a file from a URL and store it at a target location.

set -euo pipefail

download_file() {
  local url=$1
  local target=$2

  if [[ -z "${url}" || -z "${target}" ]]; then
    echo "Usage: $(basename "$0") <url> <target>" >&2
    return 1
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${target}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${target}" "${url}"
  else
    echo "Error: neither curl nor wget is available" >&2
    return 1
  fi
}

main() {
  download_file "$@"
}

main "$@"
```

All tests are passing — and with this setup in place,
you're ready to keep developing Bash scripts safely,
confidently, and without surprises.

```bash
➜ bats test
download.bats
 ✓ downloads a file from URL and stores it at target location
 ✓ fails when curl returns an error
 ✓ curl is called with correct arguments
 ✓ uses wget when curl is not available

4 tests, 0 failures
```

## Installation

You can use **bats-mock** in two main ways,
depending on how you organize your Bats tests:

1. As a Git submodule (project-local installation)
2. Installed into your system or user Bats library path

Both approaches require [Bats Core](https://github.com/bats-core/bats-core)
to be installed and available in your `PATH`.

### Installation as a Git submodule (recommended for projects)

This is the most common setup
when `bats-mock` is used within a project repository as `git submodule`
and described in the [bats-core quick installation guide](https://bats-core.readthedocs.io/en/stable/tutorial.html#quick-installation).
It keeps the dependency version-controlled and local to your project.

```bash
# From your project root
git submodule add https://github.com/mh182/bats-mock.git test/test_helper/bats-mock
```

### Installation into the Bats library path

If you prefer to have bats-mock available globally
for all Bats tests on your system or CI environment,
you can install it into the Bats library path.

First, clone the repository:

```bash
git clone https://github.com/mh182/bats-mock.git
cd bats-mock
```

Then, install [Bats][bats-core] if it's not already available:

```bash
# Install bats-core in /usr/local (may require sudo)
./script/install_bats
```

> **Note**: You may need to run `install_bats` with `sudo`
> if you do not have permission to write to `/usr/local`.

You can also install both Bats Core
and bats-mock under a custom prefix (e.g., `$HOME/.local`):

```bash
# Install bats in $HOME/.local/bin
PREFIX=$HOME/.local ./script/install_bats

# Install bats-mock in $HOME/.local/lib
PREFIX=$HOME/.local ./build install
```

Finally make sure `BATS_LIB_PATH` points to the directory
where the Bats libraries are located.  
Following our example above:

```bash
export BATS_LIB_PATH=$HOME/.local/lib
```

Now your tests can simply load the library by name:

```bash
bats_load_library bats-mock

@test "Create a simple mock object" {
  mock=$(mock_create)

  ${mock}

  [[ $(mock_get_call_num "${mock}") -eq 1 ]]
}
```

`mock_bin_dir` with `path_rm` and `path_prepend` may be used in tests
to mock a pristine system.

```bash
load bats-mock

@test "no HTTP download program installed shows error message" {
 # Mock a system where neither curl, wget, nor fetch is installed
 mock_pristine_system=$(mock_bin_dir)

 # Create a PATH so that system installed commands are not found
 path=$(path_prepend "${mock_pristine_system}" $(path_rm /bin $(path_rm /usr/bin)))

 # Execute the shell script under test
 # Provide the created PATH so we mock a pristine system with no download commands installed
 PATH="${path}" run install-fancy-app.sh

 [[ "${status}" -eq 1 ]]
 [[ "${output}" == "Error: couldn't find HTTP download program"]]
}
```

## Usage

### `mock_create`

```bash
mock_create [<command>]
```

Creates a mock program with a unique name in `BATS_TEST_TMPDIR`
and outputs its path.
The mock tracks calls and collects their properties.
The collected data is accessible using methods described below.

If `command` is provided a symbolic link with the given name is created
and returned.

> **NOTE**  
> Combining `mock_command` and `path_prepend` may be used
> to supply custom executables for your tests.
>
> It is self-explanatory that this approach doesn't work for shell scripts
> with commands having hard-coded absolute paths.

```bash
setup() {
  # Set the path to mocked binaries directory as the first location in PATH to
  # lookup in mock directories first. This change lives only for the duration of
  # the test and will be reset after. It does not modify the PATH outside of the
  # running test.
  PATH=$(path_prepend "${BATS_TEST_TMPDIR}")

  # NOTE: no cleanup since all mocks are created in ${BATS_TEST_TMPDIR}
}

@test "mock call to wget" {
  _=$(mock_create wget)

  # Calls the mock instead of the system installed wget
  wget
  [[ $(mock_get_call_num "${mock}") -eq 1 ]]
}
```

### `path_prepend`

```bash
path_prepend <mock | command | path_to_add> [path]
```

Outputs `$PATH` prefixed with the mocked command's directory.
If the directory is already part of `$PATH` nothing is done.

Works regardless if the provided mock is a file, link or a directory.

Use `path` instead of `$PATH` if specified.

### `path_rm`

```bash
path_rm <command | path_to_remove> [path]
```

Outputs `$PATH` with directories removed
that contain the specified command or path.

- If a command name is provided,
  all directories in which that command can be found are removed.
- If an absolute path to the command is provided (e.g. `/usr/bin/ls`),
  only the directory containing that executable (e.g. `/usr/bin`) is removed.
- If an absolute path is provided, the given path is removed.

Use `path` instead of `$PATH` if specified.

If a relative path is provided, the function exits with an error.

### `mock_set_status`

```bash
mock_set_status <mock> <status> [<n>]
```

Sets the exit status of the mock.

`0` status is set by default when mock is created.

If `n` is specified the status will be returned on the `n`-th call.
The call indexing starts with `1`.
Multiple invocations can be used to mimic complex status sequences.

### `mock_set_output`

```bash
mock_set_output <mock> (<output>|-) [<n>]
```

Sets the output of the mock. The mock outputs nothing by default.

If the output is specified as `-` then it is going to be read from `STDIN`.

The optional `n` argument behaves similarly to the one of `mock_set_exit_code`.

### `mock_set_side_effect`

```bash
mock_set_side_effect <mock> (<side_effect>|-) [<n>]
```

Sets the side effect of the mock. The side effect is a bash code to be
sourced by the mock when it is called.

No side effect is set by default.

If the side effect is specified as `-` then it is going to be read from `STDIN`.

The optional `n` argument behaves similarly to the one of `mock_set_exit_code`.

### `mock_get_call_num`

```bash
mock_get_call_num <mock>
```

Returns the number of times the mock was called.

### `mock_get_call_user`

```bash
mock_get_call_user <mock> [<n>]
```

Returns the user the mock was called with the `n`-th time. If no `n`
is specified then assuming the last call.

It requires the mock to be called at least once.

### `mock_get_call_args`

```bash
mock_get_call_args <mock> [<n>]
```

Returns the arguments line the mock was called with the `n`-th time.
If no `n` is specified then assuming the last call.

It requires the mock to be called at least once.

### `mock_get_call_env`

```bash
mock_get_call_env <mock> <variable> [<n>]
```

Returns the value of the environment variable the mock was called with
the `n`-th time. If no `n` is specified then assuming the last call.

It requires the mock to be called at least once.

### `mock_bin_dir`

```bash
mock_bin_dir [cmd...]
```

Creates a directory containing the most basic commands found on a system
and outputs its path.
The commands are symbolic links to the system provided programs.
A list of space separated commands may be provided
to define a more strict set of commands.
Any command created using `mock_create <command>`
will be placed inside the directory produced by `mock_bin_dir`,
ensuring that your mocked commands override the linked system commands.

## Contributing

If you want to contribute to this project
check out [Contributing](CONTRIBUTING.md).

## About this fork

This repository is a **maintained fork** of
[grayhemp/bats-mock](https://github.com/grayhemp/bats-mock) at commit [48fce74](https://github.com/grayhemp/bats-mock/commit/48fce74482a4d2bb879b904ccab31b6bc98e3224).
The original project appears to be **unmaintained** —
the last commit was made over four years ago at the time of forking.

This fork was created to:

- Maintain compatibility with newer versions of [Bats](https://github.com/bats-core/bats-core)
- Apply fixes and quality improvements as needed
- Ensure continued availability for projects that depend on `bats-mock`

We highly appreciate the original author’s work
and intend to **reintegrate changes upstream**
if the original repository becomes active again.  
This fork’s goal is to preserve and maintain the library for the community,
not to diverge unnecessarily.

## Copyright

bats-mock is [public domain](https://en.wikipedia.org/wiki/Public_Domain).
For more information, please refer to <https://unlicense.org/>.

<!-- Links -->

[bats-core]: https://github.com/bats-core/bats-core
