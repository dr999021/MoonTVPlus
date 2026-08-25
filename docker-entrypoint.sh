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

# 仅当目录属主与目标不一致时才递归修正，避免每次启动全量遍历。
# 顶层目录属主匹配即视为无需处理（挂载卷通常整体属主一致）。
fix_owner() {
  dir="$1"
  [ -d "$dir" ] || return 0
  cur="$(stat -c '%u:%g' "$dir" 2>/dev/null)" || return 0
  if [ "$cur" != "${PUID}:${PGID}" ]; then
    echo "docker-entrypoint: fixing ownership of ${dir} (${cur} -> ${PUID}:${PGID})"
    chown -R nextjs:nodejs "$dir" 2>/dev/null || \
      echo "docker-entrypoint: warning: failed to chown ${dir}" >&2
  fi
}

if [ "$(id -u)" = "0" ]; then
  echo "docker-entrypoint: adjusting UID=${PUID} GID=${PGID}"

  # 重新创建 group 与 user，使其匹配指定的 UID/GID
  deluser nextjs 2>/dev/null || true
  delgroup nodejs 2>/dev/null || true
  addgroup -g "${PGID}" -S nodejs
  adduser -u "${PUID}" -D -S -G nodejs nextjs

  # /app 中仅应用运行时可写的子目录需要修正属主：
  # public（manifest）、.data（SQLite）、.next（缓存）。
  # 默认 1001 时镜像构建已通过 --chown 设置正确属主，无需任何处理；
  # 仅当 PUID/PGID 非默认值时才修正这些子目录。
  if [ "$PUID" != "1001" ] || [ "$PGID" != "1001" ]; then
    for d in /app/.data /app/.next /app/public; do
      fix_owner "$d"
    done
  fi

  # 数据目录（可能是宿主机挂载卷）：仅在属主不匹配时修正。
  # /data 为默认离线下载目录，OFFLINE_DOWNLOAD_DIR 可另行指定。
  for dir in /data "${OFFLINE_DOWNLOAD_DIR:-/data}"; do
    fix_owner "$dir"
  done

  # 降权执行实际命令
  exec su-exec nextjs:nodejs "$@"
fi

# 非 root 直接执行
exec "$@"
