
FROM openfaas/of-watchdog:0.7.2 as watchdog
FROM node:12.13.0-alpine as ship

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/v3.11/main" >> /etc/apk/repositories \
  && apk upgrade -U -a \
  && apk add --no-cache \
  libstdc++ \
  chromium \
  harfbuzz \
  nss \
  freetype \
  ttf-freefont \
  && rm -rf /var/cache/* \
  && mkdir /var/cache/apk

ENV CHROME_BIN=/usr/bin/chromium-browser \
  CHROME_PATH=/usr/lib/chromium/

COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

RUN apk --no-cache add curl ca-certificates \
  && addgroup -S app && adduser -S -g app app

WORKDIR /root/

# Turn down the verbosity to default level.
ENV NPM_CONFIG_LOGLEVEL warn

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
ENV PUPPETEER_EXECUTABLE_PATH /usr/bin/chromium-browser

RUN mkdir -p /home/app

# Wrapper/boot-strapper
WORKDIR /home/app
COPY package.json ./

# This ordering means the npm installation is cached for the outer function handler.
RUN npm i

# Copy outer function handler
COPY index.js ./

# COPY function node packages and install, adding this as a separate
# entry allows caching of npm install

WORKDIR /home/app/function

COPY function/*.json ./

RUN npm i || :

# COPY function files and folders
COPY function/ ./

# Run any tests that may be available
RUN npm test

# Set correct permissions to use non root user
WORKDIR /home/app/

# chmod for tmp is for a buildkit issue (@alexellis)
RUN chown app:app -R /home/app \
  && chmod 777 /tmp

USER app

ENV cgi_headers="true"
ENV fprocess="node index.js"
ENV mode="http"
ENV upstream_url="http://127.0.0.1:3000"

ENV exec_timeout="10s"
ENV write_timeout="15s"
ENV read_timeout="15s"

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

CMD ["fwatchdog"]
