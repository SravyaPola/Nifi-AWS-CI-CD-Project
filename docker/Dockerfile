# Use Java 17 on Ubuntu Jammy
FROM eclipse-temurin:17-jre-jammy

# Create a nobody-like nifi user
RUN useradd --no-create-home --shell /bin/false nifi

# This ARG must match the ZIP you fetch from S3
ARG NIFI_ZIP

# Install unzip and other essentials
RUN apt-get update && \
    apt-get install -y --no-install-recommends unzip ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# Copy in the NiFi zip, unpack to /opt/nifi, set ownership
COPY ${NIFI_ZIP} /tmp/
RUN mkdir -p /opt/nifi && \
    unzip /tmp/${NIFI_ZIP} -d /opt && \
    mv /opt/nifi-*/ /opt/nifi/ && \
    rm -rf /tmp/${NIFI_ZIP} && \
    chown -R nifi:nifi /opt/nifi

ENV NIFI_HOME=/opt/nifi
ENV PATH=$NIFI_HOME/bin:$PATH
ENV NIFI_WEB_HTTP_PORT=8080

EXPOSE 8080

USER nifi
ENTRYPOINT ["nifi.sh", "run"]
