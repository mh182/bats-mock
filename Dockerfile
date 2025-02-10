ARG batsver=latest

FROM bats/bats:${batsver}
ARG MODE=755

# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL maintainer="Max Hofer"
LABEL org.opencontainers.image.authors="Max Hofer"
LABEL org.opencontainers.image.title="Bats"
LABEL org.opencontainers.image.description="Bash Automated Testing System"
# LABEL org.opencontainers.image.url="https://hub.docker.com/repository/docker/maxh/bats-mock"
LABEL org.opencontainers.image.source="https://github.com/mh182/bats-mock"
LABEL org.opencontainers.image.base.name="docker.io/bats/bats"

RUN mkdir -p /usr/lib/bats/bats-mock/src

COPY --chmod=$MODE load.bash /usr/lib/bats/bats-mock/
COPY --chmod=$MODE src/bats-mock.bash /usr/lib/bats/bats-mock/src/

WORKDIR /code/

ENTRYPOINT ["/tini", "--", "/usr/local/bin/bash", "/usr/local/bin/bats"]
