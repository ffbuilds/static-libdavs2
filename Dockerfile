
# bump: davs2 /DAVS2_VERSION=([\d.]+)/ https://github.com/pkuvcl/davs2.git|^1
# bump: davs2 after ./hashupdate Dockerfile DAVS2 $LATEST
# bump: davs2 link "Release" https://github.com/pkuvcl/davs2/releases/tag/$LATEST
# bump: davs2 link "Source diff $CURRENT..$LATEST" https://github.com/pkuvcl/davs2/compare/v$CURRENT..v$LATEST
ARG DAVS2_VERSION=1.7
ARG DAVS2_URL="https://github.com/pkuvcl/davs2/archive/refs/tags/$DAVS2_VERSION.tar.gz"
ARG DAVS2_SHA256=b697d0b376a1c7f7eda3a4cc6d29707c8154c4774358303653f0a9727f923cc8

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG DAVS2_URL
ARG DAVS2_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O davs2.tar.gz "$DAVS2_URL" && \
  echo "$DAVS2_SHA256  davs2.tar.gz" | sha256sum --status -c - && \
  mkdir davs2 && \
  tar xf davs2.tar.gz -C davs2 --strip-components=1 && \
  rm davs2.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/davs2/ /tmp/davs2/
WORKDIR /tmp/davs2/build/linux
RUN \
  apk add --no-cache --virtual build \
    build-base bash pkgconf && \
  # TODO: seems to be issues with asm on musl
  ./configure --disable-asm --enable-pic --enable-strip --disable-cli && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path davs2 && \
  ar -t /usr/local/lib/libdavs2.a && \
  readelf -h /usr/local/lib/libdavs2.a && \
  # Cleanup
  apk del build

FROM scratch
ARG DAVS2_VERSION
COPY --from=build /usr/local/lib/pkgconfig/davs2.pc /usr/local/lib/pkgconfig/davs2.pc
COPY --from=build /usr/local/lib/libdavs2.a /usr/local/lib/libdavs2.a
COPY --from=build /usr/local/include/davs2* /usr/local/include/
