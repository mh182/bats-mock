#!/usr/bin/env bash

set -euo pipefail

# Load bats-mock library
load '../load'

setup() {
  bats_require_minimum_version 1.5.0
  mock="$(mock_create)"
  cmd="$(mock_create example)"
}
