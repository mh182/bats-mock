#!/usr/bin/env bats

# Test setup to verify bats-mock is available via bats_load_library

bats_require_minimum_version 1.5.0

# Load bats helper libraries
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-mock

setup() {
  # Set the path to mocked binaries directory as the first location in PATH
  # This is required for mocks to be found before system commands
  PATH=$(path_prepend "${BATS_TEST_TMPDIR}")
}

@test "mock tracks function calls" {
  mock=$(mock_create)

  # Call the mock
  run "${mock}"

  # Verify the mock was called once
  assert_equal "$(mock_get_call_num "${mock}")" 1
}
