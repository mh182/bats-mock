#!/usr/bin/env bats

set -euo pipefail

load ../src/bats-mock

teardown() {
    rm -rf "${BATS_TMPDIR}"/bats-mock.$$.*
}

@test 'mock_teardown removes all files and directories' {
  _mock="$(mock_create)"
  _mock="$(mock_chroot ls cat)"
  mock_teardown  

  local existing_mocks
  existing_mocks="$(find "${BATS_TMPDIR}" -name "bats-mock.$$.*" 2>&1)"
  echo "existing mocks: ${existing_mocks}"
  [[ -z "${existing_mocks}" ]]
}
