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
- [ ] 用户确认后发布 GitHub 仓库与 Release
- [ ] 可选：进一步测试 F8 热键切换和实际吸附手感

## 构建命令

```powershell
.\build.ps1 -GameDir "D:\steam\steamapps\common\How to Fish\How to Fish"
.\install.ps1 -GameDir "D:\steam\steamapps\common\How to Fish\How to Fish"
```
