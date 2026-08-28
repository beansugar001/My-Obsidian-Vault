# HowToFish 自瞄 Mod 开发日志

## 目标

开发一个基于 BepInEx 5 的《How to Fish》自瞄 Mod，支持单机和私人联机房间，可通过按键开关，并发布到 GitHub。

## 关键决策

- 使用 BepInEx 5.4.23.5 + Harmony，不修改原版 `Assembly-CSharp.dll`。
- 通过 Harmony Patch 接管 `PlayerAimAssist.GetRotationDelta`，只影响本地摄像机瞄准。
- 默认 `F8` 开关，可在 BepInEx 配置中修改。
- 默认只瞄准活鱼/活生物，不对玩家自动瞄准。
- 发布范围定位为单机/私人联机，README 明确提示不要用于公开房间。

## 游戏技术信息

- 游戏目录：`D:\steam\steamapps\common\How to Fish\How to Fish`
- 游戏类型：Unity Mono x64，Unity `6000.4.4f1`
- 网络框架：FishNet，游戏支持 1-4 人合作
- 相关类：`PlayerAimAssist`、`PlayerCamera`、`ItemManager`、`Item`、`Creature`
- 现有 BepInEx 插件：`DpsMeter.dll`
- 参考项目：`e8xl/HowToFish-Trainer`（MIT）

## 项目状态

- 源码：`HowToFish.AimBot/Plugin.cs`
- 项目目录：`D:\project\how-to-fish-aimbot`
- 构建产物：`artifacts/HowToFish.AimBot.dll`
- 游戏安装：`BepInEx/plugins/HowToFish.AimBot/HowToFish.AimBot.dll`
- 配置：`BepInEx/config/com.beansugar.howtofish.aimbot.cfg`

## 已完成验证

- 插件编译通过，0 warning / 0 error。
- 游戏启动后 BepInEx 日志显示：
  `Loading [How to Fish Aim Bot 1.0.0]`
  `How to Fish Aim Bot loaded. Aim bot is on. Press F8 to toggle.`
- 配置文件自动生成，默认参数正常。

## 待办

- [ ] 用户确认后写入 Obsidian memory
- [x] 用户确认后发布 GitHub 仓库与 Release
- [ ] 可选：进一步测试 F8 热键切换和实际吸附手感

## GitHub 发布

- 仓库：https://github.com/beansugar001/HowToFish-AimBot
- Release：https://github.com/beansugar001/HowToFish-AimBot/releases/tag/v1.0.0
- 资产：`HowToFish-AimBot-v1.0.0.zip`

## v1.1.0 体验反馈更新

- 默认热键从 `F8` 改为 `F1`。
- 左上角新增自瞄状态按钮，显示 `Aim: ON/OFF`，点击也可切换。
- 右下角新增弹药 HUD，显示 `当前子弹/弹匣容量`。
- 新增配置：`ShowStatusButton`、`ShowAmmoHud`。
- 版本计划更新为 `v1.1.0`，需要重新安装 DLL 并发布新 Release。
- v1.1.0 已编译、安装并启动验证：`How to Fish Aim Bot loaded. Aim bot is on. Press F1 to toggle.`
- 已生成并发布 `HowToFish-AimBot-v1.1.0.zip`。
- v1.1.0 Release：https://github.com/beansugar001/HowToFish-AimBot/releases/tag/v1.1.0

## v1.1.1 性能优化

- 用户反馈功能测试时掉帧。
- 主要原因：自瞄每帧遍历 `ItemManager` 物品并做多次 `Physics.Linecast`。
- 优化：按 `ScanInterval` 缓存最佳目标，只在新扫描周期遍历一次。
- 优化：合并生物/物品扫描，去掉 `Distinct()` 和每帧 ammo 文本查询。
- 新增配置：`ScanInterval`，默认 `0.1` 秒。
- v1.1.1 已安装并启动验证：`How to Fish Aim Bot loaded. Aim bot is on. Press F1 to toggle.`
- v1.1.1 Release：https://github.com/beansugar001/HowToFish-AimBot/releases/tag/v1.1.1
- 等待用户进行帧率复测。

## v1.2.0 目标切换

- 用户提出打 Boss 鱼时目标很多，需要切换自瞄目标。
- 新增 `F2` 按键：在候选目标列表里循环切换到下一个。
- 候选目标仍按短间隔扫描缓存，不恢复每帧全量遍历。
- 新增配置：`NextTargetKey`，默认 `F2`。
- v1.2.0 已安装并启动验证：`How to Fish Aim Bot loaded. Aim bot is on. Press F1 to toggle.`
- v1.2.0 Release：https://github.com/beansugar001/HowToFish-AimBot/releases/tag/v1.2.0
- 待确认贡献者 GitHub 用户名后添加 contributor。
- 已添加 `tourisLY` 到 README Contributors 段落。

## v1.3.0 准心

- 用户提出射击点添加一个点作为准心，方便自瞄关闭时手动瞄准。
- 用户进一步说明：不是屏幕中心，而是枪械准星/红点激光位置，且需要绿色圆形准心。
- 已改为投影 `LaserSight` 红点/Decal 位置，或回退到 `FirePoint`。
- 新增配置：`ShowCrosshair`、`CrosshairOnlyWhenAimDisabled`、`CrosshairSize`、`LockStrength`。
- 自瞄锁定强度默认提升到 `1.5`。

## v1.4.0 死亡不掉落

- 用户提出增加死亡不掉落。
- 新增配置：`KeepItemsOnDeath`，默认 `true`。
- 通过 Harmony 拦截死亡/重生流程中的 `ServerDropAll`、手持物品 `Drop`、`SetSyncedHolder` 和 `StartSimulateLocal`，保留背包和手持物品。
- 死亡不掉落由服务器/房主侧逻辑生效；加入未安装本 Mod 的房间时，物品掉落仍由房主原版逻辑决定。
- v1.4.0 已编译、安装并启动验证：`Loading [How to Fish Aim Bot 1.4.0]`，配置已生成 `KeepItemsOnDeath = true`。
- 已生成 `HowToFish-AimBot-v1.4.0.zip`。
- 等待用户实测死亡不掉落，并确认同步 `D:\project`、Obsidian 和 GitHub Release。

## 构建命令

```powershell
.\build.ps1 -GameDir "D:\steam\steamapps\common\How to Fish\How to Fish"
.\install.ps1 -GameDir "D:\steam\steamapps\common\How to Fish\How to Fish"
```
