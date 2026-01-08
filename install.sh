#!/bin/bash

# 1. בדיקה שרצים כ-Root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (sudo ./install.sh)"
  exit
fi

PLACEHOLDER="PUT_YOUR_KEY_HERE"

# 2. יצירת .env אם לא קיים
if [ ! -f .env ]; then
    echo "⚠️ .env file not found! Creating one from template..."
    cp .env.example .env 2>/dev/null || touch .env
fi

# 3. וידוא שהמשתמש הזין מפתחות
while grep -q "$PLACEHOLDER" .env; do
    clear
    echo "==================================================="
    echo "🛑  CONFIGURATION REQUIRED / נדרשת הגדרה ראשונית"
    echo "==================================================="
    echo "Please enter your Bybit API Keys in the opened editor."
    echo ""
    echo "👉 Press [ENTER] to open nano editor."
    read -p "" 
    nano .env
    echo "Checking configuration..."
    sleep 1
done

echo "✅ Configuration found!"
echo ""

# 4. משיכת הגרסה העדכנית מהענן (במקום בנייה)
echo "☁️  Pulling latest version from Docker Hub..."
docker-compose pull

# 5. הרמת התשתיות
echo "🚀 Starting services..."
docker-compose up -d db listener dashboard

# 6. הכנת המנג'ר לטיימר (יצירה ללא הפעלה)
echo "🛠️  Initializing Manager state..."
docker-compose create manager

# 7. התקנת הטיימרים (Systemd)
echo "⚙️  Setting up Systemd Timer..."

cat <<EOF > /etc/systemd/system/bot-manager.service
[Unit]
Description=Bybit Docker Manager Executor
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/docker start -a bot_manager

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/bot-manager.timer
[Unit]
Description=Run Bot Manager 3 seconds before every 5-minute candle

[Timer]
OnCalendar=*:4/5:57
Persistent=true
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable bot-manager.timer
systemctl start bot-manager.timer

echo ""
echo "✅✅✅ INSTALLATION COMPLETE! ✅✅✅"
echo "Monitor the bot: docker logs -f bot_listener"