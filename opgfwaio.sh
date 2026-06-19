#!/bin/bash
set -e

# ======================================================
# Part 1: 安装 OpenGFW
# ======================================================

echo ">>> 下载 OpenGFW 二进制..."
wget -O /usr/local/bin/opengfw https://github.com/ruaue/OpenGFW/releases/download/v0.3.2/OpenGFW-linux-amd64
chmod +x /usr/local/bin/opengfw

echo ">>> 下载配置文件..."
mkdir -p /etc/opengfw
wget -O /etc/opengfw/config.yaml https://raw.githubusercontent.com/Nyafish/conf/refs/heads/main/config.yaml
wget -O /etc/opengfw/rules.yaml https://raw.githubusercontent.com/Nyafish/conf/refs/heads/main/rules.yaml

echo ">>> 创建 opengfw systemd 服务..."
cat > /etc/systemd/system/opengfw.service << 'EOF'
[Unit]
Description=OpenGFW
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/opengfw -c /etc/opengfw/config.yaml /etc/opengfw/rules.yaml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable opengfw
systemctl start opengfw

# ======================================================
# Part 2: 部署内存监控（内存 ≥ 95% 时重启 opengfw）
# ======================================================

echo ">>> 创建内存监控脚本..."
cat > /usr/local/bin/opengfw-mem-monitor.sh << 'EOF'
#!/bin/bash
MEM_USAGE=$(free | awk '/Mem/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -ge 95 ]; then
    systemctl restart opengfw
    logger -t opengfw-monitor "Memory usage at ${MEM_USAGE}%, restarted opengfw service"
fi
EOF
chmod +x /usr/local/bin/opengfw-mem-monitor.sh

echo ">>> 创建内存监控 service & timer..."
cat > /etc/systemd/system/opengfw-mem-monitor.service << 'EOF'
[Unit]
Description=OpenGFW memory monitor

[Service]
Type=oneshot
ExecStart=/usr/local/bin/opengfw-mem-monitor.sh
EOF

cat > /etc/systemd/system/opengfw-mem-monitor.timer << 'EOF'
[Unit]
Description=Run opengfw memory monitor every minute

[Timer]
OnCalendar=*:*
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable opengfw-mem-monitor.timer
systemctl start opengfw-mem-monitor.timer

# ======================================================
echo ""
echo "============================================"
echo " 安装完成"
echo "============================================"
echo "opengfw 二进制: /usr/local/bin/opengfw"
echo "配置文件:       /etc/opengfw/"
echo "服务状态:       $(systemctl is-active opengfw)"
echo "内存监控:       已部署（每分钟检查，≥95% 重启 opengfw）"
echo ""
echo "常用命令:"
echo "  systemctl status opengfw              查看服务状态"
echo "  systemctl restart opengfw             重启 opengfw"
echo "  journalctl -u opengfw -f              查看实时日志"
echo "  journalctl -t opengfw-monitor         查看内存监控日志"
echo "============================================"
