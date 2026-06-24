FROM mcr.microsoft.com/dotnet/runtime:10.0.9-alpine3.23

ARG PUID=99
ARG PGID=100

# Install PowerShell and dependencies
RUN apk update && \
    apk add --no-cache \
        tzdata=2026b-r0 \
        ca-certificates=20260611-r0 \
        curl=8.19.0-r0 \
        icu-libs=76.1-r1 \
        krb5-libs=1.22.1-r0 \
        libgcc=15.2.0-r2 \
        libintl=0.24.1-r1 \
        libssl3=3.5.7-r0 \
        libstdc++=15.2.0-r2 \
        zlib=1.3.2-r0 && \
    curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.6.3/powershell-7.6.3-linux-musl-x64.tar.gz \
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
            /home/appuser/.local && \
    chown -R ${PUID}:${PGID} /home/appuser && \
    chmod -R 755 /home/appuser

RUN mkdir -p /tmp && chmod 1777 /tmp

USER appuser
WORKDIR /home/appuser/scripts

COPY --chown=appuser:appgroup ./BridgeWatcher ./modules/BridgeWatcher
COPY --chown=appuser:appgroup Docker/entrypoint.sh /home/appuser/scripts/entrypoint.sh
COPY --chown=appuser:appgroup run.ps1 .

EXPOSE 8090

ENTRYPOINT ["sh", "./entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pwsh -Command "if (Test-Path '/home/appuser/output/bridge_status.json' -NewerThan (Get-Date).AddMinutes(-10)) { exit 0 } else { exit 1 }"