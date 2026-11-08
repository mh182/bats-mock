# SPDX-FileCopyrightText: 2026 Max Hofer <mh182@chello.at>
#
# SPDX-License-Identifier: MIT

FROM bats/bats:latest

# The bats helper libraries are installed in /usr/lib/bats.
# Mount the build context temporarily to run the install script without
# copying source files into the image.
RUN --mount=type=bind,target=/tmp/bats-mock \
    LIBDIR=/usr/lib/bats /tmp/bats-mock/build install

# Inherit WORKDIR and ENTRYPOINT from the base image
