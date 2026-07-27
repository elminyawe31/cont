FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    ROOT_PASSWORD=ELMINYAWE \
    TZ=UTC \
    LANG=en_US.UTF-8

# 1. تثبيت الحزم الأساسية + SSH
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server sudo curl wget git vim nano htop tmux \
      zip unzip tar rsync net-tools iproute2 iputils-ping dnsutils \
      build-essential python3 python3-pip ca-certificates gnupg lsb-release \
      bash-completion locales tzdata cron && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# 2. تحميل أداة ttyd (للترمينال في المتصفح)
RUN curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64" \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# 3. تحميل أداة cloudflared (لإنشاء الدومين أوتوماتيكياً)
RUN curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
      -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# 4. إعداد الـ SSH
RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 5. سكريبت التشغيل الذكي
COPY <<'EOF' /entrypoint.sh
#!/usr/bin/env bash
set -e

echo "================================================"
echo "  Smart me - Starting Services..."
echo "================================================"

# ضبط الباسورد وتشغيل SSH
echo "root:${ROOT_PASSWORD}" | chpasswd
/usr/sbin/sshd

# تشغيل الـ Web Terminal في الخلفية على بورت 8080
/usr/local/bin/ttyd --port 8080 --writable --credential "root:${ROOT_PASSWORD}" /bin/bash -l &

echo "  Waiting for Cloudflare to generate public URL..."
echo "================================================"

# تشغيل Cloudflare في الخلفية وحفظ اللوج
/usr/local/bin/cloudflared tunnel --url http://localhost:8080 > /tmp/cf.log 2>&1 &
sleep 10

# استخراج الدومين من اللوج وعرضه بوضوح
URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf.log | head -n 1)

echo "================================================"
echo "  ✅ WEB TERMINAL IS READY!"
echo "  Link: ${URL:-Waiting...}"
echo "  User: root"
echo "  Pass: ${ROOT_PASSWORD}"
echo "================================================"
echo "  SSH User: root | SSH Pass: ${ROOT_PASSWORD}"
echo "  (SSH Port: 22 - Requires TCP Proxy in Railway)"
echo "================================================"

# إبقاء الحاوية تعمل وعرض لوج Cloudflare
tail -f /tmp/cf.log
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 8080 22

CMD ["/entrypoint.sh"]
