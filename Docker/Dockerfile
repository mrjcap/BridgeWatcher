FROM mcr.microsoft.com/powershell:7.5-alpine-3.20
RUN apk update && \
    apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Europe/Athens /etc/localtime && \
    echo "Europe/Athens" > /etc/timezone
RUN mkdir -p /scripts/modules
EXPOSE 8090
WORKDIR /scripts
COPY ./BridgeWatcher /scripts/modules/BridgeWatcher
COPY Docker/entrypoint.sh /scripts/
COPY run.ps1 /scripts/
COPY Docker/.env /scripts/
RUN chmod +x /scripts/entrypoint.sh
ENTRYPOINT ["sh","/scripts/entrypoint.sh"]
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
CMD pwsh -Command "if (Test-Path '/tmp/bridge_status.json' -NewerThan (Get-Date).AddMinutes(-10)) { exit 0 } else { exit 1 }"
