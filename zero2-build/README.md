# zero2-build — 可复现构建（Docker + ccache + ImageBuilder）

把“源码构建一次 → ImageBuilder 快速打包”的流程固化下来：容器镜像、config seed、
增量构建脚本、IB 打包脚本、以及只改应用包时的快打包入口。

## 目录

```
zero2-build/
├─ Dockerfile                 Ubuntu 24.04 + OpenWrt 依赖（含 ccache）
├─ configs/zero2.config       本次验证过的完整 .config（target/包列表/512MB rootfs/ccache）
├─ easytier/                  EasyTier ipk（架构已改为 aarch64_cortex-a53）
├─ scripts/
│  ├─ 00-sync.sh              同步源码到构建卷 + CRLF→LF + 首次注入 .config
│  ├─ 10-build.sh             feeds（首次）+ make -jN（增量）
│  ├─ 20-imagebuilder.sh      生成 IB、内置 EasyTier、重建索引、重打包
│  └─ 30-pack-image.sh        用 IB 快速出镜像（不编译源码）
├─ build.ps1                  Windows 宿主入口
└─ build.sh                   Linux/WSL 宿主入口
```

## 环境要求

- Docker Desktop（Linux 容器）或 Linux 上的 Docker
- 磁盘：构建卷首次约 8–12 GB，ccache 另计（建议留 30 GB）
- 内存：8 GB 以上；CPU 4 核以上

> 不要把源码目录直接挂进容器编译：`G:` 是 exFAT，不支持符号链接/chmod。
> 本流程把源码挂成 `/src` 只读用途，实际构建在 ext4 的 Docker volume `/build` 里。

## 快速开始（Windows PowerShell）

```powershell
cd G:\OpiZero2w\repo\zero2-build
.\build.ps1                      # sync + build + ib + image（首次约 40–90 分钟）
.\build.ps1 -Stage image         # 只重新打包镜像（1–3 分钟）
.\build.ps1 -Stage build         # 改驱动补丁后增量重编
```

指定输出目录/包列表：

```powershell
.\build.ps1 -Stage image -OutDir D:\out `
  -Packages "luci luci-app-passwall luci-i18n-passwall-zh-cn easytier-noweb luci-app-easytier"
```

## 快速开始（Linux / WSL）

```bash
cd /path/to/immortalwrt/zero2-build
./build.sh              # 全部
./build.sh image        # 只打包
./build.sh build        # 增量重编
```

## 阶段说明

| 阶段 | 作用 | 典型耗时 |
| --- | --- | --- |
| `sync` | rsync 到 `/build/repo`，CRLF→LF，首次注入 `.config` | 几秒 |
| `build` | feeds（仅首次）+ `make -j$(nproc)`，增量 | 首次 40–90 min，之后视改动 |
| `ib` | `make target/imagebuilder`，加 EasyTier、去签名、重打包 | 2–5 min |
| `image` | `make image PROFILE=xunlong_orangepi-zero2 PACKAGES=...` | 1–3 min |

## 缓存与增量

- **构建卷** `opizero2-build`：`build_dir/`、`staging_dir/`、`feeds/`、`dl/` 全部保留，
  所以 `10-build.sh` 是增量的；只有改驱动 patch / 内核 / 包源码时才需要重跑。
- **ccache**：`CONFIG_CCACHE=y`、`CONFIG_CCACHE_DIR="/build/ccache"` 已写进
  `configs/zero2.config`。清掉 `build_dir` 后重编也能命中大部分编译缓存。
- **IB**：`/build/ib` 保留，`image` 阶段直接复用；`ib` 阶段会重新生成。

## 配置

- 首次 `sync` 会把 `configs/zero2.config` 复制成 `/build/repo/.config`；
- 想改配置：进容器 `./build.ps1 -Stage shell`，`make menuconfig`，或直接改 `.config`；
- 想回到默认：删掉 `/build/repo/.config` 再跑 `sync`/`build`；
- `configs/zero2.config` 里已包含：target sunxi/cortexa53、DEVICE_xunlong_orangepi-zero2、
  LuCI、PassWall（Xray）、kmod-nft-tproxy/socket/nat、kmod-tun、iw/iwinfo、512 MB rootfs。

## ImageBuilder 快速换包

交付物里的 `immortalwrt-imagebuilder-sunxi-cortexa53-with-easytier.tar.zst` 也可脱离源码单独用：

```bash
tar -I zstd -xf immortalwrt-imagebuilder-sunxi-cortexa53-with-easytier.tar.zst
cd immortalwrt-imagebuilder-sunxi-cortexa53.Linux-x86_64
make image PROFILE=xunlong_orangepi-zero2 \
  PACKAGES="luci luci-i18n-base-zh-cn luci-app-passwall luci-i18n-passwall-zh-cn \
            easytier-noweb luci-app-easytier" \
  EXTRA_IMAGE_NAME="my-build"
```

该 IB 已去掉本地仓库签名检查（IB 里没有私钥），并已用“全新解压 → make image”验证过。

## 产物

默认输出到 `../images/`：

- `immortalwrt-passwall-easytier-sunxi-cortexa53-xunlong_orangepi-zero2-{squashfs,ext4}-sdcard.img.gz`
- `*.manifest`
- `immortalwrt-imagebuilder-sunxi-cortexa53-with-easytier.tar.zst`

## 注意

- EasyTier 的 `luci-app-easytier` 自带中文翻译，**不要**再装 `luci-i18n-easytier-zh-cn`（文件冲突）。
- 驱动补丁在 `package/kernel/mac80211/patches/unisoc/120-uwe5622-station-info.patch`，
  改它之后必须重跑 `build`（会重编 mac80211/kmod），再跑 `ib`/`image`。
- 首次构建会下载内核/mac80211/feed 包，网络不好时先配好代理或镜像。