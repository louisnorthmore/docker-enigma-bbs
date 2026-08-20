# ENiGMA 1/2 BBS — modern build from the gitea mirror, node 22, slim.
# Clones enigma-bbs@master from the self-hosted mirror at build time so the
# image always carries the latest master (native BinkP, FREQ, TLS, etc).

FROM node:22-bookworm-slim

LABEL maintainer="louis@northmore.dev"

# ENIGMA_REPO may embed credentials, but we recommend passing a BuildKit secret
# (--secret id=gitea_token) which is injected into the clone step below.
ARG ENIGMA_REPO=https://git.uk1.northmore.net/northmore/enigma-bbs.git
ARG ENIGMA_BRANCH=master
ENV DEBIAN_FRONTEND noninteractive

# Build tooling + runtime support binaries ENiGMA wants (see docs: external-binaries)
RUN apt-get update \
    && apt-get install -y \
        git \
        curl \
        build-essential \
        python3 \
        p7zip-full \
        zip unzip \
        lrzsz \
        arj \
        lhasa \
        tar \
        poppler-utils \
        libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

# Clone target branch so we build from a known repo/branch. When the repo is
# private, pass a BuildKit secret (gitea_token) and set ENIGMA_REPO to include
# the username, e.g. --secret id=gitea_token \
#     --build-arg ENIGMA_REPO=https://oauth2@git.uk1.northmore.net/northmore/enigma-bbs.git
RUN --mount=type=secret,id=gitea_token,target=/run/gitea_token,required=false \
    url="$ENIGMA_REPO"; \
    if [ -f /run/gitea_token ]; then \
        url=$(echo "$url" | sed "s#@#:$(cat /run/gitea_token)@#"); \
    fi; \
    git clone --depth 1 --branch "$ENIGMA_BRANCH" "$url" /enigma-bbs

WORKDIR /enigma-bbs

# Install production deps. --ignore-scripts skips the dev-only husky 'prepare'
# hook in enigma's package.json; better-sqlite3 then needs its prebuild/compile
# step run explicitly (binary for the platform/arch is fetched or built).
RUN npm install --omit=dev --ignore-scripts \
    && cd node_modules/better-sqlite3 \
    && (npx --yes prebuild-install || npx --yes node-gyp rebuild --release) \
    && cd /enigma-bbs

# sexyz (X/Y/Zmodem) binary must be alongside main.js
COPY bin/sexyz /enigma-bbs/sexyz
RUN chmod +x /enigma-bbs/sexyz

# Pre-stage the volumes that need files at first boot: art, mods, config
RUN mkdir -p /enigma-bbs-pre/art /enigma-bbs-pre/mods /enigma-bbs-pre/config \
    && cp -rp /enigma-bbs/art/* /enigma-bbs-pre/art/ \
    && cp -rp /enigma-bbs/mods/* /enigma-bbs-pre/mods/ 

# Bake our chatnet config + entrypoint. config.hjson is the primary config and
# is staged alongside the rest so a fresh PVC gets seeded automatically.
COPY config/config.hjson /enigma-bbs/config/config.hjson
COPY config/ /enigma-bbs-pre/config/
COPY scripts/enigma_entrypoint.sh /enigma-bbs/docker-entrypoint.sh
RUN chmod +x /enigma-bbs/docker-entrypoint.sh \
    && rm -rf /var/lib/apt/lists/*

# enigma storage mounts
VOLUME /enigma-bbs/art
VOLUME /enigma-bbs/config
VOLUME /enigma-bbs/db
VOLUME /enigma-bbs/filebase
VOLUME /enigma-bbs/logs
VOLUME /enigma-bbs/mods
VOLUME /mail

# enigma default ports: telnet, ssh, web, https, binkp
EXPOSE 8888 8889 8080 8843 24554

WORKDIR /enigma-bbs

ENTRYPOINT ["/enigma-bbs/docker-entrypoint.sh"]