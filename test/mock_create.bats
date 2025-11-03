#!/usr/bin/env bats

set -euo pipefail

load ../src/bats-mock

@test 'mock_create creates a program' {
  run mock_create
  [[ "${status}" -eq 0 ]]
  [[ -x "${output}" ]]
}

@test 'mock_create creates a program in BATS_TEST_TMPDIR' {
  run mock_create
  [[ "${status}" -eq 0 ]]
  [[ "$(dirname "${output}")" = "${BATS_TEST_TMPDIR}" ]]
}

@test 'mock_create names the program uniquely' {
  run mock_create
  [[ "${status}" -eq 0 ]]
  mock="${output}"
  run mock_create
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != "${mock}" ]]
}

@test 'mock_create program names are not affected by deletion' {
  mock_0=$(mock_create)
  run mock_create
  [[ "${status}" -eq 0 ]]
  mock_1="${output}"
  # Delete first mock to check if the names are not reused
  rm "${mock_0}"
  run mock_create
  [[ "${status}" -eq 0 ]]
  mock_2="${output}"

  [[ "${mock_1}" != "${mock_2}" ]]
}
