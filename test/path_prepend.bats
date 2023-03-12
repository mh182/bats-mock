#!/usr/bin/env bats

load mock_test_suite

@test 'path_prepend requires mock to be specified' {
  run path_prepend
  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ 'Mock must be specified' ]]
}

@test 'path_prepend returns PATH prefixed with the mock directory' {
  # shellcheck disable=SC2154
  run path_prepend "${mock}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "$(dirname "${mock}"):$PATH" ]]
}

@test 'path_prepend returns PATH prefixed with directory' {
  run path_prepend "${mock}"
  override_with_mock="${output}"
  run path_prepend "$(dirname "${mock}")"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${override_with_mock}" ]]
}

@test 'path_prepend returns a given path prefixed with the mock directory' {
  run path_prepend '/x/y' '/a/b:/c/d'
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "/x/y:/a/b:/c/d" ]]
}

@test 'path_prepend twice has not effect' {
  run path_prepend "${mock}"
  local path_after_first_call=${output}
  run path_prepend "${mock}"
  [[ "${path_after_first_call}" = "${output}" ]]
}

@test "path_prepend doesn't accept relative paths" {
  run path_prepend 'relative/path' '/a/b:/c/d'
  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ 'Relative paths are not allowed' ]]
}
