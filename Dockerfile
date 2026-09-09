# LarzOS in a container - Ubuntu 24.04 with the LarzOS apt repo and the
# config engine preinstalled. Describe a machine and converge it:
#
#   docker run --rm -v "$PWD/system.lz:/etc/larzos/system.lz" \
#       ghcr.io/larz-scripter/larzos plan
#
#   docker run --rm --privileged \
#       -v "$PWD/system.lz:/etc/larzos/system.lz" \
#       ghcr.io/larz-scripter/larzos apply
FROM ubuntu:24.04

SHELL ["/bin/sh", "-euxc"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
 && curl -fsSL https://larzos.com/apt/KEY.asc \
      | gpg --dearmor > /usr/share/keyrings/larzos-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/larzos-archive-keyring.gpg] https://larzos.com/apt stable main" \
      > /etc/apt/sources.list.d/larzos.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends larz-system larz-ai \
 && apt-get purge -y gnupg \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

COPY examples/system.lz /etc/larzos/system.lz

ENTRYPOINT ["larz-system"]
CMD ["plan"]
