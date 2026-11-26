## 安装包

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Windows x64 | `dsh-pet-emoji-windows-x64.zip` | 解压后运行 `dsh_pet_emoji.exe` |
| Android | `dsh-pet-emoji-android.apk` | 允许「安装未知来源应用」后安装 |
| iOS | `dsh-pet-emoji-ios-unsigned.ipa` | **未签名**，需用 AltStore / Sideloadly / 自签证书重签 |

装好后打开设置填入 DeepSeek API Key，即可开始对话。

## 已知限制

- **Android**：APK 使用 debug 密钥签名（Flutter 默认模板行为），可直接安装，
  但无法上传应用商店；如需上架请自备 keystore 并改 `android/app/build.gradle.kts`。
- **iOS**：IPA 未签名，必须重签后才能安装；`dsh-pet-emoji-ios-app.zip` 里是原始
  `Runner.app`，便于自行签名。
- **Windows**：未做代码签名，SmartScreen 可能提示「未知发布者」。

## 源码

GitHub 自动附带的 `Source code (zip / tar.gz)` 即为完整源码，
含全部动画素材（114 段 640×360 动画 WebP + 114 段 WebM 母版）与语义标注清单。

## 许可

- **代码**：MIT
- **素材与形象**：CC BY-NC-SA 4.0（署名 · 非商业 · 相同方式共享），不可商用
- **上游项目**：<https://github.com/PC2005-cloud/dsh-pet>
- **形象**：社区二创 DeepSeek「大肥鱼」（鲸鱼娘），**非 DeepSeek 官方形象**；
  原型「溟月」出自 B 站 @上善无形，DeepSeek 版设计出自 B 站 @ZipZipPipe

衍生 / 改版 / 换皮作品须在 GitHub 仓库、产品官网等公开渠道附上上游地址：
`https://github.com/PC2005-cloud/dsh-pet`
