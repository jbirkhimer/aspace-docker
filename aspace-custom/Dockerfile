FROM openjdk:8-jdk-slim

RUN apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
    wget \
    default-mysql-client \
    htop \
	&& rm -rf /var/lib/apt/lists/*

RUN set -eux && \
    useradd -m -s /bin/bash -u 1000 aspace

RUN mkdir -p /aspace.local

#USER aspace

HEALTHCHECK --interval=1m --timeout=5s --start-period=5m --retries=2 \
  CMD wget -q --spider http://localhost:8089/ || exit 1

ENTRYPOINT ["/aspace/aspace-docker-setup.sh"]
CMD ["start"]