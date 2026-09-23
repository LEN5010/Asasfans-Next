# 品牌素材来源

`asasfans.png` 保留自本仓库 `v2.0.0` 的 `app/src/main/res/mipmap-xxxhdpi/icon_asasfans_next_logo.png`，不覆盖历史素材。项目继承自 `A-SoulFan/as-as-fans`，沿用仓库 GPL-2.0 许可证和历史归属。

2026-09-23 的四端图标使用既有 `asasfans_logo.svg` 的原始 A 路径与 #F2569B → #E5187C 渐变，不重描、不生成替代字形。原母版保留不变；`asasfans_mark.svg` / PNG 是透明的应用内标志。各 `asasfans_icon_*.svg` 是分离的平台底板/前景源文件。

- iOS：全幅不透明白底，不预置圆角和阴影；按 Assets 的尺寸清单生成。
- macOS：透明外边距、一层浅色圆角底板，无预烘焙阴影；Assets 与 `macos/packaging/icon` 使用逐字节相同 PNG，打包 icns 仍由原脚本产生。
- Windows：透明 A 标志，ICO 含 16/24/32/48/64/128/256 像素图层，不叠加圆角白底。
- Android：保留 API 24/25 的传统启动图；API 26 起白底与透明前景分层，前景缩入中心安全区；API 33 增加同一路径的单色图标。未改变 minSdk 或应用身份。

可复现生成入口：`node tool/brand/generate_icons.cjs`，需要当前环境提供 `sharp`（本次 0.35.4 / libvips 8.18.6，可通过 NODE_PATH 指向现有运行时）。不下载依赖、不改 Flutter 依赖锁、不签名或打包。所有小尺寸从矢量超采样生成，没有声称经过设备视觉验收；实际遮罩、Dock/任务栏观感由用户集中验收。
