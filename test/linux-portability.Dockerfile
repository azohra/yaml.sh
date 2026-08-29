ARG YQ_VERSION
FROM mikefarah/yq:${YQ_VERSION} AS yq

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    busybox \
    dash \
    gawk \
    jq \
    make \
    nodejs \
    original-awk \
  && rm -rf /var/lib/apt/lists/*

COPY --from=yq /usr/bin/yq /usr/local/bin/yq

WORKDIR /work
COPY . .

CMD ["./test/linux-portability-container.sh"]
