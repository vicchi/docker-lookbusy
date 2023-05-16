FROM containerstack/alpine-arm64:3.7.0

LABEL org.opencontainers.image.source=https://github.com/vicchi/docker-lookbusy
LABEL org.opencontainers.image.authors="Gary Gale <gary@vicchi.org>"
LABEL org.opencontainers.image.version=1.4.0
LABEL org.opencontainers.image.licenses=BSD-3-Clause

ENV PACKAGES make gcc musl-dev

WORKDIR /service
RUN apk add --no-cache $PACKAGES && \
  wget -q http://www.devin.com/lookbusy/download/lookbusy-1.4.tar.gz && \
  tar -xzf lookbusy-1.4.tar.gz && \
  cd lookbusy-1.4/ && \
  ./configure && \
  make install && \
  rm -rfv lookbusy-1.4* && \
  apk del $PACKAGES && \
  rm -rfv /var/cache/apk/*

WORKDIR /
ENTRYPOINT ["/usr/local/bin/lookbusy"]

CMD ["--help"]
