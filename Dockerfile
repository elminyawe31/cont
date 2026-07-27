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

# تعيين الباسورد افتراضياً لو لم يتم تحديده في متغيرات البيئة
ROOT_PASSWORD="${ROOT_PASSWORD:-ELMINYAWE}"
WEB_PORT="${PORT:-7681}"
SSH_P="${SSH_PORT:-22}"

echo "================================================"
echo "  Smart me - Started Successfully"
echo "================================================"
echo "  SSH User: root"
echo "  SSH Pass: ${ROOT_PASSWORD}"
echo "  Internal Port: ${SSH_P}"
echo "------------------------------------------------"
echo "  Browser Access: Open your Railway project URL."
echo "================================================"

# تطبيق الباسورد على نظام التشغيل
echo "root:${ROOT_PASSWORD}" | chpasswd

# تشغيل SSH
ssh-keygen -A 2>/dev/null || true
/usr/sbin/sshd -p "${SSH_P}"

# تشغيل الويب تيرمينال
exec /usr/local/bin/ttyd \
  --port "${WEB_PORT}" \
  --writable \
  --credential "root:${ROOT_PASSWORD}" \
  --title "Smart me" \
  /bin/bash -l
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 22 7681

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT:-7681}/" || exit 1

CMD ["/entrypoint.sh"]
