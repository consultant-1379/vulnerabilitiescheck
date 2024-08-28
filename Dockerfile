FROM ubuntu:22.04
LABEL authors="Team Pulsar"

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
      jq \
      zip \
      curl \
      unzip \
      python3 \
      python3-pip && \
    \
    apt-get autoremove --purge -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir \
        pandas \
        openpyxl && \
    \
    mkdir /vulnerabilities_check && \
    chmod ugo+rw /vulnerabilities_check

COPY ./Bin /vulnerabilities_check/Bin
COPY ./Data /vulnerabilities_check/Data

WORKDIR /vulnerabilities_check

CMD ["/bin/sh"]