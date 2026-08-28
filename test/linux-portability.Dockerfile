FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    busybox \
    dash \
    gawk \
    make \
    nodejs \
    original-awk \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY . .

CMD ["./test/linux-portability-container.sh"]
