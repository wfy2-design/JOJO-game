# 机械演算 · CTB-game

> MECHA CTB TACTICS — 一款基于 Godot 4 的 CTB（Conditional Turn-based Battle）同格战棋游戏。
> A CTB (Conditional Turn-based Battle) grid tactics game built with Godot 4.

---

## 简介 · Introduction

**中文**

《机械演算》是一款 1v1 / 2v2 / 3v3 的同格战棋游戏。玩家通过蛇形选角组建机娘小队，在可变大小的菱形棋盘上，依据 CTB 行动条依次行动，运用技能、状态与地形效果击败对手。游戏内置六名原创机娘角色、二十四项技能、六章交互式教程，以及火焰/冰霜粒子特效。

**English**

*Mecha CTB Tactics* ("机械演算") is a 1v1 / 2v2 / 3v3 grid tactics game. Players draft a squad of mecha-girls through a snake draft, then act in order on the CTB timeline across a variable-size diamond board, using skills, status effects and terrain to defeat the opponent. It features six original mecha-girl characters, twenty-four skills, a six-chapter interactive tutorial, and fire/ice particle effects.

---

## 特性 · Features

- **蛇形选角 Snake Draft**：1v1 = `1-1`、2v2 = `1-2-1`、3v3 = `1-2-2-1`；先手随机，AI 随机选角，不支持悔选。
- **可变棋盘 Variable Board**：5×5 / 6×6 / 7×7 三种规格。
- **出生方式 Spawn Mode**：固定（两队分居两角）或随机（角色完全随机散布）。
- **CTB 行动条 Timeline**：`S = 100 / 速度`，S 越小越先行动。
- **战斗机制 Combat**：免费移动 2 格、冲刺 4 格、曼哈顿距离命中衰减、暴击、防御减伤、AP 与技能系统。
- **状态与地形 Status & Terrain**：点燃、火墙、束缚、镜域标记、时停等。
- **粒子特效 Particle FX**：火墙火焰、冰系技能冰晶（`GPUParticles2D` 程序化生成，无需外部素材）。
- **六章教程 6-Chapter Tutorial**：3×3 小棋盘分章演示，支持目录与关键词跳转。
- **开始流程 Start Flow**：主页（TITLE）→ 模式选择（MODE）→ 作战简报（CONFIG）→ 选角（DRAFT）→ 战斗（BATTLE）。

---

## 下载与运行 · Download & Run

**方式一 · 直接游玩（无需 Godot）**

前往本仓库 [Releases](../../releases) 下载 `机械演算.exe`，双击即玩。

*Option 1 · Play directly (no Godot required)*

*Download `机械演算.exe` from [Releases](../../releases) and double-click to play.*

**方式二 · 用 Godot 打开项目**

需要 Godot 4.3 或更新的 Godot 4 稳定版。

```powershell
godot --path godot_game --editor
```

*Option 2 · Open the project in Godot*

*Requires Godot 4.3+ stable.*

```powershell
godot --path godot_game --editor
```

---

## 导出 · Export

**中文**

需要与所用 Godot 版本一致的导出模板（export templates）。安装模板后：

```powershell
godot --headless --path godot_game --export-release "Windows Desktop" "机械演算.exe"
```

`export_presets.cfg` 已启用 `embed_pck`，导出结果为单个 `.exe`，双击即玩。

**English**

*Install the export templates matching your Godot version, then run:*

```powershell
godot --headless --path godot_game --export-release "Windows Desktop" "mecha.exe"
```

*`export_presets.cfg` enables `embed_pck`, producing a single `.exe` that runs standalone.*

---

## 操作 · Controls

| 键位 Key | 动作 Action |
| --- | --- |
| `A` | 普通攻击 / Basic attack |
| `E` | 打开技能页 / Skill list |
| `C` | 防御 / Defend |
| `M` | 移动模式 / Move mode |
| `WASD` / 方向键 | 逐格移动 / Move |
| `Shift` | 冲刺 / Sprint |
| `Esc` | 取消 / 撤销 / Cancel / Undo |
| `Num1~Num4` | 技能选择 / Select skill |
| `Tab` | 打开菜单 / Open menu |
| 鼠标 Mouse | 选择格子、技能与同格目标 / Select cells, skills and targets |

---

## 项目结构 · Project Structure

```text
godot_game/
├── core/            # 战斗数据与逻辑（BattleData / BattleModel）
├── ui/              # 棋盘、选角、开始流程、暂停菜单
├── tutorial/        # 六章教程（剧本 + 控制器）
├── assets/          # 角色立绘、头像、字体
├── tests/           # 无头测试与截图脚本
└── tools/           # 资源处理脚本（Python）
```

---

## 测试 · Tests

```powershell
godot --headless --path godot_game --script res://tests/test_battle_model.gd
godot --headless --path godot_game --script res://tests/test_draft.gd
godot --headless --path godot_game --script res://tests/test_tutorial_scenario.gd
godot --headless --path godot_game --script res://tests/test_pause_menu.gd
```

---

## 许可 · License

角色立绘与头像为项目自有素材；字体采用开源字体（得意黑 / 思源黑体 / Bebas Neue / Yuji Syuku），许可证见 `godot_game/assets/fonts/licenses/`。

*Character art is project-owned; fonts are open-source (Smiley Sans / Source Han Sans CN / Bebas Neue / Yuji Syuku), see `godot_game/assets/fonts/licenses/` for licenses.*
