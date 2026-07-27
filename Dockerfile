FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    ROOT_PASSWORD=ELMINYAWE \
    TZ=UTC \
    LANG=en_US.UTF-8

# 1. تثبيت الحزم الأساسية + إضافة آلية إعادة محاولة لـ apt
RUN apt-get update -y || (sleep 5 && apt-get update -y) && \
    apt-get install -y --no-install-recommends \
      openssh-server sudo curl wget git vim nano htop tmux \
      zip unzip tar rsync net-tools iproute2 iputils-ping dnsutils \
      build-essential python3 python3-pip ca-certificates gnupg lsb-release \
      software-properties-common locales tzdata cron bash-completion man-db \
      jq less file passwd openssh-client && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# 2. تحميل أداة ttyd
RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in amd64) t=x86_64;; arm64) t=aarch64;; *) t="$arch";; esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# 3. تحميل أداة cloudflared
RUN curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
      -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# 4. إعداد الـ SSH
RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 5. سكريبت التشغيل
COPY <<'EOF' /entrypoint.sh
#!/usr/bin/env bash
set -e

echo "================================================"
echo "  Smart me - Starting Services..."
echo "================================================"

echo "root:${ROOT_PASSWORD}" | chpasswd
/usr/sbin/sshd

/usr/local/bin/ttyd --port 8080 --writable --credential "root:${ROOT_PASSWORD}" /bin/bash -l &

echo "  Waiting for Cloudflare to generate public URL..."
echo "================================================"

/usr/local/bin/cloudflared tunnel --url http://localhost:8080 > /tmp/cf.log 2>&1 &
sleep 10

URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf.log | head -n 1)

echo "================================================"
echo "  ✅ WEB TERMINAL IS READY!"
echo "  Link: ${URL:-Waiting...}"
echo "  User: root"
echo "  Pass: ${ROOT_PASSWORD}"
echo "================================================"

tail -f /tmp/cf.log
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 8080 22

CMD ["/entrypoint.sh"]
