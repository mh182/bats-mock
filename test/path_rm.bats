#!/usr/bin/env bats

load mock_test_suite

@test 'path_rm requires a path or command to remove to be specified' {
  run path_rm
  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ 'Path or command to remove must be specified' ]]
}

@test 'path_rm removes directory from PATH' {
  [[ ":${PATH}:" == *:/bin:* ]]
  [[ ":${PATH}:" == *:/usr/bin:* ]]

  run path_rm /usr/bin

  [[ "${status}" -eq 0 ]]
  [[ ! ":${output}:" == *:/usr/bin:* ]]
  # Verify that /bin is still present
  [[ ":${output}:" == *:/bin:* ]]
}

@test 'path_rm removes directory from given path - path head' {
  run path_rm "/a/b" "/a/b:/c/d:/e/f"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ '/c/d:/e/f' ]]
}

@test 'path_rm removes directory from given path - path middle' {
  run path_rm "/c/d" "/a/b:/c/d:/e/f"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ '/a/b:/e/f' ]]
}

@test 'path_rm removes directory from given path - path tail' {
  run path_rm "/e/f" "/a/b:/c/d:/e/f"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ '/a/b:/c/d' ]]
}

@test 'path_rm returns path unchanged if it is not contained' {
  run path_rm "/a/x" "/c/d:/a/b:/e/f"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ '/c/d:/a/b:/e/f' ]]
}

@test "path_rm removes directories of given command so that command is no longer found" {
  # Check precondition: date command is in /usr/bin and /bin
  # /bin is a symblic link to /usr/bin on some systems.
  command -v date

  run path_rm date

  [[ "${status}" -eq 0 ]]
  PATH=${output} run ! command -v date
  ls -al /usr/bin
}

@test "path_rm doesn't accept relative paths" {
  run path_rm "relative/path" "/a/b:/a/b/relative/path:/c/d"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ 'Relative paths are not allowed' ]]
}
