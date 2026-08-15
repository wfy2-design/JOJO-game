# JOJO CTB Tactics - Godot 4

这是依据仓库中的三份新版设计文档实现的 Godot 4 纵向版本。工程与旧 SFML 原型相互独立。

## 当前实现

- 6x6 菱形棋盘，A 队三人出生于 (0,0)，B 队三人出生于 (5,5)
- 同格显示、同格目标列表、单位可互相穿越
- 免费移动 2 格、冲刺 4 格、行动确认前整体撤销
- 六角色 CTB 队列，按 S、速度、固定 ID 确定顺序
- 普攻、AP、防御、距离命中、运气闪避、防御减伤和暴击
- 六名角色的 24 个技能及主要状态/场地效果
- 时停额外行动、法皇标记、念写先机、束缚、点燃和火墙
- 本地双人与玩家对基础 AI
- 目标命中/伤害预估、技能页、行动预览和战斗日志
- 六名角色的 HP/AP/S 与状态常驻显示
- 技能首次选择显示完整说明，再次选择同一技能后发动
- 暴击时在棋盘中央插入攻击者对应的弱点击破图片
- `Tab` 呼出全屏暂停菜单，主导航采用英文，子页面采用中文
- 六角色图鉴：固定基础属性、六维雷达图、背景故事和完整技能说明
- 四页规则介绍、音量/显示设置、返回标题与退出确认
- 菜单期间完整暂停战斗与 AI，并保留当前移动、目标和技能选择状态
- 得意黑、思源黑体、Bebas Neue、Yuji Syuku 开源字体与许可证
- 固定种子的无头逻辑测试

## 启动

需要 Godot 4.3 或更新的 Godot 4 稳定版。

```powershell
godot --path E:\game\godot_game --editor
```

直接运行项目后选择“本地双人”或“玩家对 AI”。

## 测试

```powershell
godot --headless --path E:\game\godot_game --script res://tests/test_battle_model.gd
godot --headless --path E:\game\godot_game --script res://tests/test_main_ui.gd
godot --headless --path E:\game\godot_game --script res://tests/test_pause_menu.gd
```

## 操作

- `A`：普通攻击
- `E`：打开技能页
- `C`：防御
- `M`：移动模式
- `WASD / 方向键`：逐格移动
- `Shift`：启用或取消冲刺
- `Esc`：取消选择或撤销本回合移动
- `Num1~Num4`：技能选择；首次显示详情，再次选择同一技能后发动
- `Tab`：打开菜单；在子页中返回上一级，在主菜单中返回战斗
- 鼠标：选择格子、技能和同格目标

## 菜单立绘

最终写实比例透明立绘放入 `res://assets/menu/portraits/`，文件名为
`jotaro.png`、`dio.png`、`kakyoin.png`、`polnareff.png`、`avdol.png`
和 `joseph.png`。素材未就绪时，菜单会自动使用现有角色图片作为占位。

六份绘制规格位于工程上级目录 `lihui/`。

## 字体与音频

- 标题：Smiley Sans / 得意黑
- 正文：Source Han Sans CN / 思源黑体
- 英文数字：Bebas Neue
- 日文拟声词：Yuji Syuku
- 许可证保存在 `res://assets/fonts/licenses/`

工程已建立 `BGM`、`SE`、`Voice` 音频总线及设置持久化，但当前没有加入音频素材。

## 实现口径

- “射程 1”按 0~1 格处理；技能自身的最低射程仍生效。
- 技能在有效射程内只受运气闪避影响，必中技能固定为 100%。
- 直接伤害可暴击；点燃、火墙和反弹不可暴击。
- 点燃在目标行动开始时触发两次。
- 火墙按施放者行动计时，每次进入对应格都会触发；施放者退场时火墙消失。
- 火焰照明强化下一次直接攻击指令（包括多段与 AOE），结算后移除。
- 间接伤害仍经过角色防御属性，但不享受防御动作和其他主动减伤。这是当前实现中唯一需要继续实测的数值口径。
- DIO 时停的额外行动提供 4 格免费移动；承太郎的时停额外行动为普通 2 格移动，可自行消耗 AP 冲刺。
