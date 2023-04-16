FROM ubuntu:22.04

ARG VALS_VERSION="0.24.0"
ARG HELM_VERSION="v3.11.1"
ARG HELM_SECRETS_VERSION="4.4.2"
ARG HELMFILE_VERSION="0.152.0" 

RUN set -eux; \
    groupadd --gid 999 argocd; \
    useradd --uid 999 --gid argocd -m argocd;

# Install couple of useful packages
RUN apt-get update  --allow-insecure-repositories --allow-unauthenticated && \
    apt-get install -y \
    git \
    curl \
    gpg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install plugin related binary (sops, age, helm, helmfile)
COPY helm-wrapper.sh /usr/local/bin/helm
RUN OS=$(uname | tr '[:upper:]' '[:lower:]') && \
    ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/') && \
    curl -sSL -o vals.tar.gz https://github.com/helmfile/vals/releases/download/v${VALS_VERSION}/vals_0.24.0_${OS}_${ARCH}.tar.gz && \
    tar zxvf vals.tar.gz && \
    mv vals /usr/local/bin/ && \
    rm -f vals vals.tar.gz && \
    curl -fsSLO https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz && \
    tar zxvf "helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz" && \
    mv ${OS}-${ARCH}/helm /usr/local/bin/helm.bin && \
    rm -rf ${OS}-${ARCH} helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz && \
    curl -fsSLO https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz && \
    tar zxvf "helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz" && \
    mv ./helmfile /usr/local/bin/ && \
    rm -f helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz README.md LICENSE && \
    chmod +x /usr/local/bin/helm

# Installing helm's helm-secrets plugin (this one is used by helmfile)
USER 999
RUN /usr/local/bin/helm.bin plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION}
ENV HELM_PLUGINS="/home/argocd/.local/share/helm/plugins/"

# ArgoCD plugin definition
WORKDIR /home/argocd/cmp-server/config/
COPY plugin.yaml ./
