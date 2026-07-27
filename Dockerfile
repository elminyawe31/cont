FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    SSH_PORT=22 \
    TZ=UTC \
    LANG=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server sudo curl wget git vim nano htop tmux \
      zip unzip tar rsync net-tools iproute2 iputils-ping dnsutils \
      build-essential python3 python3-pip ca-certificates gnupg lsb-release \
      software-properties-common locales tzdata cron bash-completion man-db \
      jq less file passwd openssh-client && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in amd64) t=x86_64;; arm64) t=aarch64;; *) t="$arch";; esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

COPY <<'EOF' /entrypoint.sh
#!/usr/bin/env bash
set -e

ROOT_PASSWORD="${ROOT_PASSWORD:-ELMINYAWE}"
WEB_PORT="${PORT:-8080}"
SSH_P="${SSH_PORT:-22}"

echo "================================================"
echo "  Smart me - Started Successfully"
echo "================================================"
echo "  SSH User: root"
echo "  SSH Pass: ${ROOT_PASSWORD}"
echo "  Web Terminal Port: ${WEB_PORT}"
echo "  Internal SSH Port: ${SSH_P}"
echo "------------------------------------------------"
echo "  Browser Access: Open your Railway project URL."
echo "================================================"

echo "root:${ROOT_PASSWORD}" | chpasswd

ssh-keygen -A 2>/dev/null || true
/usr/sbin/sshd -p "${SSH_P}"

exec /usr/local/bin/ttyd \
  --port "${WEB_PORT}" \
  --writable \
  --credential "root:${ROOT_PASSWORD}" \
  /bin/bash -l
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 8080 22

CMD ["/entrypoint.sh"]
