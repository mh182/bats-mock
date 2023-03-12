#!/usr/bin/env bats

load '../load'

# We use flags on 'run' command which are available since bats version 1.5.0
bats_require_minimum_version 1.5.0

@test 'mock_bin_dir without argument creates directory with minimal set of commands' {
  run mock_bin_dir
  [[ "${status}" -eq 0 ]]
  bin_dir=${output}

  # Test a small sub-set of created links otherwise the test may fail on systems
  # with reduced tooling (e.g. minimal container images)
  PATH="${BATS_TEST_TMPDIR}" run command -v cat
  [[ "${output}" =~ ${bin_dir}/cat ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v date
  [[ "${output}" =~ ${bin_dir}/date ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v grep
  [[ "${output}" =~ ${bin_dir}/grep ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v ln
  [[ "${output}" =~ ${bin_dir}/ln ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v ls
  [[ "${output}" =~ ${bin_dir}/ls ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v mv
  [[ "${output}" =~ ${bin_dir}/mv ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v rm
  [[ "${output}" =~ ${bin_dir}/rm ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v sh
  [[ "${output}" =~ ${bin_dir}/sh ]]
}

@test 'mock_bin_dir and mock_create mock commands in the same directory' {
  run mock_create wget
  [[ "${status}" -eq 0 ]]
  mock_wget="${output}"
  run mock_bin_dir
  [[ "${status}" -eq 0 ]]
  [[ $(dirname "${mock_wget}") == "${output}" ]]
}

@test 'mock_bin_dir skips command creation if command not found' {
  # Provide empty PATH to make sure none of the basic system commands can be found
  PATH="" run mock_bin_dir
  [[ "${status}" -eq 0 ]]
  # Since none of the commands could be found, no links should be created
  # Note: MacOS always finds '/bin/mkdir' even with empty PATH, so don't test
  # the number of created links here.
  PATH="${BATS_TEST_TMPDIR}" run -127 cat
  PATH="${BATS_TEST_TMPDIR}" run -127 date
  PATH="${BATS_TEST_TMPDIR}" run -127 grep
  PATH="${BATS_TEST_TMPDIR}" run -127 ln
  PATH="${BATS_TEST_TMPDIR}" run -127 ls
  PATH="${BATS_TEST_TMPDIR}" run -127 mv
  PATH="${BATS_TEST_TMPDIR}" run -127 rm
  PATH="${BATS_TEST_TMPDIR}" run -127 sh
}

@test 'mock_bin_dir is idempotent' {
  run mock_bin_dir
  [[ "${status}" -eq 0 ]]
  local first_chroot="${output}"
  run mock_bin_dir
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${first_chroot}" ]]
}

@test 'mock_bin_dir does not overwrite existing mock command' {
  run mock_create cat
  [[ "${status}" -eq 0 ]]
  mock="${output}"
  run mock_bin_dir
  [[ "${status}" -eq 0 ]]
  # Check link instead of calling the mock to decouple tests.
  run readlink "${mock}"
  [[ "${output}" =~ ${BATS_TEST_TMPDIR}/bats-mock\. ]]
}

@test 'mock_bin_dir with defined set of commands' {
  run mock_bin_dir cat cut ls
  [[ "${status}" -eq 0 ]]
  bin_dir="${output}"
  PATH="${BATS_TEST_TMPDIR}" run command -v cat
  [[ "${output}" =~ ${bin_dir}/cat ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v cut
  [[ "${output}" =~ ${bin_dir}/cut ]]
  PATH="${BATS_TEST_TMPDIR}" run command -v ls
  [[ "${output}" =~ ${bin_dir}/ls ]]
  [[ $(find "${bin_dir}" -type l | wc -l) -eq 3 ]]
}

@test 'mock_bin_dir with defined set of commands fails if command not found' {
  run mock_bin_dir cat foo cut ls
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "foo: command not found" ]]
}

@test 'mock_bin_dir with defined set of commands fails on existing mock command' {
  run mock_create cat
  [[ "${status}" -eq 0 ]]
  LC_ALL=C run mock_bin_dir ls cat head
  [[ "${status}" -eq 1 ]]
  local regexp="ln: .*${BATS_TEST_TMPDIR}/cat'*: File exists"
  [[ "${output}" =~ ${regexp} ]]
}
