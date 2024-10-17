#!/usr/bin/env bats

set -euo pipefail

load ../src/bats-mock

teardown() {
  rm -rf "${BATS_TMPDIR}/bats-mock.$$."*
}

@test 'mock_create creates a program' {
  run mock_create
  [[ "${status}" -eq 0 ]]
  [[ -x "${output}" ]]
}

@test 'mock_create names the program uniquely' {
  run mock_create
  [[ "${status}" -eq 0 ]]
  mock="${output}"
  run mock_create
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != "${mock}" ]]
}

@test 'mock_create creates a program in BATS_TMPDIR' {
  run mock_create
  [[ "${status}" -eq 0 ]]
  [[ "$(dirname "${output}")" = "${BATS_TMPDIR}" ]]
}

@test 'mock_create command creates a program with given name' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  [[ -x "${output}" ]]
  [[ "$(basename "${output}")" = example ]]
}

@test 'mock_create command is loacted in the same directory as the mock' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  echo "command: $(dirname "${output}")"
  echo "mock: $(dirname "$(readlink "${output}")")"
  [[ "$(dirname "${output}")" == "${BATS_TMPDIR}/bats-mock.$$.bin" ]]
}

@test 'mock_create command links to a mock' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  [[ "$(readlink "${output}")" =~ ${BATS_TMPDIR}/bats-mock\.$$\. ]]
}

@test 'mock_create command with absolute path' {
  echo "${BATS_TMPDIR}/bats-mock.$$.XXXX"
  absolute_path=$(mktemp -u "${BATS_TMPDIR}/bats-mock.$$.XXXXXX")
  run mock_create "${absolute_path}/example"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" = "${absolute_path}/example" ]]
}

@test 'mock_create command with absolute path creates mock in BATS_TMPDIR' {
  absolute_path=$(mktemp -u "${BATS_TMPDIR}/bats-mock.$$.XXXXXX")
  run mock_create "${absolute_path}/example"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" = "${absolute_path}/example" ]]
  [[ "$(dirname "$(readlink "${output}")")" = "${BATS_TMPDIR}" ]]
}

@test 'mock_create command does not change PATH' {
  saved_path=${PATH}
  run mock_create example
  [[ "${status}" -eq 0 ]]
  [[ "${saved_path}" = "${PATH}" ]]
}

@test 'mock_create command twice with same command fails' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  LC_ALL=C run mock_create example
  echo "output: $output"
  [[ "${status}" -eq 1 ]]
  local regex_pattern="ln: .*${BATS_TMPDIR}/bats-mock.$$.bin/example'*: File exists"
  echo "regex match: [${regex_pattern}]"
  [[ "${output}" =~ ${regex_pattern} ]]
}

@test 'mock_create command with absolute path to existing command fails' {
  LC_ALL=C run mock_create /bin/ls
  [[ "${status}" -eq 1 ]]
  echo "Output: [${output}]"
  # This is a brittle test since we check against ln error output which may
  # varry based on the implementation. Is there a better way?
  local regex_pattern="ln: .*/bin/ls'*: File exists"
  echo "regex_pattern: [${regex_pattern}]"
  [[ "${output}" =~ ${regex_pattern} ]]
}

@test 'mock_create comand to existing program does not create the mock' {
  LC_ALL=C run mock_create /bin/ls
  [[ "${status}" -eq 1 ]]
  [[ $(find "${BATS_TMPDIR}" -maxdepth 1 -name "bats-mock.$$.*" 2>&1 | wc -l) -eq 0 ]]
}
