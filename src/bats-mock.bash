#!/usr/bin/env bash
#
# A Bats helper library providing mocking functionality

# Assure test isolation by using BATS_TEST_TMPDIR introduced with bats 1.4.0
bats_require_minimum_version '1.4.0'

# Creates a mock program
# Globals:
#   BATS_TEST_TMPDIR
# Arguments:
#   1: Command to mock, optional
# Returns:
#   1: If the mock command already exists
#   1: If the command provided with an absoluth path already exists
# Outputs:
#   STDOUT: Path to the mock
#   STDERR: Corresponding error message
mock_create() {
  local cmd="${1-}"
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

  # If a command name is provided, create a symbolic link to the mock
  if [[ -n "${cmd}" ]]; then
    # Don't create the mock if we cant create the link
    cmd=$(mock_set_command "${mock}" "${cmd}") || exit $?
  fi

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

  if [[ -n "${cmd}" ]]; then
    echo "${cmd}"
  else
    echo "${mock}"
  fi
}

# Creates a symbolic link with given name to a mock program
#
# This method is not meant to be called directly. Use mock_create instead.
#
# Arguments:
#   1: Path to the mock
#   2: Command name
# Returns:
#   1: If the mock command already exists
#   1: If the command provided with an absoluth path already exists
# Outputs:
#   STDOUT: Path to the mocked command
#   STDERR: Corresponding error message
mock_set_command() {
  local mock="${1?'Mocked command must be specified'}"
  local cmd="${2?'Command must be specified'}"
  local link_name="${mock%/*}/${cmd}"

  if [[ "${cmd}" = /* ]]; then
    # Command with abolute path
    if [[ -e "${cmd}" ]]; then
      echo "mock_create: failed to create command '${cmd}': command exists" >&2
      exit 1
    fi
    link_name=${cmd}
    mkdir -p "$(dirname "${link_name}")"
  elif [[ -e "${link_name}" ]]; then
    # Link already exists: either created by mock_create or mock_bin_dir
    if [[ $(readlink "${link_name}") =~ ${BATS_TEST_TMPDIR} ]]; then
      # Link pointing to  mock (created by mock_create)
      echo "mock_create: failed to create command '${cmd}': command exists" >&2
      exit 1
    else
      # Link pointing to outside $BATS_TEST_TMPDIR (created by mock_bin_dir).
      # We can savely delete it, to create a new one.
      rm "${link_name}"
    fi
  fi

  # Create command stub by linking it to the mock
  ln -s "${mock}" "${link_name}" && echo "${link_name}"
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
  # Make sure to resolve links in case we received a mock command
  mock=$(readlink -f "${mock}")

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
  # Make sure to resolve links in case we received a mock command
  mock=$(readlink -f "${mock}")

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
  # Make sure to resolve links in case we received a mock command
  mock=$(readlink -f "${mock}")

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
  # Make sure to resolve links in case we received a mock command
  mock=$(readlink -f "${mock}")

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

  # Make sure to resolve links in case we received a mock command
  mock=$(readlink -f "${mock}")

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
    exit 1
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

# Returns a path without a given path
# Arguments:
#   1: Path to be removed
#   2: Path from which the 1st argument is removed. Defaults to $PATH if not provided.
# Outputs:
#   STDOUT: a path without the path provided in ${1}
path_rm() {
  local path_or_cmd_to_remove=${1?'Path or command to remove must be specified'}
  local path=${2:-${PATH}}
  if [[ "${path_or_cmd_to_remove}" != /* ]] && [[ "${path_or_cmd_to_remove}" == *"/"* ]]; then
    echo "Relative paths are not allowed"
    exit 1
  fi

  if [[ "${path_or_cmd_to_remove}" == /* ]]; then
    # Absolute path to a command or directory, remove the directory and exit
    _remove_path "${path_or_cmd_to_remove}"
    return
  fi

  # It's a command, resolve its path(s) and remove their directories from the path
  local path_to_remove="${path_or_cmd_to_remove}"
  local path_to_cmd

  while path_to_cmd=$(PATH=${path} command -v "${path_or_cmd_to_remove}"); do
    # We can resolved the command
    # Use parameter expansion to get the folder portion of the command
    path_to_remove=${path_to_cmd%/*}
    path=$(_remove_path "${path_to_remove}")
  done
  echo "${path}"
}

_remove_path() {
  local path_to_remove="${1?'Path to remove must be specified'}"
  # Wrap the path with colons to simplify removal
  local path=":$path:"
  # Replace single colons with double colons for easier string substitution
  path=${path//":"/"::"}
  # Remove the path
  path=${path//":${path_to_remove}:"/}
  # Restore single colons
  path=${path//"::"/":"}
  # Clean up leading/trailing colons
  path=${path#:}
  path=${path%:}
  echo "${path}"
}
