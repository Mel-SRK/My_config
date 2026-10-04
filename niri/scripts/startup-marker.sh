#!/bin/bash
# 在 swaybg 启动时记录时间，检测实际渲染延迟
sleep 0.5
echo "swaybg launched at: $(date +%s.%N)" >> /tmp/login-time.log
