#!/usr/bin/env bats

set -euo pipefail

load ../src/bats-mock

teardown() {
    rm -rf "${BATS_TMPDIR}"/bats-mock.$$.*
}

@test 'mock_chroot without argument creates directory with minimal set of commands' {
  run mock_chroot
  [[ "${status}" -eq 0 ]]
  # Test sub-set of created links otherwise the test may fail on systems with
  # reduced tooling
  [[ -x "${output}/date" ]]
  [[ -x "${output}/ln" ]]
  [[ -x "${output}/ls" ]]
  [[ -x "${output}/mv" ]]
  [[ -x "${output}/rm" ]]
  [[ -x "${output}/sh" ]]
}

@test 'mock_chroot skips command if command not found' {
  # Provide empty PATH to make sure none of the basic system commands can be found
  PATH="" run mock_chroot
  [[ "${status}" -eq 0 ]]
  [[ $(find "${output}" -type l | wc -l) -eq 0 ]]
}

@test 'mock_chroot is idempotent' {
  run mock_chroot
  [[ "${status}" -eq 0 ]]
  local first_chroot="${output}"
  run mock_chroot
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${first_chroot}" ]]
}

@test 'mock_chroot and mock_create command use same directory' {
  run mock_create wget
  [[ "${status}" -eq 0 ]]
  mock_wget="${output}"
  run mock_chroot
  [[ "${status}" -eq 0 ]]
  [[ $(dirname "${mock_wget}") == "${output}" ]]
}

@test 'mock_chroot does not overwrite existing mock command' {
  run mock_create cat
  [[ "${status}" -eq 0 ]]
  mock_cat="${output}"
  run mock_chroot
  [[ "${status}" -eq 0 ]]
  echo "$(readlink "${mock_cat}")"
  [[ $(readlink "${mock_cat}") =~ ${BATS_TMPDIR}/bats-mock.$$. ]]
}

@test 'mock_chroot with defined set of commands' {
  run mock_chroot cat cut ls
  [[ "${status}" -eq 0 ]]
  echo "Comands in chroot: $(find "${output}" -type l | wc -l)"
  [[ $(find "${output}" -type l | wc -l) -eq 3 ]]
}

@test 'mock_chroot with defined set of commands fails if command not found' {
  run mock_chroot cat foo cut ls
  [[ "${status}" -eq 1 ]]
  echo "Output: [${output}]"
  [[ "${output}" == "foo: command not found" ]]
}

@test 'mock_chroot with defined set of commands fails on existing mock command' {
  run mock_create cat
  [[ "${status}" -eq 0 ]]
  mock_cat="${output}"
  LC_ALL=C run mock_chroot ls cat head
  [[ "${status}" -eq 1 ]]
  echo "Output: [${output}]"
  [[ "${output}" == "ln: failed to create symbolic link '${BATS_TMPDIR}/bats-mock.$$.bin/cat': File exists" ]]
}
