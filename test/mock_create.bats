#!/usr/bin/env bats

# Load bats-mock library
load '../load'

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

@test 'mock_create command creates a program with given name' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  [[ -x "${output}" ]]
  [[ "$(basename "${output}")" = example ]]
}

@test 'mock_create command is located in BATS_TEST_TMPDIR' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  echo "output: $output"
  [[ "$(dirname "${output}")" == "${BATS_TEST_TMPDIR}" ]]
}

@test 'mock_create command links to a mock' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  [[ "$(readlink "${output}")" =~ ${BATS_TEST_TMPDIR}/bats-mock\. ]]
}

@test 'mock_create command with absolute path' {
  absolute_path=$(mktemp -u "${BATS_TMPDIR}/XXXXXX")
  run mock_create "${absolute_path}/example"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" = "${absolute_path}/example" ]]
}

@test 'mock_create command with absolute path creates mock in BATS_TEST_TMPDIR' {
  absolute_path=$(mktemp -u "${BATS_TMPDIR}/XXXXXX")
  run mock_create "${absolute_path}/example"
  [[ "${status}" -eq 0 ]]
  [[ "$(dirname "$(readlink "${output}")")" = "${BATS_TEST_TMPDIR}" ]]
}

@test 'mock_create command twice with same command fails' {
  run mock_create example
  [[ "${status}" -eq 0 ]]
  # Set locale to C to get consistent error message
  LC_ALL=C run mock_create example
  [[ "${status}" -eq 1 ]]
  local regexp="mock_create: failed to create command 'example': command exists"
  [[ "${output}" =~ ${regexp} ]]
}

@test 'mock_create command with absolute path to existing command fails' {
  LC_ALL=C run mock_create /bin/ls
  [[ "${status}" -eq 1 ]]
  local regexp="mock_create: failed to create command '/bin/ls': command exists"
  [[ "${output}" =~ ${regexp} ]]
}

@test 'mock_create comand to existing program does not create the mock' {
  LC_ALL=C run mock_create /bin/ls
  [[ "${status}" -eq 1 ]]
  [[ $(find "${BATS_TEST_TMPDIR}" -maxdepth 1 -name "bats-mock.*" 2>&1 | wc -l) -eq 0 ]]
}
