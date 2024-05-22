# Use debian:bullseye-slim as the base image
FROM debian:bullseye-slim

LABEL maintainer="Giovanni Scafetta <giovanni.scafetta@gmx.com>"

ARG cafolder=/opt/certs/ca
ENV cafolder=${cafolder}

ARG certsfolder=/opt/certs/server
ENV certsfolder=${certsfolder}

# Update and install necessary packages
RUN apt update && apt upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt install -y openssl \
    && rm -rf /var/lib/apt/lists/*

# COPY *.cfg /opt
COPY ./configs/*.cfg /tmp

# Copy entrypoint script
COPY ./src/words /usr/share/dict
COPY ./src/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Define an environment variable to trigger script execution
ENV GENERATE_CA_CERT=false
ENV GENERATE_CLIENT_CERT=false
ENV GENERATE_SERVER_CERT=false
ENV GENERATE_DH_CERT=false
ENV DH_KEY_SIZE=2048
ENV CA-NAME=""
ENV SERVER-NAME=""
ENV CLIENT-NAME=""

# Set the entry point
ENTRYPOINT ["/entrypoint.sh"]