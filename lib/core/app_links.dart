/// 全局常量与对外链接。
///
/// `kRepoOwner` 是本仓库的账号名。若要迁移到其他账号 / 组织，执行
/// `bash tool/set_owner.sh <新用户名>`，它会以本文件的值为准，一次性替换
/// README、docs、NOTICE 等全部文档与代码中的地址。
library;

const String kAppName = '大肥鱼桌宠';
const String kAppNameEn = 'DSH Pet Emoji';
const String kVersion = '1.2.0';

/// 应用内的品牌图（标题栏 logo、欢迎页图标）。
///
/// 由 `tool/gen_icons.py` 从 `tool/brand/app_icon.ico` 的 256 档导出，
/// 三端启动图标与界面内形象因此始终是同一个。
const String kBrandIconPath = 'assets/brand/app_icon.png';

/// 本仓库（Flutter 版）。
const String kRepoOwner = 'OperationSkuld';
const String kRepoName = 'dsh-pet-emoji';
const String kRepoUrl = 'https://github.com/$kRepoOwner/$kRepoName';

/// 原作者仓库：任何衍生 / 改版 / 换皮作品都必须在公开渠道附上此地址。
const String kUpstreamRepoUrl = 'https://github.com/PC2005-cloud/dsh-pet';

/// 形象出处。
const String kPrototypeAuthor = 'B 站 @上善无形';
const String kPrototypeAuthorUrl = 'https://space.bilibili.com/4456176';
const String kDeepSeekDesigner = 'B 站 @ZipZipPipe';
const String kDeepSeekDesignerUrl = 'https://space.bilibili.com/4168597';
const String kLicenseStatementUrl =
    'https://www.bilibili.com/opus/1247156596114456581';
const String kLicenseStatement =
    '大肥鱼是遵守CC BY-NC-SA 4.0协议的形象，不可以以任何形式商业化。'
    '若您非常喜爱该形象，希望其拥有实体，您可以自行定制。';

/// DeepSeek 开放平台。
const String kDefaultBaseUrl = 'https://api.deepseek.com';
const String kDefaultModel = 'deepseek-chat';
const List<String> kSupportedModels = ['deepseek-chat', 'deepseek-reasoner'];
