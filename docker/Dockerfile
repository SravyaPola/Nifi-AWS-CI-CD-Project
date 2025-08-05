#── STAGE 1: build & unzip ───────────────────────────────────────────────
FROM eclipse-temurin:17-jre-jammy AS builder

ARG NIFI_VERSION=1.26.0
ARG NIFI_ZIP=nifi-${NIFI_VERSION}-bin.zip
WORKDIR /tmp

# only needed at build-time:
RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip curl \
 && rm -rf /var/lib/apt/lists/*

# pull & unpack NiFi
# (or COPY ${NIFI_ZIP} /tmp/ if you prefer)
RUN curl -fSL \
     https://archive.apache.org/dist/nifi/${NIFI_VERSION}/${NIFI_ZIP} \
     -o ${NIFI_ZIP} \
 && unzip ${NIFI_ZIP} -d /opt \
 && mv /opt/nifi-${NIFI_VERSION} /opt/nifi \
 && rm ${NIFI_ZIP}

#── STAGE 2: minimal runtime ───────────────────────────────────────────────
FROM eclipse-temurin:17-jre-jammy-slim

# create unprivileged user & group
RUN groupadd -r nifi && useradd -r -g nifi -d /opt/nifi -s /bin/false nifi

# copy only the exploded NiFi tree
COPY --from=builder /opt/nifi /opt/nifi

# strip out docs, Windows scripts, examples, unused NARs, etc.
RUN rm -rf \
     /opt/nifi/docs \
     /opt/nifi/README* \
     /opt/nifi/bin/*.bat \
     /opt/nifi/licenses \
     /opt/nifi/conf/templates \
     /opt/nifi/lib/logback* \
     /opt/nifi/lib/kafka-client* \
     /opt/nifi/lib/mysql-connector*   # remove JDBC drivers you don't need

USER nifi
WORKDIR /opt/nifi

ENV NIFI_HOME=/opt/nifi \
    PATH=/opt/nifi/bin:$PATH \
    NIFI_WEB_HTTP_PORT=8080

EXPOSE 8080

ENTRYPOINT ["nifi.sh", "run"]
