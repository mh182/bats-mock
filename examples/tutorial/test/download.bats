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

@test "curl is called with correct arguments" {
  # Arrange
  mock_curl=$(mock_create curl)
  url="https://example.com/file.txt"

  # Act - expect failure
  run download.bash "${url}" "${target}"

  assert_equal "$(mock_get_call_args "${mock_curl}")" "-fsSL ${url} -o ${target}"
}

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
