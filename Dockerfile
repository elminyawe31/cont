FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROOT_PASSWORD=ELMINYAWE

# 1. تثبيت الحزم الأساسية + SSH + أدوات السيرفر
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server sudo curl wget git vim nano htop tmux \
    build-essential python3 python3-pip net-tools iproute2 \
    bash-completion locales tzdata && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# 2. إعداد الـ SSH والباسورد
RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "root:${ROOT_PASSWORD}" | chpasswd

# 3. تحميل سكريبت تشغيل ذكي جداً (بيعالج مشكلة بورت Railway)
COPY <<'EOF' /start.sh
#!/bin/bash
# Railway بياخد البورت من المتغير PORT
WEB_PORT=${PORT:-8080}

echo "================================================"
echo "  Smart Server - Ready!"
echo "================================================"
echo "  Web Terminal: Just open the Railway URL."
echo "  SSH User: root | SSH Pass: ${ROOT_PASSWORD}"
echo "================================================"

# تشغيل SSH في الخلفية
echo "root:${ROOT_PASSWORD}" | chpasswd
/usr/sbin/sshd

# تشغيل الترمينال في المتصفح على بورت Railway
# باستخدام أداة gotty الخفيفة جداً والمتوافقة مع Railway
exec /usr/local/bin/gotty -w --port ${WEB_PORT} --credential "root:${ROOT_PASSWORD}" /bin/bash -l
EOF

# 4. تحميل أداة gotty (أخف وأذكى من ttyd لـ Railway)
RUN curl -fsSL "https://github.com/sorenisanerd/gotty/releases/latest/download/gotty_1.5.0_linux_amd64.tar.gz" -o /tmp/gotty.tar.gz && \
    tar -xzf /tmp/gotty.tar.gz -C /usr/local/bin/ gotty && \
    chmod +x /usr/local/bin/gotty && \
    rm /tmp/gotty.tar.gz

# 5. إعطاء صلاحيات للسكريبت
RUN chmod +x /start.sh

# 6. إخبار Railway إن الخدمة على بورت 8080 (البورت اللي Railway بيحبه)
EXPOSE 8080

# 7. التشغيل
CMD ["/start.sh"]
