FROM mcr.microsoft.com/powershell:7.5-alpine-3.20

ARG PUID=99
ARG PGID=100

RUN apk update && \
    apk add --no-cache tzdata=2025b-r0 && \
    cp /usr/share/zoneinfo/Europe/Athens /etc/localtime && \
    echo "Europe/Athens" > /etc/timezone && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

RUN addgroup -g ${PGID} appgroup && \
    adduser -D -u ${PUID} -G appgroup -h /home/appuser -s /bin/sh appuser

RUN mkdir -p /home/appuser/scripts/modules \
             /home/appuser/logs \
             /home/appuser/output \
             /home/appuser/.cache \
             /home/appuser/.local && \
    chown -R appuser:appgroup /home/appuser && \
    chmod -R 755 /home/appuser

RUN mkdir -p /tmp && chmod 1777 /tm

USER appuser
WORKDIR /home/appuser/scripts

COPY --chown=appuser:appgroup ./BridgeWatcher ./modules/BridgeWatcher
COPY --chown=appuser:appgroup Docker/entrypoint.sh /home/appuser/scripts/entrypoint.sh
COPY --chown=appuser:appgroup run.ps1 .

EXPOSE 8090

ENTRYPOINT ["sh", "./entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pwsh -Command "if (Test-Path '/home/appuser/output/bridge_status.json' -NewerThan (Get-Date).AddMinutes(-10)) { exit 0 } else { exit 1 }"