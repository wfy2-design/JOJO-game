# 游戏教程（1v1 引导）设计与实现文档

> 目标：在开始游戏界面新增「游戏教程」选项，通过两个角色 1v1 的演示对局，
> 每一步操作配以辅助说明，通俗易懂地讲清游戏规则。
>
> 适用范围：`E:\game\godot_game`（Godot 4.3+，GDScript，代码构建 UI）。

---

## 1. 目标与定位

### 1.1 要解决的问题

当前游戏规则较复杂（CTB 行动条、曼哈顿距离与命中衰减、AP/冲刺、24 个技能、
点燃/火墙/束缚/标记/时停等状态），新玩家直接进入「本地双人」或「玩家对 AI」
很容易看不懂。现有 `pause_menu.gd` 里的 **GUIDE 四页规则**（`MenuThemeData.RULE_PAGES`）
是纯文字速查，缺少"看得见、动起来"的过程演示。

### 1.2 教程定位

| 内容 | 定位 | 形式 |
|------|------|------|
| 教程（本文档） | 过程演示、建立直觉 | 1v1 脚本化对局 + 逐步说明 |
| 暂停菜单 GUIDE | 规则速查、查漏补缺 | 四页文字（已存在） |
| 暂停菜单 ARCHIVE | 角色/技能详情 | 图鉴（已存在） |

三者互补：**教程负责"第一次看懂"**，GUIDE/ARCHIVE 负责"之后想查"。

### 1.3 非目标（第一版不做）

- 不覆盖全部 24 个技能，只演示**共享规则 + 1~2 个代表性状态效果**。
- 不做技能/角色深度教学（交给 ARCHIVE）。
- 不做多语言（沿用现有中文子页面风格）。

---

## 2. 现状梳理（可复用的部分）

| 资产 | 路径 | 作用 |
|------|------|------|
| 战斗模型 | `core/battle_model.gd` | 全部规则逻辑：移动、命中、伤害、CTB、技能、状态、胜负。**教程每一步都调用它，保证演示与实战规则一致**。 |
| 角色/技能数据 | `core/battle_data.gd` | `characters()` 返回六角色定义，含 24 技能。 |
| 棋盘渲染 | `ui/board_view.gd` | `set_model()` 渲染棋盘与角色，`set_highlights()` 显示移动/命中/技能高亮（已支持命中百分比文字）。**可直接复用，无需重写棋盘**。 |
| 技能文案 | `ui/menu/menu_theme_data.gd` | `skill_summary()` / `skill_description()` 已写好全部技能说明，教程可引用。 |
| 开始界面 | `main.gd` → `_show_mode_menu()`（约 267–313 行） | 当前只有「本地双人」「玩家对 AI」两个按钮，教程按钮加在这里。 |
| 无头测试 | `tests/test_battle_model.gd` | 演示了如何用固定种子、直接驱动 model 的方法，教程脚本编写可参考同一模式。 |

关键结论：**教程不需要重写任何战斗规则**，只需要
1. 一个"剧本"数据结构描述每一步（说什么、做什么、高亮哪里）；
2. 一个"导演"控制器按剧本驱动 `BattleModel` + `BoardView`；
3. 一个精简的说明面板 + 步骤控制条；
4. 在开始菜单加一个入口按钮。

---

## 3. 方案选型

### 方案 A：自动演示（脚本回放）—— 推荐首发 ✅

两名角色按**预先写好的剧本**自动走一步，每步配一句说明；玩家用
「上一步 / 下一步 / 重播 / 返回」控制节奏，全程不操作角色。

- 优点：实现最简单、结果确定（固定种子）、文案与动作一一对应、易维护、易本地化。
- 缺点：玩家只看不动，参与感较弱。
- 结论：**完全匹配你说的"两个角色 1v1 + 每步操作配说明"**，作为第一版最合适。

### 方案 B：引导式互动（玩家亲手操作 + 逐步校验）

玩家操控一方，系统每步给出"现在请按 M 进入移动模式"之类的提示，
并校验玩家是否完成预期操作后才进入下一步。

- 优点：参与感强、记忆更牢。
- 缺点：实现复杂（要拦截现有 UI、处理玩家做错/卡住、做输入校验与提示回退），
  且要复制一份 main.gd 的战斗交互逻辑，维护成本高。

### 方案 C：混合（先演示，后小段实操）—— 推荐作为第二阶段

前 N 步用方案 A 演示，最后给一段"自由移动 + 攻击"的小练习。
- 优点：兼顾理解与手感。
- 缺点：范围更大。

### 推荐路线

**第一版做方案 A**；剧本动作设计成"可替换"（见第 5 节 action 表），
未来若要上方案 B，只需在动作类型里增加一个 `"type": "wait_for_player"`，
把"执行剧本动作"换成"等待并校验玩家输入"，无需重做。

---

## 4. 整体架构

### 4.1 新增文件

```
godot_game/
├── tutorial/
│   ├── tutorial_controller.gd      # 教程"导演"：状态机 + 步骤控制 + 说明卡片（继承 Control，自包含，可被两个入口复用）
│   └── tutorial_scenario.gd        # 剧本数据（class_name TutorialScenario，纯数据，便于策划/文案编辑）
└── (可选) tutorial/tutorial.tscn   # 若想用场景而非纯代码；现有风格倾向纯代码，可不建
```

> `TutorialController` 自包含（内部持有 `BattleModel` + `BoardView` + 说明卡片 + 控制条），
> 只暴露 `exit_requested` 信号。两个入口都 `add_child(TutorialController.new())` 即可，
> 退出逻辑由入口各自处理，教程代码零重复。

### 4.2 数据流

```
入口① 开始界面「游戏教程」按钮 (main.gd)
入口② 暂停菜单「TUTORIAL」项 (pause_menu.gd，第 6 项，配霜翊剪影)
        │ 二者都实例化同一个组件
        ▼
TutorialController (Control，自包含)
   ├─ BattleModel  (1v1、3×3、固定 seed)
   ├─ BoardView     (渲染棋盘 + 高亮，复用)
   ├─ 主题目录       (章节列表，当前章高亮，点击跳转到对应章节)
   ├─ 说明卡片       (标题 / 正文 / 角色立绘 / 状态条；关键词可点击跳转)
   └─ 控制条         (上一步 / 下一步 / 重播 / 返回 / 目录)
        │
        └─ 章节/步骤数据来自 TutorialScenario.CHAPTERS（Array[Dictionary]）
```

### 4.3 节点关系与两个入口

- 入口①（开始界面）：`main.gd` 把 `TutorialController` 作为**子节点**实例化
  （与 `pause_menu` 用法一致），收到 `exit_requested` 后 `queue_free` 教程节点
  并 `_show_mode_menu()` 回到模式选择。
- 入口②（暂停菜单）：`pause_menu.gd` 新增 `Page.TUTORIAL` 子页面，在 `content_root`
  里实例化同一个 `TutorialController`，收到 `exit_requested` 后 `_show_main_page()`
  回到暂停菜单主页面，**当前战斗保持暂停**。
- 两个入口都**不引入场景切换**，`TutorialController` 代码零重复。
- 退出目标由"来源"决定：入口①退出回模式选择，入口②退出回暂停菜单主页面
  （可在实例化时传一个 `source` 参数，或由入口各自处理 `exit_requested` 信号即可）。

---

## 5. 教程剧本数据格式

### 5.0 章节化结构（支持目录跳转与关键词跳转）

教程从"一条线性剧本"升级为**章节（Chapter）+ 步骤（Step）**两级。每个章节是一个
**自洽的 mini 1v1 演示**，可独立进入，因此玩家对某一规则点有疑惑时能直接跳到对应章节。

```gdscript
const CHAPTERS := [
    {
        "id": "range",                      # 章节唯一标识，供目录/关键词跳转
        "title": "距离与命中",               # 目录与标题显示
        "keywords": ["射程", "距离", "命中"],  # 供文案关键词匹配（可点击）
        "setup": [                          # 进入本章时摆位（重建 model 后执行）
            {"type": "spawn", "unit": "sun_blade", "pos": Vector2i(0, 0)},
            {"type": "spawn", "unit": "molten_core", "pos": Vector2i(2, 2)},
        ],
        "steps": [ { /* 步骤，结构同 5.1 */ }, /* ... */ ],
    },
    /* 其余章节 ... */
]
```

- **顺序播放** = 逐章逐章播放；**跳转** = 载入目标章节（重建 `BattleModel` + 执行 `setup`
  + 从该章第 0 步开始），无副作用、不依赖前后文。
- 步骤结构（5.1）、动作类型表（5.3）、占位符回填（5.4）在章节内**完全不变**。
- 章节分块清单见第 6.0 节（草案，待与你共同确认）。

### 5.1 步骤结构

每个步骤一个 `Dictionary`，统一字段：

```gdscript
{
  "id": "step_01",                       # 唯一标识（便于断言/测试/跳转）
  "title": "棋盘与出生点",                 # 短标题（大字号）
  "body": "6×6 菱形棋盘……",                # 说明正文，支持 BBCode，可用 {占位符}
  "portrait": "night_chain",             # 该步骤解说使用的角色 key（显示立绘/头像，可选）
  "highlight": [                         # 步骤开始时的高亮（可选）
     {"cell": Vector2i(1, 0), "kind": "move"},
     {"cell": Vector2i(5, 0), "kind": "danger"},
  ],
  "action": {                            # 本步执行的剧本动作（可选；缺省=纯解说步）
     "type": "move",
     "unit": "sun_blade",                # 用角色 key 而非 id，可读性更好
     "to": Vector2i(3, 0),
  },
  "after": "曜锋移动到 (3,0)，现在距离敌人 {distance} 格。",  # 执行后补充说明，可带占位符
}
```

### 5.2 解说步 vs 执行步

为让"先讲、后动、再总结"节奏清晰，每个教学点建议拆成两小步：

- **解说步**：无 `action`，展示 `body` + `highlight`，玩家此时看棋盘。
- **执行步**：有 `action`，点击"下一步"后调用 model 执行动作，面板切换为 `after`。

### 5.3 动作类型表（`action.type`）

| type | 参数 | 对应 model 调用 | 说明 |
|------|------|----------------|------|
| `spawn` | `unit`, `pos`, `team` | 直接摆位 | 教程专用：开局摆位（通过 spawn 参数完成，通常不出现在剧本里） |
| `move` | `unit`, `to`, `sprint?` | `move_to()` / `set_sprint_enabled()` + `move_step()` | 移动（可带冲刺） |
| `attack` | `unit`, `target` | `perform_basic_attack()` | 普通攻击 |
| `skill` | `unit`, `skill_id`, `target?`, `cell?` | `perform_skill()` | 释放技能（目标为 enemy/ally/self/cell 时参数不同） |
| `defend` | `unit` | `perform_defend()` | 防御 |
| `wait` | `unit` | `perform_wait()` | 不行动 |
| `force_turn` | `unit`, `start_effects?` | `current_unit_id = …; _start_unit_turn(start_effects)` | 强制切换行动者；`start_effects=false` 只切人不触发回合开始效果（用于控制节奏），`true` 会触发点燃/场地结算与状态重置（用于第 14 步演示点燃） |
| `set_state` | `unit`, `field`, `value` | 直接改单位字段 | 演示特定状态（如设置 `marked=true`、`defending=true`） |
| `highlight_only` | `highlight` | 只调 `BoardView.set_highlights()` | 纯展示，不改状态 |

> 说明：`unit`/`target` 用角色 `key`（如 `"sun_blade"`），控制器内部通过
> `BattleData.characters()` 或单位数组反查 `id`，避免直接写数字 id 难读难改。

### 5.4 占位符回填

`body` / `after` 支持占位符，控制器执行动作后把**真实结果**回填，避免文案与实际数值对不上：

| 占位符 | 含义 |
|--------|------|
| `{distance}` | 与目标的曼哈顿距离 |
| `{damage}` | 实际造成的伤害（可从 model 最新一条 damage 事件取） |
| `{hit}` | 命中率（百分比） |
| `{hp}` / `{ap}` | 某单位当前 HP / AP |
| `{name}` | 单位名称 |

示例：`"曜锋的普攻命中率为 {hit}%，实际造成 {damage} 点伤害。"`
执行后替换为 `"曜锋的普攻命中率为 86%，实际造成 19 点伤害。"`

---

## 6. 教程分块与分步脚本（1v1：曜锋 vs 熔芯）

### 6.0 教程分块（章节）定稿 —— 6 章，每章可采用不同角色

按"每个规则点可独立跳转"的原则，拆为 **6 章**。每章是一个自洽 mini 1v1 演示（章内 2~4 步），
**每章可指定不同的对阵角色**（教程通过选角系统第 12 节的 `teams` 参数把两名角色分到 A/B 两队，
任意组合均可对打，不再受"角色固有队伍"约束）：

| 章节 id | 标题 | 推荐对阵（A vs B） | 选角理由 | 覆盖规则点 | 可点击关键词 |
|---------|------|-------------------|---------|-----------|-------------|
| `intro` | 入门与目标 | 曜锋 vs 熔芯 | 主线代表 | 1v1、胜利条件、控制条/目录用法 | 目标、胜利、控制 |
| `board` | 棋盘与移动 | 曜锋 vs 绯棘 | 曜锋 AP4 适合冲刺；绯棘 HP230 耐打当移动参照 | 3×3 棋盘、同格/穿越、免费 2 格、冲刺 | 棋盘、移动、冲刺 |
| `ctb` | 行动顺序 | 夜链 vs 霜翊 | 速度 14 vs 6，差值最大，先手一目了然 | S=100/速度、同 S 比速度再比 ID | CTB、速度、顺序 |
| `range` | 距离与命中 | 熔芯 vs 曜锋 | 熔芯远程演示衰减；曜锋运气 12 演示闪避 | 曼哈顿距离、R_opt/R_max 衰减、运气闪避、必中 | 射程、距离、命中、闪避 |
| `attack` | 攻击与技能 | 夜链 vs 绯棘 | 夜链必中/连打讲技能；绯棘防御 12 演示减伤 | 普攻、伤害公式、防御减伤、AP、技能首次/再次 | 攻击、伤害、技能、AP、防御 |
| `status` | 状态与暴击 | 曜锋 vs 熔芯 | 曜锋「裂空突刺」演示暴击；熔芯演示点燃/火墙 | 点燃/火墙、暴击 1.5x（束缚/标记一句带过，指向 GUIDE） | 状态、点燃、火墙、暴击 |

> - 对阵按"最能演示该主题"挑选，落地时仍可微调；未在教程登场的角色（如镜澜）在
>   ARCHIVE 图鉴中查看。每章 `setup` 里写入对阵与摆位。
> - 第 6 章"束缚/标记"不单独展开（避免一章塞太多），正文一句带过，并用关键词跳转
>   到 GUIDE/ARCHIVE。
> - 现有 6.1~6.3 的"20 步线性脚本"整体上正是 `range` + `attack` + `status` 三章的合并版，
>   落地时按本章表切分为各章 `steps` 即可。

### 6.1 为什么选这两名角色

| 角色 | key | 队 | 教学价值 |
|------|-----|----|---------|
| 曜锋 | `sun_blade` | A | 高速近战；技能覆盖**暴击强化（裂空突刺）、多段（等离子连斩）、脱甲、残影** |
| 熔芯 | `molten_core` | B | 远程/AOE；技能覆盖**点燃（熔流喷射）、十字 AOE（炉心震荡）、火墙（灼热区）、命中强化** |

二者速度差明显（曜锋 13 vs 熔芯 8），能清楚展示 CTB 顺序；熔芯还能带出
"点燃/火墙"这两个 README 特别强调的特色机制。**剧本数据可轻松换成任意两名角色**。

### 6.2 教程棋盘尺寸（3×3）与初始摆位

为降低操作步数、让玩家一眼看全，**教程默认使用 3×3 小棋盘**（正式对局仍是 6×6）。
小棋盘通过 `start_battle(..., board_size = 3)` 传入，棋盘渲染与边界判定都随之缩小。

- 初始摆位（通过 `spawn` 参数完成，不出现在剧本步骤里）：曜锋 `(0, 0)`、熔芯 `(2, 2)`，
  初始曼哈顿距离 4（恰好超出曜锋覆写后的 R_max=3，用于演示"太远打不到"）。
- **教程用角色需覆写射程**（见 7.7）：曜锋 `r_opt=1 / r_max=3`，熔芯 `r_opt=1 / r_max=3`，
  其余属性（HP/AP/伤害/速度/暴击/运气）保持真实值，命中与伤害公式不变。
  这样三档命中层次清晰：4 格 0% → 2 格约 43% → 1 格约 86%。

### 6.3 分步脚本（示意）

> 编号下「解」= 解说步（无 action），「动」= 执行步（有 action）。
> 命中/伤害数值为示例口径，实际由 model 以固定种子计算并通过占位符回填。

| # | 类型 | 标题 | 说明要点 | 动作 |
|---|------|------|---------|------|
| 01 | 解 | 目标 | 1v1 演示，一方 HP 归零退场即判负；看完后可重播或返回 | — |
| 02 | 解 | 棋盘与出生点 | 3×3 教程小棋盘；A 队出生 (0,0)、B 队出生 (2,2)；同格可叠加、可穿越 | 高亮出生格 |
| 03 | 解 | 行动条 CTB | S = 100 / 速度 p，S 小者先动；同 S 比速度、再比 ID | 高亮当前行动者 |
| 04 | 动 | 曜锋先手 | 曜锋 S≈7.7 小于熔芯 S=12.5，故曜锋先动 | `force_turn` 曜锋 |
| 05 | 解 | 移动 | 每回合免费移动 2 格，移动**不结束**行动，之后仍可攻击/技能/防御 | 高亮 2 格范围 |
| 06 | 动 | 移动演示 | 曜锋从 (0,0) 走到 (1,1)（2 格），距敌 2 格 | `move` 曜锋→(1,1) |
| 07 | 解 | 冲刺 | 消耗 1 AP 额外 +2 格（共 4 格）；确认行动前可撤销 | 展示 AP 变化 |
| 08 | 动 | 冲刺贴近 | 曜锋冲刺到 (2,1)，与敌人相邻 1 格 | `move(sprint)` 曜锋→(2,1) |
| 09 | 解 | 距离与命中 | 曼哈顿距离 d=|Δx|+|Δy|；d≤R_opt 100%，R_opt~R_max 线性下降，≥R_max 必失 | 命中高亮 |
| 10 | 动 | 普通攻击 | 普攻造成 {damage} 伤害，命中率 {hit}%；普攻回复 1 AP | `attack` 曜锋→熔芯 |
| 11 | 解 | 技能 | 首次选择显示详情，再次选择同技能发动；技能消耗 AP | — |
| 12 | 动 | 熔芯反击 | 熔芯回合：远程「熔流喷射」点燃曜锋 | `force_turn` 熔芯 + `skill` burn |
| 13 | 解 | 状态效果 | 点燃在目标行动开始时结算两次；火墙/束缚/标记等见 GUIDE | 高亮曜锋状态 |
| 14 | 动 | 点燃结算 | 曜锋行动开始，先结算点燃掉血 | `force_turn` 曜锋（`true` 触发开始效果） |
| 15 | 解 | 防御/不行动 | 防御使本回合受伤害 -50%；不行动直接结束 | — |
| 16 | 动 | 防御演示 | 曜锋选择防御，准备承受下一击 | `defend` 曜锋 |
| 17 | 解 | 暴击 | 暴击 1.5 倍伤害；「裂空突刺」额外 +20% 暴击 | — |
| 18 | 动 | 暴击演示 | 曜锋「裂空突刺」触发暴击（固定种子保证必出） | `skill` 曜锋 crit_strike |
| 19 | 解 | 胜利条件 | 一方全员 HP 归零退场即结束 | — |
| 20 | 动 | 终局 | 最后一击令熔芯退场，A 队胜利 | `attack` 曜锋→熔芯 |

> 备注：
> - 第 18 步要保证"演示必暴击"，采用**确定性覆盖**而非碰运气：执行该步前用
>   `set_state` 把曜锋 `crit` 临时改为 50（`critical_chance = 50/50 + 0.2 = 1.0`），
>   保证该段必暴击，结算后用 `set_state` 恢复 `crit=18`。这样任何 seed 下都稳定复现，
>   不依赖"恰好随机到暴击"。
> - 第 14 步"点燃结算"用 `force_turn(曜锋, start_effects=true)`，让 `_start_unit_turn(true)`
>   走 `_tick_burns`，恰好演示"点燃在行动开始时结算、防御等状态同步重置"。
> - 完整剧本写成一个 `TutorialScenario.STEPS` 常量数组，策划可直接改文案与顺序。
> - 落地时建议把 20 步精简到约 14 步：合并相邻解说/执行步、砍掉次要演示，
>   教学点收敛为「目标 → 棋盘/出生点 → CTB → 移动+冲刺 → 距离与命中 → 普攻 →
>   技能+点燃状态 → 暴击 → 胜利」；完整 20 步保留为进阶补充。

---

## 7. 关键实现细节

### 7.1 `BattleModel.start_battle` 支持选角队伍、出生点与棋盘尺寸

选角系统（第 12 节）要求队伍由选角结果决定，而非角色固有属性。**最小改动**是给
`start_battle` 增加 `teams`（按队分组）等可选参数，不破坏现有调用：

```gdscript
var board_size := 6   # 新增成员变量；正式对局默认 6，教程传 3

func start_battle(
    selected_mode: String = "local",
    seed: int = 1,
    teams: Dictionary = {},       # {"A": ["sun_blade", ...], "B": ["molten_core", ...]}
    spawns: Dictionary = {},      # { "sun_blade": Vector2i(0,0), ... }
    board_size: int = 6           # 棋盘边长；教程传 3 得到 3×3
) -> void:
    self.board_size = board_size
    var definitions: Array[Dictionary] = []
    if not teams.is_empty():
        # 按 teams 的 A/B 键收集角色，队伍由所在键决定（覆盖角色 data 里的默认 team）
        for team_key in ["A", "B"]:
            for character_key in teams.get(team_key, []):
                for definition in BattleData.characters():
                    if str(definition["key"]) == str(character_key):
                        var copy := definition.duplicate(true)
                        copy["team"] = BattleData.TEAM_A if team_key == "A" else BattleData.TEAM_B
                        definitions.append(copy)
    else:
        definitions = BattleData.characters()   # 回退：按角色固有 team（现有默认/测试兼容）
    # ... 其余初始化不变（遍历 definitions 建 unit）
    for definition in definitions:
        var unit := definition.duplicate(true)
        # ... 现有 hp/ap/状态初始化 ...
        if spawns.has(str(unit["key"])):
            unit["pos"] = spawns[str(unit["key"])]
        else:
            unit["pos"] = Vector2i.ZERO if unit["team"] == BattleData.TEAM_A \
                else Vector2i(board_size - 1, board_size - 1)
        units.append(unit)

func is_inside_board(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < board_size and cell.y >= 0 and cell.y < board_size
```

- 现有 `main.gd` / 测试调用 `start_battle("local", seed)` 仍兼容（`teams` 为空时回退角色固有 `team`）。
- 选角结果直接传入：`start_battle(mode, seed, draft_result)`，其中
  `draft_result = {"A": [3 个 key], "B": [3 个 key]}`。
- 教程 1v1 调用：
  `start_battle("local", 固定种子, {"A": ["sun_blade"], "B": ["molten_core"]}, {"sun_blade": Vector2i(0,0), "molten_core": Vector2i(2,2)}, 3)`。

### 7.2 确定性（固定种子）

- 教程必须用**固定 seed**，保证每次播放的暴击/闪避/伤害完全一致，
  否则说明文案"说一套、做一套"。
- 关键演示点（暴击、闪避）在写剧本时先跑 headless 验证结果，或改用 `guaranteed` 技能。

### 7.3 精简界面 vs 完整战斗 UI

教程**不复用** main.gd 的完整操作按钮/技能面板/日志，只保留：
- 棋盘（`BoardView`）；
- 说明卡片（标题 + 正文 + 可选角色立绘 + 该角色 HP/AP/S 迷你状态）；
- 控制条（上一步 / 下一步 / 重播 / 返回）。

理由：避免信息过载；玩家在教程里只"看"，不需要 7 个操作按钮。

**侧边说明卡片**（本方案定稿形态）放在棋盘右侧，由四部分组成：
1. 当前解说角色立绘缩略图（复用 `portrait_texture`）；
2. 步骤标题（大字号）+ 正文（BBCode，支持占位符回填）；
3. 该角色 HP / AP / S 迷你状态条（状态标签复用 main.gd `_compact_status` 的映射）；
4. 步骤进度（如 `07 / 14`）。

**控制条交互**：`上一步 / 下一步 / 重播 / 返回` 四按钮；键盘映射与游戏内一致
（`←`/`A` = 上一步，`→`/`D` = 下一步，`R` = 重播，`Esc` = 返回）。可选加
「自动播放」按钮（每步约 1.5s 自动前进），第一版可不做。

### 7.4 高亮复用

`BoardView.set_highlights()` 已支持 `"move"` / `"sprint"` / `"skill"` / `"danger"` / `"hit"` 等类型，
教程直接把步骤的 `highlight` 数组转成该字典即可，**命中格还能自动显示百分比**，
第 09 步"距离与命中"直接复用现成能力。

### 7.5 状态展示复用

`main.gd` 的 `_compact_status()`（约 515–535 行）已经把各状态翻译成中文短标签
（防御/蓄力/脱甲/残影/照明/护体/束缚/标记）。教程的迷你状态条可复刻这套映射，
避免重复维护状态名。

### 7.6 返回与重入

- 「返回」→ `exit_requested` 信号 → main 回收教程节点并 `_show_mode_menu()`。
- 「重播」→ 重建 `BattleModel`（同一 seed）并把步骤游标归 0。

### 7.7 小棋盘适配（3×3 教程专用，缺一不可）

缩小棋盘需要三处配套改动：

1. **`BoardView` 尺寸改为读 model**：把 `const BOARD_SIZE := 6` 改为 `var board_size := 6`，
   在 `set_model()` 里同步 `board_size = model.board_size`；`_draw()` / `_cell_at()` 中
   `for y in BOARD_SIZE` 全部改用 `board_size`。渲染位置由 `cell_center()`/`board_origin()`
   派生，小棋盘会自动水平居中；可选将 `board_origin().y` 按 `board_size` 下移做到垂直居中。

2. **教程用角色射程覆写（关键）**：角色 `r_opt/r_max` 与技能射程是为 6×6 设计的，
   3×3（对角距离 4）里必须缩小，否则"命中随距离衰减"演示不出来。在
   `TutorialScenario` 增加常量：

   ```gdscript
   const UNIT_OVERRIDES := {
       "sun_blade": {"r_opt": 1, "r_max": 3},
       "molten_core": {"r_opt": 1, "r_max": 3},
   }
   const SKILL_RANGE_OVERRIDES := {
       "molten_spray": {"min_range": 1, "max_range": 3},   # 点燃，原 2~7
       "furnace_quake": {"min_range": 1, "max_range": 3},  # 十字 AOE，原 2~6
   }
   ```

   控制器在 `start_battle` 后对参战单位应用覆写：**只改射程相关字段**，HP/AP/伤害/速度/暴击/运气
   保持真实值，命中公式、伤害公式不变。这样教程演示的每一步仍是"真实规则，只是战场更小"。

3. **校验脚本**（第 10 节）同样用 `board_size=3` 跑，断言 3×3 下移动/命中/AOE 边界正确
   （如 `is_inside_board(Vector2i(3, 0)) == false`、对角距离 4 命中为 0）。

### 7.8 主题目录与关键词跳转

**主题目录**：教程界面左侧/顶部常驻一个章节列表（由 `TutorialScenario.CHAPTERS` 生成），
当前章高亮；点击任意章节 → 重建 model + 执行该章 `setup` + 从第 0 步开始。控制条加一个
「目录」按钮（键盘 `T`）随时呼出/收起目录。

**关键词跳转**：说明卡片用 `RichTextLabel`（BBCode）渲染，规则点关键词写成可点击链接：

```gdscript
card.bbcode_enabled = true
card.selection_enabled = true          # 关键：meta 点击依赖文本选择系统，必须开启
card.text = "对 [url=topic:range]射程[/url] 有疑惑？点击跳到相关章节。"
card.meta_clicked.connect(_on_card_meta_clicked)

func _on_card_meta_clicked(meta: Variant) -> void:
    if str(meta).begins_with("topic:"):
        _jump_to_chapter(str(meta).trim_prefix("topic:"))

func _jump_to_chapter(chapter_id: String) -> void:
    # 与目录点击共用同一函数：重建 model、执行 setup、重置步骤游标、刷新目录高亮
```

- 章节 `keywords` 字段用于**自动**把正文中出现的对应词包装成 `[url=topic:<章节id>]`，避免手写链接；
  或直接手写 BBCode 链接（更精确）。推荐：正文手写链接为主，`keywords` 作为目录索引/搜索兜底。
- 跳转后「上一步/下一步」仅在该章内移动；章末「下一步」在**顺序播放**时自动进下一章，
  在**跳入模式**时停在章末（可一键返回目录）。

---

## 8. UI 接入（两个入口）

### 8.1 入口①：开始界面（main.gd）

在 `_show_mode_menu()`（约 299–308 行的两个按钮之后）新增一个按钮：

```gdscript
var tutorial := Button.new()
tutorial.text = "游戏教程"
tutorial.custom_minimum_size = Vector2(350, 60)
tutorial.pressed.connect(_open_tutorial)
box.add_child(tutorial)
```

新增回调：

```gdscript
func _open_tutorial() -> void:
    if menu_overlay != null:
        menu_overlay.queue_free()
        menu_overlay = null
    result_overlay.visible = false
    var tutorial_controller := TutorialController.new()
    tutorial_controller.exit_requested.connect(_on_tutorial_exit)
    add_child(tutorial_controller)

func _on_tutorial_exit() -> void:
    _show_mode_menu()
```

### 8.2 入口②：暂停菜单（pause_menu.gd + menu_theme_data.gd）

**第 1 步**：`MenuThemeData.MENU_ITEMS` 加第 6 项，配霜翊剪影（凑齐 6 剪影对应 6 角色）：

```gdscript
const MENU_ITEMS := [
    {"id": "continue", "label": "CONTINUE", "character": "night_chain"},
    {"id": "archive",  "label": "ARCHIVE",  "character": "crimson_thorn"},
    {"id": "guide",    "label": "GUIDE",    "character": "mirror_tide"},
    {"id": "tutorial", "label": "TUTORIAL", "character": "frost_wing"},  # 新增：霜翊，唯一未使用的剪影
    {"id": "settings", "label": "SETTINGS", "character": "sun_blade"},
    {"id": "exit",     "label": "EXIT",     "character": "molten_core"},
]
```

> 现有 `_show_main_page()` 会遍历 `MENU_ITEMS` 生成按钮并调用 `_set_character_theme`，
> 新增这一项后按钮、剪影、主色调、拟声词（霜翊 `FREEZE` / `#376da5`）自动生效，无需改渲染逻辑。

**第 2 步**：`pause_menu.gd` 增加教程子页面：

```gdscript
enum Page { MAIN, ARCHIVE, GUIDE, TUTORIAL, SETTINGS }   # 加 TUTORIAL

func _activate_main_item(item_id: String) -> void:
    match item_id:
        "continue": close_menu()
        "archive": _show_archive_page()
        "guide": _show_guide_page()
        "tutorial": _show_tutorial_page()      # 新增
        "settings": _show_settings_page()
        "exit": _show_confirmation("exit", "确定要退出游戏吗？")

func _show_tutorial_page() -> void:
    current_page = Page.TUTORIAL
    menu_title.text = "TUTORIAL"
    subtitle.text = "游戏教程"
    bottom_hint.text = "上一步 / 下一步 / 重播 / 返回    TAB / ESC  返回菜单"
    _clear_content()
    var tutorial_controller := TutorialController.new()
    tutorial_controller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tutorial_controller.exit_requested.connect(_show_main_page)
    content_root.add_child(tutorial_controller)
```

**键盘协调**：教程作为暂停菜单子页面时，`Tab` / `Esc` 仍由 `pause_menu._input` 捕获并
返回主页面（与 GUIDE/SETTINGS 一致）；教程控制条内部使用 `←`/`→`/`A`/`D`/`R` 及「返回」按钮，
不再占用 `Esc`。入口①（开始界面）里 `Esc` 才负责退出教程回模式选择。

**暂停兼容备注**：教程作为暂停菜单子页面时战斗处于 `paused` 状态；教程是"按钮/键盘手动
推进步骤"，不依赖 `_process`/定时器，故不受暂停影响。若后续加「自动播放」，其定时器节点
需设 `process_mode = Node.PROCESS_MODE_ALWAYS` 才能在暂停下计时。

> 提示：`TutorialController` 需 `class_name TutorialController`，并在
> `project.godot` 或首次扫描后被全局识别（Godot 会自动生成 class 缓存）。

---

## 9. 实现步骤清单

- [ ] 1. `core/battle_model.gd`：`start_battle` 增加 `teams` / `spawns` / `board_size` 可选参数，`is_inside_board` 改用 `board_size`（第 7.1 节）。
- [ ] 2. `core/battle_data.gd`：`team` 字段语义降级为"默认分组"（选角通过 `teams` 覆盖，无需删字段）。
- [ ] 3. 新增选角界面（Draft，第 12 节）：蛇形 1-2-2-1、先手随机、本地双人/玩家对 AI 两种行为；`_show_mode_menu()` 的「本地双人」「玩家对 AI」改为先进选角再进战斗。
- [ ] 4. `ui/board_view.gd`：`BOARD_SIZE` 常量改为成员并从 `model.board_size` 同步，绘制/点击循环改用 `board_size`。
- [ ] 5. 新建 `tutorial/tutorial_scenario.gd`：定义 `CHAPTERS`（第 6.0 节章节化）+ 每章 `setup`/`steps`/`keywords` + `UNIT_OVERRIDES` / `SKILL_RANGE_OVERRIDES`（第 7.7 节射程覆写）。
- [ ] 6. 新建 `tutorial/tutorial_controller.gd`：
  - [ ] 构建棋盘（`BoardView`）、侧边说明卡片、迷你状态条、控制条；
  - [ ] 主题目录（章节列表，当前章高亮，点击跳转）+ 「目录」按钮；
  - [ ] 章节切换 `_jump_to_chapter()`（重建 model + 执行 `setup` + 重置游标）；
  - [ ] 关键词跳转（RichTextLabel `meta_clicked`，正文 `[url=topic:...]`）；
  - [ ] 步骤状态机（当前步 / `body` 展示 / `action` 执行 / `after` 展示 / 上一步 / 重播）；
  - [ ] 应用射程覆写（`UNIT_OVERRIDES` / `SKILL_RANGE_OVERRIDES`）；
  - [ ] 占位符回填逻辑；
  - [ ] `exit_requested` 信号。
- [ ] 7. `main.gd`（教程入口①）：`_show_mode_menu()` 加「游戏教程」按钮 + `_open_tutorial()` / `_on_tutorial_exit()`。
- [ ] 8. `menu_theme_data.gd` + `pause_menu.gd`（教程入口②）：`MENU_ITEMS` 加 `TUTORIAL`（配 `frost_wing` 剪影）、`Page` 加 `TUTORIAL`、`_activate_main_item` 加分支、新增 `_show_tutorial_page()`。
- [ ] 9. 加 headless 校验脚本：`tests/test_tutorial_scenario.gd`（`board_size=3`，见第 10 节）+ `tests/test_draft.gd`（1-2-2-1 顺序、每队 3 人、先手随机、任意两角色可跨队）。
- [ ] 10. 手动跑通：选角 → 进战斗；两个教程入口均能进入；完整播放、上一步/重播/返回；入口①退出回模式选择、入口②退出回暂停菜单且战斗仍暂停；从 AI 对局中点返回不残留状态。

---

## 10. 测试与验收

### 10.1 剧本可回放性测试（headless）

仿照 `tests/test_battle_model.gd`，写 `tests/test_tutorial_scenario.gd`：
固定 seed 下逐条执行 `TutorialScenario.STEPS` 的 action，断言：

- 每步 `action` 调用都返回 `true`（或按预期失败）；
- 结束状态与剧本预期一致（如"最终 B 队 0 存活"）；
- 两次运行产生的事件序列完全一致（确定性）。

```powershell
godot --headless --path E:\game\godot_game --script res://tests/test_tutorial_scenario.gd
```

### 10.2 验收标准

- [ ] 开始界面出现「游戏教程」按钮，点击进入 1v1 教程。
- [ ] 暂停菜单出现「TUTORIAL」项（配霜翊剪影），点击进入同一教程，返回后回到暂停菜单且战斗仍暂停。
- [ ] 每步：先显示说明与棋盘高亮 → 点"下一步"执行动作 → 面板显示 `after`。
- [ ] 可上一步 / 重播 / 返回；入口①返回模式选择、入口②返回暂停菜单。
- [ ] 固定种子下，同一教程两次播放结果一致。
- [ ] 不出现文案数值与画面实际结果不一致的情况。

---

## 11. 已定稿决策

| 决策点 | 结论 |
|--------|------|
| 交互形态 | 方案 A：自动演示（1v1 脚本回放 + 逐步说明），玩家用控制条控制节奏 |
| 教程对阵 | 每章可指定不同对阵（见第 6.0 节），通过 `teams` 把两名角色分到两队，剧本数据可替换 |
| 选角系统 | 新增：蛇形 1-2-2-1 draft、先手随机；角色 `team` 降级为"默认分组"，队伍由选角决定；解除教程跨队约束 |
| 教程棋盘 | 3×3 小棋盘（正式对局仍 6×6）；角色射程按比例覆写以保留"命中衰减"演示 |
| 教程入口 | 两处：① 开始界面「游戏教程」按钮；② 暂停菜单新增「TUTORIAL」项（配霜翊 `frost_wing` 剪影，凑齐 6 剪影对应 6 角色） |
| 教程结构 | 6 章定稿（intro/board/ctb/range/attack/status），章节化 Chapter + Step，每章可指定不同对阵角色；常驻主题目录 + 文案关键词点击跳转 |
| 表现层 | 侧边说明卡片（标题 + 正文 + 立绘缩略图 + HP/AP/S 迷你状态）+ 底部控制条 |
| 控制条 | 上一步 / 下一步 / 重播 / 返回；键盘 `←`/`A`、`→`/`D`、`R`、`Esc` |
| 剧本节奏 | 落地精简为约 14 步，20 步完整版作为进阶补充 |
| 与 GUIDE 互跳 | 教程结束页加「查看完整规则（GUIDE）」入口，GUIDE 页可反向进入教程 |
| 实施节奏 | 先讨论定稿，暂不写代码；确认后再落地 `tutorial/` + `main.gd` + 测试 |

### 仍未定（落地前需拍板）

1. 是否加入「自动播放」按钮（第一版可暂不做）。
2. 教程结束页的 GUIDE 跳转，是复用暂停菜单整页还是只弹规则页（见第 3 节互补定位）。
3. 是否需要在教程开头加一个「跳过教程」快捷键（如直接按 Esc 返回）。

---

## 12. 选角系统（Draft）—— 队伍由选角决定，解除角色固定队伍

### 12.1 需求与规则

- 角色**不再在数据里固定**属于 A 队或 B 队，队伍由开局选角决定。
- 选角顺序为**蛇形 1-2-2-1**（以先手方为 A、后手为 B 示例）：
  - 第 1 轮：A 选 1 名；
  - 第 2 轮：B 选 2 名；
  - 第 3 轮：A 选 2 名；
  - 第 4 轮：B 选 1 名；
  - 合计 A=3、B=3，6 名角色选完。
- **先手随机**：开局随机决定 A 或 B 谁先选；若 B 先手，则顺序镜像为 B:1、A:2、B:2、A:1。
- 效果：任意两名角色都可被分到不同队伍，教程 1v1 因此不再受"同队不能作为敌人"约束。

### 12.2 现状与改动点

| 位置 | 现状 | 改动 |
|------|------|------|
| `battle_data.gd` `characters()` | 每角色硬编码 `"team": TEAM_A/B` | 保留该字段，但**降级为"无选角时的默认分组"**（兼容测试/默认模式）；正式对局由 `teams` 覆盖 |
| `battle_model.gd` `start_battle` | 按角色 `team` 分队、定出生点 | 新增 `teams` 参数（第 7.1 节），队伍与出生点由 `teams` 决定 |
| 开局流程 | 模式选择 → 直接进战斗 | 模式选择 → **选角界面** → 进战斗 |
| 教程 1v1 | 受角色固有队伍限制 | 通过 `teams` 任意指定两队，跨队约束解除 |

> 采用"保留默认 team + `teams` 覆盖"的兼容做法，避免破坏现有 headless 测试与默认模式；
> 角色 `team` 字段语义从"固定阵营"变为"默认兜底"。

### 12.3 选角流程与界面

1. 模式选择后进入「选角界面」（Draft），界面显示 6 名角色与双方当前已选列表。
2. 随机决定先手；顶部提示当前轮到谁选（如「A 队选角 / 剩余 2 名」）。
3. 按 1-2-2-1 顺序轮流点选角色；已选角色置灰。
4. 选满 6 人 → 生成 `draft_result = {"A": [3 keys], "B": [3 keys]}` → 调 `start_battle(mode, seed, draft_result)`。
5. 两种模式的行为：
   - **本地双人**：两名玩家在同一设备上轮流选。
   - **玩家对 AI**：玩家按自己的轮次选 3 名；AI 在 AI 轮次自动选（策略见 12.4 待确认）。
6. 选角界面与现有菜单风格一致（复用 `MenuThemeData` 主题与 `_panel_style` 风格）。

### 12.4 对教程的影响

- 教程 1v1 直接 `start_battle("local", seed, {"A":[...], "B":[...]}, spawns, 3)`，
  任意两名角色分属两队即可对打，第 6.0 节各章对阵不再受角色固有队伍限制。
- 教程**不经过选角界面**，直接由剧本 `setup` 指定对阵，保证按主题快速进入演示。

### 12.5 已定决策（已实现）

1. **AI 选角策略**：随机选择（`DraftModel.ai_pick()`）。
2. **悔选**：不支持（`DraftModel.pick()` 拒绝重复选择）。
3. **选角先手与战斗先手**：选角先手随机（`first_picker`），CTB 战斗先手仍由速度决定，两者相互独立。

---

## 附：与现有 GUIDE 四页规则的对应关系

| 教程步骤 | 对应 GUIDE 页 |
|---------|--------------|
| 02 棋盘与出生点 | 01 基本规则 |
| 05–08 移动/冲刺 | 04 战斗机制 |
| 09 距离与命中 | 02 距离与命中 |
| 03–04 CTB 顺序 | 03 行动条 CTB |
| 11–14 技能/状态 | 04 战斗机制 + ARCHIVE 技能页 |
| 17 暴击 | 04 战斗机制 |
