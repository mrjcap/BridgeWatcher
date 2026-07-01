FROM mcr.microsoft.com/powershell:7.4-alpine

ARG PUID=99
ARG PGID=100

# Install dependencies and set timezone
RUN apk update && \
    apk add --no-cache \
        tzdata=2026b-r0 \
        su-exec && \
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

# USER appuser (run as root to read secrets, then drop privileges in entrypoint.sh via su-exec)
WORKDIR /home/appuser/scripts

COPY --chown=${PUID}:${PGID} ./BridgeWatcher ./modules/BridgeWatcher
COPY --chown=${PUID}:${PGID} Docker/entrypoint.sh /home/appuser/scripts/entrypoint.sh
COPY --chown=${PUID}:${PGID} run.ps1 .

EXPOSE 8090

ENTRYPOINT ["sh", "./entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pwsh -Command "\$outDir = \$Env:BRIDGEWATCHER_OUT; if ([string]::IsNullOrWhiteSpace(\$outDir)) { \$outDir = '/home/appuser/output' }; if (Test-Path \"\$outDir/bridge_status.json\" -NewerThan (Get-Date).AddMinutes(-10)) { exit 0 } else { exit 1 }"