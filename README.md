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

- [Installation](#installation)
- [Usage](#usage)
  - Mock generation [`mock_create`](#mock_create)
  - Mock customization [`mock_set_status`](#mock_set_status), [`mock_set_output`](#mock_set_output) and [`mock_set_side_effect`](#mock_set_side_effect)
  - Mock observation [`mock_get_call_num`](#mock_get_call_num), [`mock_get_call_user`](#mock_get_call_user), [`mock_get_call_args`](#mock_get_call_args), [`mock_get_call_env`](#mock_get_call_env)
  - Path utilities [`path_prepend`](#path_prepend), [`path_rm`](#path_rm)
  - Mock environment [`mock_bin_dir`](#mock_bin_dir)
- [Contributing](#contributing)
- [About this fork](#about-this-fork)

## ⚙️ Installation

You can use **bats-mock** in two main ways, depending on how you organize your Bats tests:

1. As a Git submodule (project-local installation)
2. Installed into your system or user Bats library path

Both approaches require [Bats Core](https://github.com/bats-core/bats-core) to be installed and available in your `PATH`.

### Installation as a Git submodule (recommended for projects)

This is the most common setup when `bats-mock` is used within a project repository as `git submodule` and described in the [bats-core quick installation guide](https://bats-core.readthedocs.io/en/stable/tutorial.html#quick-installation).
It keeps the dependency version-controlled and local to your project.

```bash
# From your project root
git submodule add https://github.com/mh182/bats-mock.git test/test_helper/bats-mock
```

### Installation into the Bats library path

If you prefer to have bats-mock available globally for all Bats tests on your system or CI environment, you can install it into the Bats library path.

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

> **Note**: You may need to run `install_bats` with `sudo` if you do not have permission to write to `/usr/local`.

You can also install both Bats Core and bats-mock under a custom prefix (e.g., `$HOME/.local`):

```bash
# Install bats in $HOME/.local/bin
PREFIX=$HOME/.local ./script/install_bats

# Install bats-mock in $HOME/.local/lib
PREFIX=$HOME/.local ./build install
```

Finally make sure `BATS_LIB_PATH` points to the directory where the Bats libraries are located.  
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

`mock_bin_dir` with `path_rm` and `path_prepend` may be used in tests to mock a pristine system.

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

Creates a mock program with a unique name in `BATS_TEST_TMPDIR` and outputs its path.
The mock tracks calls and collects their properties.
The collected data is accessible using methods described below.

If `command` is provided a symbolic link with the given name is created and returned.

> **NOTE**  
> Combining `mock_command` and `path_prepend` may be used to supply custom executables for your tests.
>
> It is self-explanatory that this approach doesn't work for shell scripts with commands having hard-coded absolute paths.

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

Outputs `$PATH` with directories removed that contain the specified command or path.

- If a command name is provided, all directories in which that command can be found are removed.
- If an absolute path to the command is provided (e.g. `/usr/bin/ls`), only the directory containing that executable (e.g. `/usr/bin`) is removed.
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
The call indexing starts with `1`. Multiple invocations can be used to mimic complex status sequences.

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

mock_bin_dir [cmd...]

Creates a directory containing the most basic commands found on a system and outputs its path.
The commands are symbolic links to the system provided programs.
A list of space separated commands may be provided to define a more strict set of commands.
`mock_create <command>` puts the mocked command in the same directory as provided with `mock_bin_dir`.

## Contributing

If you want to contribute to this project check out [Contributing](CONTRIBUTING.md).

## About this fork

This repository is a **maintained fork** of [grayhemp/bats-mock](https://github.com/grayhemp/bats-mock) at commit [48fce74](https://github.com/grayhemp/bats-mock/commit/48fce74482a4d2bb879b904ccab31b6bc98e3224).
The original project appears to be **unmaintained** — the last commit was made over four years ago at the time of forking.

This fork was created to:

- Maintain compatibility with newer versions of [Bats](https://github.com/bats-core/bats-core)
- Apply fixes and quality improvements as needed
- Ensure continued availability for projects that depend on `bats-mock`

We highly appreciate the original author’s work and intend to **reintegrate changes upstream** if the original repository becomes active again.  
This fork’s goal is to preserve and maintain the library for the community, not to diverge unnecessarily.

## Copyright

bats-mock is [public domain](http://en.wikipedia.org/wiki/Public_Domain).
For more information, please refer to <https://unlicense.org/>.

<!-- Links -->

[bats-core]: https://github.com/bats-core/bats-core
