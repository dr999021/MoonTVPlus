#!/bin/sh
# ============================================================
# 支持通过 PUID / PGID 环境变量指定容器运行时的 UID / GID。
# 默认值 1001 / 1001，与镜像内预创建的 nextjs 用户保持一致。
# 容器以 root 启动，脚本调整用户/组并修正数据目录属主后，
# 通过 su-exec 降权为指定用户运行实际命令。
# 若镜像被以非 root 用户启动（如 OpenShift 随机 UID），
# 则跳过调整直接执行。
# ============================================================
set -e

PUID="${PUID:-1001}"
PGID="${PGID:-1001}"

if [ "$(id -u)" = "0" ]; then
  echo "docker-entrypoint: adjusting UID=${PUID} GID=${PGID}"

  # 重新创建 group 与 user，使其匹配指定的 UID/GID
  deluser nextjs 2>/dev/null || true
  delgroup nodejs 2>/dev/null || true
  addgroup -g "${PGID}" -S nodejs
  adduser -u "${PUID}" -D -S -G nodejs nextjs

  # 修正应用目录与数据目录属主。
  # 应用运行时需写入 /app 下的 public（manifest）、.data（SQLite）、.next（缓存）等；
  # /data 为默认离线下载目录，也可能是宿主机挂载卷，同样一并修正。
  for dir in /app /data "${OFFLINE_DOWNLOAD_DIR:-/data}"; do
    if [ -d "$dir" ]; then
      chown -R nextjs:nodejs "$dir" 2>/dev/null || \
        echo "docker-entrypoint: warning: failed to chown ${dir}" >&2
    fi
  done

  # 降权执行实际命令
  exec su-exec nextjs:nodejs "$@"
fi

# 非 root 直接执行
exec "$@"
