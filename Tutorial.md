# Using `bats-mock` for Test-Driven Development in Bash

In this tutorial, we’ll explore how to use [`bats-mock`](README.md)
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

## Quick installation

This tutorial starts with a minimal project layout:

```text
tutorial/
├── src
└── test
```

Initialize the project:

```bash
mkdir -p tutorial/{src,test}
cd tutorial
git init
```

The easiest way to run Bats tests is to use a container image
that already includes Bats, helper libraries, and bats-mock.
This avoids relying on a local Bats installation.

To build the image,
clone this repository to get the Containerfile and build scripts.

```bash
git clone https://github.com/mh182/bats-mock.git
(cd bats-mock && docker build -f Containerfile -t bats-mock:latest .)
rm -rf bats-mock
```

Create a `bats` alias that runs tests through the container image.

```sh
# Create an alias to simplify calling bats
alias bats='docker run --rm -it -v "$PWD:/code" -w /code bats-mock:latest'
```

If you cannot use containers, or prefer not to,
use the submodule-based setup below.

```sh
# In your project root
git submodule add https://github.com/bats-core/bats-core.git test/bats
git submodule add https://github.com/bats-core/bats-support test/test_helper/bats-support
git submodule add https://github.com/bats-core/bats-assert test/test_helper/bats-assert
git submodule add https://github.com/bats-core/bats-file test/test_helper/bats-file
git submodule add https://github.com/mh182/bats-mock test/test_helper/bats-mock

# Create an alias to simplify calling bats
alias bats=$PWD/test/bats/bin/bats
# Provide location of helper libraries, used by bats_load_library
export BATS_LIB_PATH=$PWD/test/test_helper
```

If you use the submodule fallback, your project structure becomes:

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

Verify your `bats` setup.

```bash
bats --version
Bats 1.13.0
```

After verifying that `bats` is available,
create `test/verify-setup.bats`
to validate that all helper libraries can be loaded,
including `bats-mock`:

```bash
cat > test/verify-setup.bats <<EOF
#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-mock

@test "verify bats_load_library bats-mock" {
  mock_echo="\$(mock_create echo)"

  run "\${mock_echo}" "hello"

  assert_success
  assert_equal "\$(mock_get_call_num "\${mock_echo}")" 1
}
EOF

chmod +x test/verify-setup.bats
```

Run this test file to verify the setup end-to-end:

```bash
bats test
verify-setup.bats
 ✓ verify bats_load_library bats-mock

1 test, 0 failures
```

If the test passes, you are ready to start the tutorial.

## Writing the first mock test

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
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file

# Load Bats Mock library for mocking commands
bats_load_library bats-mock

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
   $TUTORIAL_DIR/tutorial/test/download.bats: line 46: download.bash: command not found

1 test, 1 failure
```

## Make the test pass

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

```sh
chmod +x src/download.bash

# Run the tests
bats test
download.bats
 ✓ downloads a file from URL and stores it at target location

1 test, 0 failures
```

If you still see a failure,
ensure that the mock directory is at the beginning of your PATH
so that the test uses the mocked `curl` instead of the system one.

## Mocking a failure

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

```sh
bats test
download.bats
 ✓ downloads a file from URL and stores it at target location
 ✓ fails when curl returns an error

2 tests, 0 failures
```

`curl` default behavior on a non-existing URL (404) is
to download the web-page showing the "404 Not Found" error
and return a 0 exit code.
`curl` only returns exit code 22 when the `--fail` or `-f` flag is used.

This means the test would pass
even if the real implementation forgot to use `-f` —
meaning our test would validate the wrong behavior.

This demonstrates a common risk when using mocks:
they can give a false sense of correctness
if they don’t accurately represent the real command’s behavior.

Let's add a test that verifies the arguments passed to `curl`
to ensure we are calling it correctly.

```bash
@test "curl is called with correct arguments" {
  # Arrange
  mock_curl=$(mock_create curl)
  url="https://example.com/file.txt"

  # Act - expect failure
  run download.bash "${url}" "${target}"

  # Use -f to fail with exit code for 400 codes or greater
  assert_equal "$(mock_get_call_args "${mock_curl}")" "-fsSL ${url} -o ${target}"
}
```

As expected, the new test also passes because we call `curl` with the `-f` flag.

```sh
➜ bats test
download.bats
 ✓ downloads a file from URL and stores it at target location
 ✓ fails when curl returns an error
 ✓ curl is called with correct arguments

3 tests, 0 failures
```

## Testing in a deterministic setup

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

All tests are now passing.

```sh
➜ bats test
download.bats
 ✓ downloads a file from URL and stores it at target location
 ✓ fails when curl returns an error
 ✓ curl is called with correct arguments
 ✓ uses wget when curl is not available

4 tests, 0 failures
```

This concludes the tutorial.
