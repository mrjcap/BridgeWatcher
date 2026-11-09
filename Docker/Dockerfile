FROM mcr.microsoft.com/dotnet/runtime:10.0.14-alpine3.24-amd64

# renovate: datasource=github-releases depName=PowerShell/PowerShell
ARG POWERSHELL_VERSION=7.6.3
ARG PUID=99
ARG PGID=100

# Install PowerShell and dependencies
# hadolint ignore=DL3018
RUN apk update && \
    apk add --no-cache \
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

# Smart user creation - reuse 'users' group for GID 100
RUN if [ "${PGID}" = "100" ]; then \
        adduser -D -u ${PUID} -G users -h /home/appuser -s /bin/sh appuser; \
    else \
        addgroup -g ${PGID} appgroup && \
        adduser -D -u ${PUID} -G appgroup -h /home/appuser -s /bin/sh appuser; \
    fi
# Use UID:GID directly - always works!
RUN mkdir -p /home/appuser/scripts/modules \
            /home/appuser/logs \
            /home/appuser/output \
            /home/appuser/.cache \
            /home/appuser/.local \
            /app/logs && \
    chown -R ${PUID}:${PGID} /home/appuser /app/logs && \
    chmod -R 755 /home/appuser /app/logs

RUN mkdir -p /tmp && chmod 1777 /tmp

USER appuser
WORKDIR /home/appuser/scripts

COPY --chown=${PUID}:${PGID} ./BridgeWatcher ./modules/BridgeWatcher
COPY --chown=${PUID}:${PGID} Docker/entrypoint.sh /home/appuser/scripts/entrypoint.sh
COPY --chown=${PUID}:${PGID} run.ps1 .

EXPOSE 8090

ENTRYPOINT ["sh", "./entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pwsh -Command "if (Test-Path '/app/logs/bridge_status.json' -NewerThan (Get-Date).AddMinutes(-10)) { exit 0 } else { exit 1 }"
