#!/bin/bash
source shell/custom-packages.sh
echo "第三方软件包: $CUSTOM_PACKAGES"
echo "Building for profile: $PROFILE"
echo "Include Docker: $INCLUDE_DOCKER"
echo "Building for ROOTFS_PARTSIZE: $ROOTSIZE"

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  echo "🔄 正在同步第三方软件仓库..."
  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo
  mkdir -p /home/build/immortalwrt/extra-packages
  cp -r /tmp/store-run-repo/run/arm64/* /home/build/immortalwrt/extra-packages/
  echo "✅ Run files copied to extra-packages:"
  ls -lh /home/build/immortalwrt/extra-packages/*.run
  sh shell/prepare-packages.sh
  ls -lah /home/build/immortalwrt/packages/
fi

LUCI_VERSION="${LUCI_VERSION:-25.12.0}"
case "$PROFILE" in
  rpi-3) CPU_ARCH="aarch64_cortex-a53" ;;
  rpi-4) CPU_ARCH="aarch64_cortex-a72" ;;
  rpi-5) CPU_ARCH="aarch64_cortex-a76" ;;
  *)     CPU_ARCH="aarch64_generic" ;;
esac

# 25.12 使用 apk 包管理器，不需要修改 repositories.conf
echo "✅ 25.12 使用 apk，跳过 repositories.conf 修改"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting build process..."

PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# Docker
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# OpenClash 内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加内核"
    mkdir -p files/etc/openclash/core
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
    URL=$(curl -s https://api.github.com/repos/vernesong/OpenClash/releases/latest \
      | grep "browser_download_url.*ipk" | head -n1 | cut -d '"' -f 4)
    echo "OpenClash latest: $URL"
    wget "$URL" -P /home/build/immortalwrt/packages/
fi

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image..."
echo "$PACKAGES"
make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
