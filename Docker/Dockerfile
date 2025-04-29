FROM mcr.microsoft.com/powershell:7.5-alpine-3.20
RUN apk update && \
    apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Europe/Athens /etc/localtime && \
    echo "Europe/Athens" > /etc/timezone
RUN mkdir -p /scripts/modules
EXPOSE 8090
WORKDIR /scripts
COPY ./BridgeWatcher /scripts/modules/BridgeWatcher
COPY entrypoint.sh /scripts/
COPY run.ps1 /scripts/
RUN chmod +x /scripts/entrypoint.sh
ENTRYPOINT ["/scripts/entrypoint.sh"]
