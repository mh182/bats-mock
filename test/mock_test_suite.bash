#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2018 Sergey Konoplev <gray.ru@gmail.com>
# SPDX-FileCopyrightText: 2020 Unknown <ms-develop@stoffnet.at>
# SPDX-FileCopyrightText: 2025 Max Hofer <mh182@chello.at>
#
# SPDX-License-Identifier: MIT
# SPDX-License-Identifier: Unlicense

set -euo pipefail

# Load bats-mock library
load '../load'

setup() {
  bats_require_minimum_version 1.5.0
  mock="$(mock_create)"
  cmd="$(mock_create example)"
}
