FROM mcr.microsoft.com/powershell:7.5-alpine-3.20

# Install packages and cleanup in single layer για μικρότερο image size
RUN apk update && \
    apk add --no-cache tzdata=2025b-r0 && \
    cp /usr/share/zoneinfo/Europe/Athens /etc/localtime && \
    echo "Europe/Athens" > /etc/timezone && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

# Create non-root user με specific UID για consistency
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup -h /home/appuser

# Create necessary directories με περισσότερη δομή
RUN mkdir -p /home/appuser/scripts/modules \
             /home/appuser/logs \
             /home/appuser/output && \
    chown -R appuser:appgroup /home/appuser && \
    # Create tmp directory που ελέγχει το healthcheck
    mkdir -p /tmp && chmod 1777 /tmp

# Switch to non-root user
USER appuser
WORKDIR /home/appuser/scripts

# Copy files - το entrypoint.sh χρειάζεται special handling
COPY --chown=appuser:appgroup ./BridgeWatcher ./modules/BridgeWatcher
COPY --chown=appuser:appgroup Docker/entrypoint.sh /home/appuser/scripts/entrypoint.sh
COPY --chown=appuser:appgroup run.ps1 .

# Ensure entrypoint is executable (δεν χρειάζεται RUN chmod γιατί δεν έχουμε shell access)
# Αντί αυτού, κάνε το executable locally: chmod +x Docker/entrypoint.sh

EXPOSE 8090

# Use shell form για το entrypoint επειδή είναι shell script
ENTRYPOINT ["sh", "./entrypoint.sh"]

# Healthcheck με path που έχει σίγουρα access ο appuser
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pwsh -Command "if (Test-Path '/home/appuser/output/bridge_status.json' -NewerThan (Get-Date).AddMinutes(-10)) { exit 0 } else { exit 1 }"