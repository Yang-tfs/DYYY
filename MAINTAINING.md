# DYYY 维护接手文档

> 适用仓库：`Yang-tfs/DYYY`（fork）
> 接手日期：2026-11-23
> 当前工作分支：`sync-v3.0`（已推送到 fork 的 `origin/sync-v3.0`）

---

## 1. 项目定位与仓库关系（先搞清楚谁是谁）

| 仓库 | 角色 | 最后更新 | 状态 |
|---|---|---|---|
| `Wtrwx/DYYY` | fork 的**直接上游**（fork 就是它的逐字节镜像，零独有提交） | 2026-10-25 | 已停滞 |
| `huami1314/DYYY` | 真正活跃的上游，已改名 **DYYY3 v3.0.2**，适配抖音 41.2.0 | 2026-11-21 | 活跃（CI 绿色） |
| `Yang-tfs/DYYY` | 你的 fork，用于接管维护 | 同步于 Wtrwx 2026-10-25 | 本次开始维护 |

**关键结论：**
- "原作者停止更新"指的是 `Wtrwx` 主线；`huami1314` 在 2026-11-20/21 重新适配了 41.x（抖音把 UI 迁到 Swift、换了播放架构，旧版大量功能失效）。
- `huami1314` 的 v3.0 是**重写版**：文件数 98 → 55，删除了全屏协调器、评论毛玻璃协调器、悬浮按钮协调器、测试套件等；且与 fork **没有共同提交历史**（`git merge` 不可用）。
- 因此本次同步策略是：**保留 fork 架构，移植 v3.0 的 41.2.0 适配修复**（用户已确认）。

## 2. 项目结构速览

基于 Theos/Logos 的抖音 UI Tweak，Objective-C / Logos（`.xm`），ARC，Logos generator = `internal`（无 substrate 依赖，可 TrollFools 注入）。

- **Hook 入口**：`DYYY.xm`（Feed、倍速、全屏、底栏等全局 Hook）；`DYYYSettings.xm`（设置页、远程配置入口）。
- **业务核心**：`DYYYManager`（下载/批量任务/媒体合成）、`DYYYSettingsHelper`（设置依赖、入口、协议）、`DYYYUtils`（无状态工具）、`CityManager`（属地）。
- **架构组件（fork 独有，务必保留）**：`DYYYFullscreenCoordinator`、`DYYYCommentBlurCoordinator`、`DYYYFloatingButtonCoordinator`、`DYYYFullscreenGeometry`、`DYYYCommentPlaybackCoordinator`、`AWMSafeDispatchTimer`、`DYYYDownloadScheduler`。
- **隐私/登录**：`DYYYLoginBypassManager`、`DYYYPrivacyRecordUploadGuard` 及对应 Hook。
- **构建**：`Makefile`（`SCHEME=rootful/rootless/roothide`、`GITHUB_ACTIONS=true make package`）。
- **CI**：`.github/workflows/build.yml` 构建三种 Deb 并抽 arm64e dylib；`publish-release.yml` 根据 build 结果发 Release（12h 冷却、目标分支校验）。

维护约定详见仓库内 `AGENTS.md`（头文件集中管理、Manager/Utils 职责边界、Hook 规范等）。

## 3. 本次同步内容（`sync-v3.0` 分支，3 个提交）

基准：fork `main` = `49867e1`；移植来源：`huami1314/DYYY` `6c3dfbd..9f35660`（v3.0 → v3.0.2）。

### 3.1 已移植的 41.2.0 适配

| 文件 | 改动 | 说明 |
|---|---|---|
| `control`、`DYYYConstants.h` | 版本号 `2.2-9` → `3.0.2` | 与上游 v3.0.2 对齐 |
| `AwemeHeaders.h` | 2 处类改名（Pendant、FullPageFeed）+ 新增 v3.0 同步声明段 | 41.x Swift 类名变化 |
| `DYYY.xm` | 详情页 `fixedCellHeight` / `originalTableViewHeight` 基准修复（5 个类） | 修复全屏下 873/956 行高混排、文案上移 |
| `DYYY.xm` | 长按倍速：实时档位返回 + `AWEDSpeed*` 容器族钩子 + 倍速文案正则替换 | 41.x 倍速卡在设定值无法调档 |
| `DYYY.xm` | 头像/加号隐藏：Element `setHide:`、`AWEPlayInteractionUserProfileContainerView`、`setHidden:` 兜底、新管理类名 | 41.x 头像结构变化 |
| `DYYY.xm` | 底栏仅在有按钮隐藏时才重新均匀布局 | 41.x 不等宽 tab 被挤偏 |
| `DYYY.xm` | 图文状态栏容器、发布引导/任务卡、挂件 Swift 类改名兜底 | 保留旧类名，双版本兼容 |
| `DYYY.xm` | 评论黑底 label 清理、信息流视频占用控制中心的两个新写入口拦截 | 沿用 fork 更强的清理实现，补方法名 |
| `DYYY.xm` | 摇一摇导出视图树（调试） | 对应设置项 `DYYYShakeExportViewTree` |
| `DYYYUtils.h/.m` | `describeViewTree:`（约 180 行只读运行时探针） | 摇一摇导出实现 |
| `DYYYSettings.xm` | 新增"摇一摇导出视图树"开关 | — |
| `DYYYLongPressPanel.xm` | 评论长按面板逐 Element `elementShouldShow` 隐藏（8 个类，`objc_getClass` 动态绑定） | 替代 41.x 失效的 `setModelsArray:` 过滤；**保留 fork 独有的"隐藏收藏"** |
| `.github/workflows/build.yml` | push 触发分支增加 `sync-v3.0` | 用于云端验证本次移植 |

### 3.2 刻意**没有**移植的内容（避免破坏 fork 架构）

- huami v3.0 的评论毛玻璃暴力清底补丁：fork 已有 `DYYYCommentBlurCoordinator` 精细管理，直接叠加会重复/冲突。
- huami v3.0 对 `AWEAwemeDetailTableView setFrame:` 的重写：fork 由 `DYYYFullscreenCoordinator` 处理全屏布局，覆盖会丢功能。
- huami v3.0 删除的测试套件、协调器文件：全部保留。
- huami 的"私有 framework/C++ 构建改动"：未涉及（v3.0 差异中没有必要项）。

### 3.3 兼容性设计

所有 41.x 新类名均以**追加**方式引入，旧类名 hook 全部保留 → 同一二进制理论上兼容 36.5.0–41.2.0；`objc_getClass` 动态解析保证类不存在时安全跳过。

## 4. 验证状态

| 检查项 | 状态 | 说明 |
|---|---|---|
| Logos 结构完整性 | ✅ 通过 | `DYYY.xm`: 336 `%hook` + 16 `%group` = 352 `%end`；`DYYYLongPressPanel.xm`: 16+9=25，均平衡 |
| 引用完整性 | ✅ 通过 | `describeViewTree:` / `getActiveWindow` / `showToast:` 均在 `DYYYUtils.h/.m` 存在；新类声明已补入 `AwemeHeaders.h` |
| 静态管线测试 | ⚠️ 部分 | `tests/run_pipeline_regressions.py` 在 UTF-8 模式下通过静态检查，随后因 Windows 无 macOS `clang`/Apple frameworks 无法编译（预期限制） |
| GitHub Actions 云端编译 | ✅ 通过 | [run #45166185863](https://github.com/Yang-tfs/DYYY/actions/runs/45166185863) success；产物 `DYYY-20261123193455`：3 个 Deb（rootful/rootless/roothide）+ `DYYY_3.0.2.dylib` |
| 真机回归 | ⏳ 待做 | 需 macOS + 越狱/注入环境（建议 iPhone XR / iOS 16 / 抖音 40.7.0 与 41.2.0 双版本） |

### 4.0 IPA 静态核对（用户提供的砸壳包）

用户提供砸壳 IPA：`C:\Users\Yang\Desktop\dyyy维护\抖音_41.2.0.ipa`。静态核对结果：

| 项目 | 结果 |
|---|---|
| Info.plist | `CFBundleShortVersionString=41.2.0`，`CFBundleVersion=412021`，`MinimumOSVersion=15.0`，arm64 |
| 加密状态 | 无 `LC_ENCRYPTION_INFO_64`（已砸壳） |
| 实际代码位置 | 主二进制 `Aweme` 仅 276 KB；hook 目标类全部在 `Frameworks/AwemeCore.framework/AwemeCore`（约 1 GB） |
| v3.0 移植涉及的 35 个类/方法名 | **全部命中** AwemeCore（含 `AWEDSpeedCoreContainer`、`AWEPlayInteractionUserProfileContainerView`、`CommentLongPressPanel*`、`elementShouldShow`、`handleFastSpeed:`、`updateNowPlayingInfoWhenResiginActive` 等） |
| Swift 类模块名 | `AWECommentLongPressPanelSwiftImpl` / `AWECommentIMSwiftImpl` / `AWECommentCommerceSwiftImpl` 等模块名与类名组件均存在，dotted 全名在 Swift metadata 中分段存储（非连续字符串），`objc_getClass` 的写法与 v3.0 一致 |

结论：本次移植的 hook 目标与用户实际的抖音 41.2.0 二进制**完全匹配**，不是"按文档猜类名"。临时提取文件已清理。

### 4.0.1 真机反馈修复：推荐页直播全屏错位

用户提供摇一摇视图树导出（`C:\Users\Yang\Desktop\1.txt`），发现推荐页直播全屏显示错位。

**诊断**：直播信息层所有 `IESLiveStackView` 被强制 `translateY=-20`（日志中 −20/−40/−131 逐层累加）。根因是 `DYYY.xm` 中 2025 年的临时 hack（提交 `b289285` "不知道谁改的 写死把"）：把计算好的 `tx/ty` 丢弃，对每个嵌套 StackView 无条件写死 `CGAffineTransformMakeTranslation(0, -20)`。41.2.0 直播 cell 已是原生全屏高度，该补偿纯属多余且因嵌套累积导致错位。

**修复过程**：
1. `8697039`：移除 `IESLiveStackView` 写死的 −20 位移（日志确认生效：顶层从 `y=-20` 变 `y=0`）。
2. `7ead417`：`AWEElementStackView` 直播分支同步移除全屏重复位移。
3. 用户复测仍"控件被遮挡、关闭全屏后正常"。用**绝对坐标**重新分析日志（frame 相对父视图，需逐级累加）发现真正主因：直播底部控件在屏幕 **y≈831~926**，而底栏 `AWENormalModeTabBar` 覆盖 **y=843~926** 且背景 `alpha=1.00` 完全不透明——底栏没为直播场景透明化。
4. `0d33faa`：尝试让底栏为直播透明化（登记直播控制器）。真机复测反馈：**底栏标签与主播名重叠**——透明化后直播 UI 仍按 926 全屏高度排版，主播名伸进底栏区域，只是从"被遮挡"变成"文字重叠"。
5. `0d33faa`/`c12c12e`：尝试底栏透明化、直播 cell 不撑高。真机复测反馈：底栏与主播名重叠，且**刷视频会卡死**。
6. `07bbd83`（当前版本，**回滚**）：上述针对直播遮挡的 3~5 步改动**全部回滚**，代码恢复到 `c812537` 稳定基线（仅保留第 1、2 步已验证生效的 −20 位移修复）。卡死疑似由 `AWEFeedTableView layoutSubviews` 中遍历 `visibleCells` 并改 frame 引发布局重入。

7. `e56da84` / `18411dc`：继续修正两处误判
   - `e56da84`：撤销底栏透明化 + 只对含 `AWELivePrestreamGuideView` 的层位移 → 用户反馈"上移太多"；
   - `18411dc`：改为固定 `translateY=-(底栏高度+12)` → 用户反馈"毫无变化"。
   - **关键教训（务必记住）**：`convertRect:toView:window` + `view.frame` 在滚动 tableView 里不可用。直播 cell 的 `contentOffset` 可达数万，`frame` 又被自身 transform 污染，每次 layout 累加会把 view 算到屏幕外（实测出现过 `y=-18426`）。任何"按窗口坐标算位移"的写法都必须禁止。
8. `0e23c3a`（**最终修复，用户已确认生效**）：
   - 真正被遮的不是 `AWELivePrestreamGuideView`，而是**整个直播信息层**：`IESLiveStackView` 根容器为 `{12,0,404,926}`（宽 404 < 屏宽 428，说明只含 UI、不含视频），其底部信息块（"直播中"状态、主播名 `@xxx`、直播标题、地区标签）排在 y=831~926，正好落在透明底栏 843~926 的文字区；
   - 在 `IESLiveStackView layoutSubviews` 中识别**根容器**（`bounds.height ≥ 屏高-2` 且 `bounds.width < 屏宽-2`），只对它施加固定 `translateY(-底栏高度)`；其下所有底部信息一起上移，视频渲染层是兄弟视图不受影响；
   - 底栏透明化保留（用户要的"首页全屏那样的透明底栏"）；
   - 删除此前改错对象的 `AWELivePrestreamGuideView` hook；
   - 约束不变：**不碰 `AWEFeedTableView` frame、不遍历 `visibleCells`**（那是刷视频卡死的根因）。

**当前版本 CI 构建通过**：[run #45385706562](https://github.com/Yang-tfs/DYYY/actions/runs/45385706562)。
本地 dylib 只保留这一份：`DYYY_3.0.2_run45385706562.dylib`（SHA-256 `A8CA0668EE750FC8094BD31564E90D87AD5382568423F51BCDB18C4A6F37AC81`）。
真机复测结果：**已修复**（用户 2026-11-24 确认"修好了"）。

**排查方法论（避免重蹈覆辙）**：
- 先看**截图**确认现象，再对着摇一摇视图树找对应 class；纯靠 frame 数值推断极易误判（日志里 frame 是相对父视图的，需逐级累加，且受 transform 影响）。
- 直播 pre-stream 结构：`AWEFeedLiveStreamTableViewCell` → `AWELiveNewPreStreamViewController` → `AWELivePreStream4LayerContainerView`（视频渲染 + `IESLiveStackView` UI 层是兄弟）；底部信息块 `IESLiveLayoutContainerView {0,831,404,95}`。
- 底栏：`AWENormalModeTabBar {0,843,428,83}`；透明化后背景无 bg、但按钮文字仍在。

### 4.1 构建中修复的编译问题记录

前三次 CI 失败及修复（均已提交）：
1. `AwemeHeaders.h` 中后台播放类写成 category → 改为普通 `@interface`（`a2e8a1e`）；
2. `DYYYUtils.m` 中 v3.0 探针函数 `DYYYAppendViewTree` 与 fork 原有同名函数签名冲突 → 重命名为 `DYYYAppendViewTreeWithProbes`（`2ea0d4c`）；
3. huami patch 把两个旧类声明**改名**导致 fork 原 hook 只有前向声明 → 恢复旧类名声明、与 41.x 新类名并存；同时移除我新增的与 fork 重复的 `AWEPlayInteractionUserAvatarOptElementElement layoutElementView` hook（`4a77fde`）。

**教训**：fork 与 huami v3.0 差异巨大，任何从 v3.0 直接 `git apply` 的补丁都必须逐行核对是否与 fork 原有声明/函数重名，尤其是集中式头文件 `AwemeHeaders.h` 里的类声明。

## 4.2 本地 dylib 留存（每次构建后必做）

按用户要求：以后每次 CI 构建成功后，都在本地留一份 dylib。

- **存放目录**：`DYYY\artifacts\dylib\`（已加入 `.gitignore`，不会被提交到仓库）
- **命名**：`DYYY_<版本号>_run<run-id>.dylib`，例如 `DYYY_3.0.2_run45171418708.dylib`
- **现有一份**：`DYYY_3.0.2_run45385706562.dylib`（2.92 MB，SHA-256 `A8CA0668EE750FC8094BD31564E90D87AD5382568423F51BCDB18C4A6F37AC81`），来自直播底栏遮挡最终修复 run #45385706562

**自动下载脚本**：`DYYY\scripts\fetch-artifact.ps1`

```powershell
# 下载最近一次成功 build deb run 的 dylib（默认行为）
powershell -ExecutionPolicy Bypass -File scripts/fetch-artifact.ps1

# 下载指定 run 的 dylib
powershell -ExecutionPolicy Bypass -File scripts/fetch-artifact.ps1 -RunId 45171418708
```

脚本从本机 Git 凭据管理器读取 GitHub token，无需用户交出账号密码；同一 run 重复运行会跳过已存在文件（加 `-Force` 可覆盖）。以后我每次触发构建并确认成功后，会立即运行该脚本留存 dylib 并报告 SHA-256。

## 4.3 新增功能记录

### 隐藏「真实生活分享计划」横幅（`403ff07`）

- **开关路径（已确认）**：抖音 → 我 → 设置 → DYYY 设置 → **隐藏设置** → **消息页与我的页** → **隐藏真实生活分享计划**（`DYYYHideUGCContributionBanner`，该分类第 15 项，带副标题"隐藏我的页「真实生活分享计划」发布引导横幅"）。也可在 DYYY 设置顶部搜索框搜「真实生活」快速定位。
- **真机验证**：✅ 用户 2026-11-27 确认功能生效。
- **对应 UI**：我的页头部、图标行下方的"真实生活分享计划 / 发作品有机会获得流量激励 / 去发布"横幅
- **实现**（`DYYY.xm`）：
  - 主修改在数据层 `AWEUserProfileUGCHeaderContributionGuideBannerSectionViewModel`：
    `isShowingContributionGuideBanner` 返回 NO、`sectionSize` 返回 `CGSizeZero`，横幅不显示且**不留 58pt 空白**；
  - 兜底隐藏 `AWEUserProfileUGCHeaderContributionGuideBannerSectionCell` 与 `AWEUserProfileUGCContributionGuideCollectionViewCell`。
- **类名核对**：在抖音 41.2.0 砸壳 `AwemeCore` 二进制中确认存在
  `AWEUserProfileUGCHeaderContributionGuideBannerSectionController` / `...SectionViewModel`
  及 `sectionSize`（`{CGSize=dd}`）与 `isShowingContributionGuideBanner`（BOOL 属性）。
- **CI**：[run #46019583460](https://github.com/Yang-tfs/DYYY/actions/runs/46019583460)；dylib `DYYY_3.0.2_run46019583460.dylib`（SHA-256 `697CF081F635FEA2A87282CD38EF731EE984C23B083929BC4975F7649E63D7EC`）。

## 5. 下一步操作清单（用户侧）

1. **触发云端构建**（二选一）：
   - 打开 <https://github.com/Yang-tfs/DYYY/actions/workflows/build.yml> → `Run workflow` → 分支选 `sync-v3.0` → 运行；
   - 或直接向 `main` 提 PR（`sync-v3.0` → `main`），push 事件会自动构建。
2. **检查构建**：确认 3 个 Deb（rootful/rootless/roothide）与 arm64e dylib 产物齐全；若有编译错误，把 Actions 日志发来继续修。
3. **真机验证**（重点）：抖音 41.2.0 上逐项验证——详情页全屏翻页/文案位置、长按倍速上下调档、头像/加号隐藏、底栏按钮、评论长按菜单隐藏项、控制中心占用、摇一摇导出。
4. **发布**：验证通过后，在 Actions 里手动 `publish release`（先用 `skip_cooldown=true` 的 workflow_dispatch 指向成功的 build run ID），或直接把 `sync-v3.0` 合入 `main` 触发自动发布链。
5. **后续同步**：已添加 `upstream` remote（`huami1314/DYYY`）。后续 huami 更新时：
   ```bash
   git fetch upstream
   git diff HEAD upstream/main -- <files>
   ```
   按本文件第 3 节的"保留架构 + 移植修复"原则逐项移植，不要直接 merge。

## 6. 分支与提交一览

```
sync-v3.0
  e62af5e docs: 注明 3.0.2 版本号来源（触发 CI 构建验证）
  6337ef1 ci: 允许 sync-v3.0 分支推送触发构建验证
  a904a84 sync: 移植 huami1314 DYYY3 v3.0.2 的抖音 41.2.0 适配到 fork 架构
  49867e1 (main) fix: 稳定文案分页与清屏切换布局
```

远端：<https://github.com/Yang-tfs/DYYY/tree/sync-v3.0>
