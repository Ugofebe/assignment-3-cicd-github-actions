FROM ubuntu:22.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        dnsutils \
        netcat-openbsd \
        procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/ /app/

RUN chmod +x /app/app.sh

ENTRYPOINT ["/app/app.sh"]
CMD ["help"]
