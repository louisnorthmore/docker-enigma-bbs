FROM ubuntu:16.04

MAINTAINER Dave Stephens <dave@force9.org>

# set up home directory for nvm
ENV NVM_DIR /root/.nvm

# Do some installing!
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    python \
    libssl-dev \
    lrzsz \
    arj \
    lhasa \
    unrar-free \
    p7zip-full \
  && curl -O https://raw.githubusercontent.com/creationix/nvm/v0.33.7/install.sh \
  && chmod +x ./install.sh && ./install.sh && rm install.sh \
  && . ~/.nvm/nvm.sh && nvm install 6 && nvm alias default 6 && npm install -g pm2 \
  && git clone https://github.com/NuSkooler/enigma-bbs.git --depth 1 --branch 0.0.8-alpha \
  && cd /enigma-bbs && npm install --only=production \
  && apt-get remove build-essential python libssl-dev git curl -y && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && apt-get clean

# sexyz
COPY bin/sexyz /usr/local/bin

# enigma storage mounts
VOLUME /enigma-bbs/art
VOLUME /enigma-bbs/config
VOLUME /enigma-bbs/db
VOLUME /enigma-bbs/filebase
VOLUME /enigma-bbs/logs
VOLUME /enigma-bbs/mods
VOLUME /mail

# copy base config
COPY config/* /enigma-bbs/misc/

# set up config init script
COPY scripts/enigma_config.sh /enigma-bbs/misc/enigma_config.sh
RUN chmod +x /enigma-bbs/misc/enigma_config.sh

# Enigma default port
EXPOSE 8888

WORKDIR /enigma-bbs

ENTRYPOINT ["/bin/bash", "-c", "cd /enigma-bbs && ./misc/enigma_config.sh && source ~/.nvm/nvm.sh && exec pm2-docker ./main.js"]
