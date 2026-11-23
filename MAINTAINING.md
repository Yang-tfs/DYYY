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

**修复**（`8697039`）：`IESLiveStackView layoutSubviews` 改为只在用户显式设置昵称/元素缩放时应用缩放 transform，否则恢复 identity；不再对每个嵌套层施加全屏位移。CI 构建验证通过：[run #45171418708](https://github.com/Yang-tfs/DYYY/actions/runs/45171418708)（artifact `DYYY-20261123201600`）。**待真机复测确认**。

### 4.1 构建中修复的编译问题记录

前三次 CI 失败及修复（均已提交）：
1. `AwemeHeaders.h` 中后台播放类写成 category → 改为普通 `@interface`（`a2e8a1e`）；
2. `DYYYUtils.m` 中 v3.0 探针函数 `DYYYAppendViewTree` 与 fork 原有同名函数签名冲突 → 重命名为 `DYYYAppendViewTreeWithProbes`（`2ea0d4c`）；
3. huami patch 把两个旧类声明**改名**导致 fork 原 hook 只有前向声明 → 恢复旧类名声明、与 41.x 新类名并存；同时移除我新增的与 fork 重复的 `AWEPlayInteractionUserAvatarOptElementElement layoutElementView` hook（`4a77fde`）。

**教训**：fork 与 huami v3.0 差异巨大，任何从 v3.0 直接 `git apply` 的补丁都必须逐行核对是否与 fork 原有声明/函数重名，尤其是集中式头文件 `AwemeHeaders.h` 里的类声明。

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
