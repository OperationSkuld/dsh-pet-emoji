# 发布流程

## 0. 先替换仓库占位符

仓库里凡是 `OWNER` 都是占位符（README 徽章、文档链接、`lib/core/app_links.dart`、
workflow 里的下载地址）。创建仓库后执行一次：

```bash
bash tool/set_owner.sh <你的GitHub用户名>
git add -A && git commit -m "chore: point links to <用户名>"
```

## 1. 创建 GitHub 仓库

网页方式：<https://github.com/new> → 仓库名 `dsh-pet-emoji` → **不要**勾选
「Add a README / .gitignore / license」（本地已有）。

命令行方式（需已 `gh auth login`）：

```bash
gh repo create dsh-pet-emoji --public --source=. --remote=origin --push
```

## 2. 推送

```bash
git remote add origin https://github.com/<用户名>/dsh-pet-emoji.git
git branch -M main
git push -u origin main
```

首次 push 约 123MB（67MB GIF + 56MB WebM），慢是正常的。
若超过单文件 100MB 限制才会被拒——本仓库最大的文件约 0.9MB，不会触发。

## 3. 本地构建

```bash
flutter pub get

# Windows（需要 Visual Studio「使用 C++ 的桌面开发」）
flutter build windows --release
# 产物: build/windows/x64/runner/Release/

# Android（需要 Android SDK + JDK 17）
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk

# iOS（只能在 macOS 上）
flutter build ios --release --no-codesign
# 产物: build/ios/iphoneos/Runner.app
```

### macOS 上打未签名 ipa

```bash
cd build/ios/iphoneos
mkdir -p Payload && cp -R Runner.app Payload/
zip -qry ../../../dsh-pet-emoji-ios-unsigned.ipa Payload
```

用 AltStore / Sideloadly / 自己的开发者证书重签后即可安装。

## 4. 自动发布（推荐）

打 tag 即触发 `.github/workflows/release.yml`：

```bash
git tag v1.0.0
git push origin v1.0.0
```

流水线会并行构建三端，然后创建 GitHub Release 并附上：

| 文件 | 内容 |
| --- | --- |
| `dsh-pet-emoji-windows-x64.zip` | Windows 绿色包，解压即用 |
| `dsh-pet-emoji-android.apk` | 通用 APK |
| `dsh-pet-emoji-ios-unsigned.ipa` | 未签名 ipa，需自签 |
| `dsh-pet-emoji-ios-app.zip` | 未签名 `.app`，方便自行签名 |
| Source code (zip/tar.gz) | GitHub 自动附带的完整源码 |

也可以手动触发：Actions → Release → Run workflow（不填 tag 时只产出 artifact）。

## 5. 签名说明

- **Android**：Flutter 模板默认用 debug 签名构建 release，APK 可直接安装。
  要上架应用商店，请自己生成 keystore 并配置 `android/key.properties`
  （该文件已被 `.gitignore` 忽略），不要提交私钥。
- **iOS**：未签名 ipa 无法直接安装，这是 iOS 的机制，不是构建问题。
  正式分发需要 Apple Developer 账号 + 描述文件 + `flutter build ipa`。
- **Windows**：未做代码签名，SmartScreen 会提示「未知发布者」，属预期行为。

## 6. 版本号

`pubspec.yaml` 的 `version: 1.0.0+1` 同时决定：

- `version`：应用版本（Windows 文件版本、iOS CFBundleShortVersionString）
- `+1`：构建号（Android versionCode、iOS CFBundleVersion）

发版时同步更新 `CHANGELOG.md`。
