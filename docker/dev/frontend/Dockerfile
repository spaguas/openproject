FROM node:22.15.0
MAINTAINER operations@openproject.com

ARG DEV_UID=1000
ARG DEV_GID=1001

ENV USER=node

RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources && \
  rm -rf /var/lib/apt/lists/* && \
  apt-get update && \
  apt-get install -y --no-install-recommends chromium && \
  rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium

RUN npm i -g npm@11.3.0

RUN groupadd $USER || true
RUN groupmod -g $DEV_GID $USER || true
RUN usermod -u $DEV_UID -d /home/dev $USER || true

EXPOSE 4200

RUN mkdir -p /home/dev/openproject/public/assets/frontend
RUN chown $USER:$USER -R /home/dev

VOLUME ["/home/dev/openproject", "/home/dev/openproject/public/assets/frontend"]

WORKDIR /home/dev/openproject/frontend

USER $USER
