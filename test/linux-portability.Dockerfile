ARG YQ_VERSION
ARG GAWK_VERSION=5.4.1
ARG GAWK_SHA256=07f6f7342b7febe4313fc2c2542ad93d64fe20ad8717200109f105a826f5fd37

FROM mikefarah/yq:${YQ_VERSION} AS yq

FROM ubuntu:26.04 AS gawk
ARG GAWK_VERSION
ARG GAWK_SHA256

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
  && curl -fsSL "https://ftp.gnu.org/gnu/gawk/gawk-${GAWK_VERSION}.tar.xz" -o /tmp/gawk.tar.xz \
  && printf '%s  %s\n' "$GAWK_SHA256" /tmp/gawk.tar.xz | sha256sum -c - \
  && mkdir /tmp/gawk \
  && tar -xJf /tmp/gawk.tar.xz --strip-components=1 -C /tmp/gawk \
  && cd /tmp/gawk \
  && ./configure --disable-nls --prefix=/usr/local \
  && make -j2 \
  && make install-strip

FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    busybox \
    dash \
    jq \
    make \
    nodejs \
    original-awk \
  && rm -rf /var/lib/apt/lists/*

COPY --from=yq /usr/bin/yq /usr/local/bin/yq
COPY --from=gawk /usr/local/bin/gawk /usr/local/bin/gawk

WORKDIR /work
COPY . .

CMD ["./test/linux-portability-container.sh"]
