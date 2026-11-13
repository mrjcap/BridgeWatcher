FROM mcr.microsoft.com/dotnet/runtime:11.0.0-alpine3.24-amd64

# renovate: datasource=github-releases depName=PowerShell/PowerShell
ARG POWERSHELL_VERSION=7.7.0
ARG PUID=99
ARG PGID=100

# Install PowerShell and dependencies
# hadolint ignore=DL3018
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache --upgrade \
        tzdata \
        ca-certificates \
        curl \
        icu-libs \
        icu-data-full \
        krb5-libs \
        libgcc \
        libintl \
        libssl3 \
        libstdc++ \
        zlib && \
    curl --fail --show-error --silent --location \
        "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-musl-x64.tar.gz" \
        -o /tmp/powershell.tar.gz && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    rm /tmp/powershell.tar.gz && \
    cp /usr/share/zoneinfo/Europe/Athens /etc/localtime && \
    echo "Europe/Athens" > /etc/timezone && \
    rm -rf /var/cache/apk/*

ENV TZ=Europe/Athens
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV XDG_CACHE_HOME=/tmp/.cache
ENV XDG_CONFIG_HOME=/tmp/.config
ENV XDG_DATA_HOME=/tmp/.local/share

# Smart user creation - reuse 'users' group for GID 100
RUN if [ "${PGID}" = "100" ]; then \
        adduser -D -u ${PUID} -G users -h /home/appuser -s /bin/sh appuser; \
    else \
        addgroup -g ${PGID} appgroup && \
        adduser -D -u ${PUID} -G appgroup -h /home/appuser -s /bin/sh appuser; \
    fi && \
    mkdir -p /home/appuser/scripts/modules \
            /app/logs \
            /tmp && \
    chown -R ${PUID}:${PGID} /home/appuser /app/logs && \
    chmod -R 755 /home/appuser /app/logs && \
    chmod 1777 /tmp

USER appuser
WORKDIR /home/appuser/scripts

COPY --chmod=0555 ./BridgeWatcher ./modules/BridgeWatcher
COPY --chmod=0555 run.ps1 .

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-File", "./run.ps1"]

# hadolint ignore=DL3025
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD ["sh", "-c", "test -n \"$(find \"${BRIDGEWATCHER_OUT:-/app/logs}\" -maxdepth 1 -name bridge_status.json -mmin -10 2>/dev/null)\""]
