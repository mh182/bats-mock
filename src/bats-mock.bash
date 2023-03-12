#!/usr/bin/env bash
#
# A Bats helper library providing mocking functionality

# Assure test isolation by using BATS_TEST_TMPDIR introduced with bats 1.4.0
bats_require_minimum_version '1.4.0'

# Creates a mock program
# Globals:
#   BATS_TEST_TMPDIR
# Outputs:
#   STDOUT: Path to the mock
mock_create() {
  local index
  local mock
  local prefix='bats-mock'

  # Find the next available index. Use sort+tail instead of wc -l to avoid name
  # collisions in case a mock is deleted in the test.
  index="$(find "${BATS_TEST_TMPDIR}" -maxdepth 1 -type f -name "${prefix}.*" \
    2>/dev/null | sed -E "s|.*/${prefix}\.([0-9]+)$|\1|" | sort -n | tail -n1)"
  if [[ -z "${index}" ]]; then
    index=0
  else
    ((index++))
  fi
  mock="${BATS_TEST_TMPDIR}/${prefix}.${index}"

  echo -n 0 >"${mock}.call_num"
  echo -n 0 >"${mock}.status"
  echo -n '' >"${mock}.output"
  echo -n '' >"${mock}.side_effect"

  cat <<EOF >"${mock}"
#!/usr/bin/env bash

set -e

mock="${mock}"

call_num="\$(( \$(cat \${mock}.call_num) + 1 ))"
echo "\${call_num}" > "\${mock}.call_num"

echo "\${_USER:-\$(id -un)}" > "\${mock}.user.\${call_num}"

printf "%s" "\$*" > "\${mock}.args.\${call_num}"

for var in \$(compgen -e); do
  declare -p "\${var}"
done > "\${mock}.env.\${call_num}"

if [[ -e "\${mock}.output.\${call_num}" ]]; then
  cat "\${mock}.output.\${call_num}"
else
  cat "\${mock}.output"
fi

if [[ -e "\${mock}.side_effect.\${call_num}" ]]; then
  source "\${mock}.side_effect.\${call_num}"
else
  source "\${mock}.side_effect"
fi

if [[ -e "\${mock}.status.\${call_num}" ]]; then
  exit "\$(cat \${mock}.status.\${call_num})"
else
  exit "\$(cat \${mock}.status)"
fi
EOF
  chmod +x "${mock}"

  echo "${mock}"
}

# Sets the exit status of the mock
# Arguments:
#   1: Path to the mock
#   2: Status
#   3: Index of the call, optional
mock_set_status() {
  local mock="${1?'Mock must be specified'}"
  local status="${2?'Status must be specified'}"
  local n="${3-}"

  mock_set_property "${mock}" 'status' "${status}" "${n}"
}

# Sets the output of the mock
# Arguments:
#   1: Path to the mock
#   2: Output or - for STDIN
#   3: Index of the call, optional
mock_set_output() {
  local mock="${1?'Mock must be specified'}"
  local output="${2?'Output must be specified'}"
  local n="${3-}"

  mock_set_property "${mock}" 'output' "${output}" "${n}"
}

# Sets the side effect of the mock
# Arguments:
#   1: Path to the mock
#   2: Side effect or - for STDIN
#   3: Index of the call, optional
mock_set_side_effect() {
  local mock="${1?'Mock must be specified'}"
  local side_effect="${2?'Side effect must be specified'}"
  local n="${3-}"

  mock_set_property "${mock}" 'side_effect' "${side_effect}" "${n}"
}

# Returns the number of times the mock was called
# Arguments:
#   1: Path to the mock
# Outputs:
#   STDOUT: Number of calls
mock_get_call_num() {
  local mock="${1?'Mock must be specified'}"

  cat "${mock}.call_num"
}

# Returns the user the mock was called with
# Arguments:
#   1: Path to the mock
#   2: Index of the call, optional
# Outputs:
#   STDOUT: User name
mock_get_call_user() {
  local mock="${1?'Mock must be specified'}"
  local n
  n="$(mock_default_n "${mock}" "${2-}")" || exit "$?"

  cat "${mock}.user.${n}"
}

# Returns the arguments line the mock was called with
# Arguments:
#   1: Path to the mock
#   2: Index of the call, optional
# Outputs:
#   STDOUT: Arguments line
mock_get_call_args() {
  local mock="${1?'Mock must be specified'}"
  local n
  n="$(mock_default_n "${mock}" "${2-}")" || exit "$?"

  cat "${mock}.args.${n}"
}

# Returns the value of the environment variable the mock was called with
# Arguments:
#   1: Path to the mock
#   2: Variable name
#   3: Index of the call, optional
# Outputs:
#   STDOUT: Variable value
mock_get_call_env() {
  local mock="${1?'Mock must be specified'}"
  local var="${2?'Variable name must be specified'}"
  local n
  n="$(mock_default_n "${mock}" "${3-}")" || exit "$?"

  # shellcheck source=/dev/null
  source "${mock}.env.${n}"
  echo "${!var-}"
}

# Sets a specific property of the mock
# Arguments:
#   1: Path to the mock
#   2: Property name
#   3: Property value or - for STDIN
#   4: Index of the call, optional
# Inputs:
#   STDIN: Property value if 2 is -
mock_set_property() {
  local mock="${1?'Mock must be specified'}"
  local property_name="${2?'Property name must be specified'}"
  local property_value="${3?'Property value must be specified'}"
  local n="${4-}"

  if [[ "${property_value}" = '-' ]]; then
    property_value="$(cat -)"
  fi

  if [[ -n "${n}" ]]; then
    echo -e "${property_value}" >"${mock}.${property_name}.${n}"
  else
    echo -e "${property_value}" >"${mock}.${property_name}"
  fi
}

# Defaults call index to the last one if not specified explicitly
# Arguments:
#   1: Path to the mock
#   2: Index of the call, optional
# Returns:
#   1: If mock is not called enough times
# Outputs:
#   STDOUT: Call index
#   STDERR: Corresponding error message
mock_default_n() {
  local mock="${1?'Mock must be specified'}"
  local call_num
  call_num="$(cat "${mock}.call_num")"
  local n="${2:-${call_num}}"

  if [[ "${n}" -eq 0 ]]; then
    n=1
  fi

  if [[ "${n}" -gt "${call_num}" ]]; then
    echo "$(basename "$0"): Mock must be called at least ${n} time(s)" >&2
    exit 1
  fi

  echo "${n}"
}

# Returns a path prepended with the mock's directory
# Arguments:
#   1: Path to the mock which may be a file, directory or link
#   2: Path to be prepended by the path from the 1st argument. Defaults to $PATH if not provided.
# Outputs:
#   STDOUT: the path prepended with the mock's directory
path_prepend() {
  local mock="${1?'Mock must be specified'}"
  local path=${2:-${PATH}}
  local mock_path="${mock}"

  if [[ "${mock}" != /* ]]; then
    echo "Relative paths are not allowed"
    return 1
  fi

  if [[ -f "${mock}" ]]; then
    # Parameter expansion to get the folder portion of the mock's path
    local mock_path="${mock%/*}"
  fi

  # Putting the directory with the mocked comands at the beginning of the PATH
  # so it gets picked up first
  if [[ :${path}: == *:${mock_path}:* ]]; then
    echo "${path}"
  else
    echo "${mock_path}:${path}"
  fi
}
