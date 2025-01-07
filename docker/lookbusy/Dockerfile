ARG UBUNTU_VERSION=24.04
ARG VERSION
FROM ubuntu:${UBUNTU_VERSION} AS build

RUN <<EOT
apt-get update -qy
apt-get install -qyy \
    -o APT::Install-Recommends=false \
    -o APT::Install-Suggests=false \
    build-essential
apt-get clean
rm -rf /var/lib/apt/lists/*
EOT

WORKDIR /build
COPY src /build/src

WORKDIR /build/src
RUN <<EOT
./configure
make
EOT

FROM ubuntu:${UBUNTU_VERSION}
ARG UBUNTU_VERSION
ARG VERSION
WORKDIR /service

COPY --from=build /build/src/lookbusy ./lookbusy

LABEL org.opencontainers.image.source=https://github.com/vicchi/docker-lookbusy
LABEL org.opencontainers.image.url=https://github.com/vicchi/docker-lookbusy/tree/master#readme
LABEL org.opencontainers.image.authors="Gary Gale <gary@vicchi.org>, Devin Carraway <lookbusy@devin.com>"
LABEL org.opencontainers.image.version=${VERSION}
LABEL org.opencontainers.image.revision=${VERSION}
LABEL org.opencontainers.image.licenses=GPL-2.0-or-later
LABEL org.opencontainers.image.description="Lightweight multi-architecture Docker image for lookbusy"
LABEL org.opencontainers.image.title="Docker Lookbusy"
LABEL org.opencontainers.image.base.name=docker.io/ubuntu:${UBUNTU_VERSION}

ENTRYPOINT ["/service/lookbusy"]
CMD ["--help"]
