# 暂停菜单剪影转场实现方案

## 1. 目标与结论

可以实现，而且现有暂停菜单已经具备大部分基础：`MenuThemeData.MENU_ITEMS` 已经让六个菜单项分别对应六名角色，`pause_menu.gd::_select_main_item()` 也会在焦点变化时切换角色主题。

目前不连贯的原因是 `_set_character_theme()` 会立即调用 `_set_portrait()` 替换剪影纹理，只有主色和副色在做 0.25 秒 Tween。建议将单张 `silhouette` 改为“旧剪影 + 新剪影”的双层组件，用斜向撕裂遮罩完成切换。视觉语言可以参考 P5R 的高对比、快速切入和不规则边缘，但不要直接复制其人物、图形或商标素材。

本方案分成两层：

1. **选项转场（第一阶段，必须）**：鼠标悬停或键盘移动焦点时，旧剪影被斜向切走，新剪影从相同方向切入，时长 220～280 ms。
2. **页面转场（第二阶段，可选）**：点击 `ARCHIVE / GUIDE / TUTORIAL / SETTINGS` 后，让当前剪影快速放大扫过屏幕，再在遮挡最强时创建子页面。

“点击”仍负责进入页面；仅在菜单项之间移动时应由 `focus_entered` 触发剪影过渡。项目现有的 `mouse_entered -> grab_focus()` 可以继续使用，因此鼠标和键盘会共用同一套逻辑。

## 2. 当前代码接入点

| 位置 | 当前职责 | 需要修改 |
| --- | --- | --- |
| `ui/menu/menu_theme_data.gd` | 菜单项、角色与颜色映射 | 可增加独立剪影路径和构图偏移；没有专用素材时继续复用角色立绘 |
| `ui/menu/pause_menu.gd::_build_overlay()` | 创建暂停菜单固定层 | 创建一个常驻的 `SilhouetteTransition`，位置在背景之上、菜单按钮之下 |
| `ui/menu/pause_menu.gd::_show_main_page()` | 创建主菜单和当前单张剪影 | 删除这里对 `silhouette`、`silhouette_shadow` 的重复创建，改为显示常驻组件 |
| `ui/menu/pause_menu.gd::_select_main_item()` | 响应鼠标/键盘焦点 | 计算移动方向，并请求组件切换到目标角色 |
| `ui/menu/pause_menu.gd::_set_character_theme()` | 换色并直接替换纹理 | 只负责颜色 Tween；不再直接替换剪影纹理 |
| `ui/menu/pause_menu.gd::_clear_content()` | 清理页面内容 | 不清理常驻转场组件，只在离开主菜单时隐藏它 |

建议新增两个文件：

```text
ui/menu/silhouette_transition.gd
ui/menu/silhouette_wipe.gdshader
```

不要将转场节点放进 `content_root`。`_show_archive_page()` 等函数会调用 `_clear_content()`，如果转场节点也是其子节点，点击页面时动画会被立刻释放。它应当是 `overlay` 的直接子节点，并在 `content_root` 之前加入，这样按钮始终处在剪影上层。

## 3. 视觉与时间参数

推荐第一版使用以下固定参数，先得到干净、可控的结果：

| 阶段 | 时间 | 表现 |
| --- | ---: | --- |
| 旧剪影预冲 | 0～40 ms | 沿菜单移动方向偏移 18 px，轻微放大到 1.015 |
| 交叉撕裂 | 40～220 ms | 旧剪影遮罩从 1 到 0，新剪影从 0 到 1；二者保持 35～55 px 错位 |
| 新剪影落位 | 220～270 ms | 新剪影回到原位，拟声词从 0.85 倍弹到 1.0 倍 |

向下选择菜单时，切线从左下向右上推进；向上选择时反向。不要使用普通透明度交叉淡入淡出，否则剪影会在中途叠成一团，失去“切换”的力度。

建议参数：

```gdscript
const SWITCH_DURATION := 0.26
const SLIDE_DISTANCE := 52.0
const EDGE_SOFTNESS := 0.012
const TEAR_AMOUNT := 0.075
```

所有位置按项目的 1600×900 逻辑分辨率布局，Godot 的 `canvas_items` 拉伸会负责窗口缩放。

## 4. 素材规范

第一版可以直接复用 `BattleData.characters()` 中的 `portrait_texture`，与现在的 `_set_portrait()` 一致。为了让六张剪影切换时不跳动，最终最好导出专用 PNG：

- 画布统一为 1200×1200 或 1600×1200，透明背景；
- 人物脚底、视觉重心和头部高度使用同一参考线；
- 人物必须保留完整外轮廓，不要在图片边缘裁掉武器；
- Alpha 边缘避免白色描边；
- 每张图在 1600×900 下实际显示宽度不超过约 840 px；
- 文件建议放在 `assets/characters/silhouettes/<character_key>.png`。

数据结构可逐步扩展为：

```gdscript
const MENU_ITEMS := [
    {
        "id": "continue",
        "label": "CONTINUE",
        "character": "night_chain",
        "silhouette": "res://assets/characters/silhouettes/night_chain.png",
        "offset": Vector2(0, 0),
        "scale": 1.0,
    },
    # 其余菜单项同理
]
```

若暂时没有专用文件，就让组件回退到 `portrait_texture`，不要阻塞程序实现。

## 5. 撕裂遮罩 Shader

新增 `ui/menu/silhouette_wipe.gdshader`。这个 Shader 同时完成白底移除、纯色剪影和斜向撕裂，兼容项目当前的 `gl_compatibility` 渲染器。

```glsl
shader_type canvas_item;

uniform vec4 theme_color : source_color = vec4(0.48, 0.36, 0.88, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float direction = 1.0;
uniform float remove_white = 0.0;
uniform float edge_softness = 0.012;
uniform float tear_amount = 0.075;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float white = smoothstep(0.90, 0.995, min(tex.r, min(tex.g, tex.b)));
    float source_mask = tex.a * (1.0 - white * remove_white);

    // 斜向主切线，加低频分段噪声形成纸张撕裂感。
    float axis = (UV.x + (1.0 - UV.y) * 0.24) / 1.24;
    if (direction < 0.0) {
        axis = 1.0 - axis;
    }
    vec2 tear_cell = floor(UV * vec2(26.0, 15.0));
    float tear = (hash21(tear_cell) - 0.5) * tear_amount;
    float threshold = mix(-0.10, 1.10, progress);
    float wipe_mask = 1.0 - smoothstep(
        threshold - edge_softness,
        threshold + edge_softness,
        axis + tear
    );

    COLOR = vec4(theme_color.rgb, source_mask * wipe_mask * 0.96);
}
```

这里不依赖噪声贴图，便于先落地。若后续发现边缘过于数码化，再用一张可平铺的黑白墨迹纹理替代 `hash21()`；不要在第一版引入额外资产依赖。

## 6. 双层剪影组件

`silhouette_transition.gd` 的职责只有四个：维护旧/新两组剪影、设置材质参数、播放 Tween、处理连续输入。推荐节点结构：

```text
SilhouetteTransition (Control，常驻)
├── OutgoingShadow (TextureRect)
├── OutgoingMain   (TextureRect)
├── IncomingShadow (TextureRect)
└── IncomingMain   (TextureRect)
```

主剪影使用角色 `primary`，错位副剪影使用 `secondary`，并维持当前约 0.30 的 Alpha。四个节点必须各自拥有独立的 `ShaderMaterial`，不能共享同一个材质实例，否则四层的 `progress` 会一起变化。

核心接口建议如下：

```gdscript
class_name SilhouetteTransition
extends Control

const WIPE_SHADER := preload("res://ui/menu/silhouette_wipe.gdshader")
const DURATION := 0.26
const SLIDE_DISTANCE := 52.0

var current_key := ""
var target_key := ""
var _tween: Tween
var _generation := 0

var outgoing_main: TextureRect
var outgoing_shadow: TextureRect
var incoming_main: TextureRect
var incoming_shadow: TextureRect


func set_initial(character_key: String, primary: Color, secondary: Color) -> void:
    _kill_transition()
    current_key = character_key
    target_key = character_key
    _assign_pair(incoming_main, incoming_shadow, character_key, primary, secondary)
    _set_pair_progress(incoming_main, incoming_shadow, 1.0)
    _set_pair_progress(outgoing_main, outgoing_shadow, 0.0)


func transition_to(
    character_key: String,
    primary: Color,
    secondary: Color,
    direction: int
) -> void:
    if character_key == target_key:
        return

    # 快速连续选择时，让上一目标成为新的起点，避免 Tween 排队。
    _commit_interrupted_target()
    _generation += 1
    var run_id := _generation
    target_key = character_key

    _copy_pair(incoming_main, incoming_shadow, outgoing_main, outgoing_shadow)
    _assign_pair(incoming_main, incoming_shadow, character_key, primary, secondary)
    _set_pair_progress(outgoing_main, outgoing_shadow, 1.0)
    _set_pair_progress(incoming_main, incoming_shadow, 0.0)

    var sign_value := 1.0 if direction >= 0 else -1.0
    _set_pair_direction(outgoing_main, outgoing_shadow, sign_value)
    _set_pair_direction(incoming_main, incoming_shadow, sign_value)
    outgoing_main.position.x = 0.0
    outgoing_shadow.position.x = 50.0
    incoming_main.position.x = SLIDE_DISTANCE * sign_value
    incoming_shadow.position.x = 50.0 + SLIDE_DISTANCE * sign_value

    _tween = create_tween()
    _tween.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_method(_set_outgoing_progress, 1.0, 0.0, DURATION * 0.82)
    _tween.tween_method(_set_incoming_progress, 0.0, 1.0, DURATION)
    _tween.tween_property(outgoing_main, "position:x", -SLIDE_DISTANCE * sign_value, DURATION)
    _tween.tween_property(outgoing_shadow, "position:x", 50.0 - SLIDE_DISTANCE * sign_value, DURATION)
    _tween.tween_property(incoming_main, "position:x", 0.0, DURATION)
    _tween.tween_property(incoming_shadow, "position:x", 50.0, DURATION)
    _tween.finished.connect(func() -> void:
        if run_id != _generation:
            return
        current_key = target_key
        _set_pair_progress(outgoing_main, outgoing_shadow, 0.0)
    )
```

辅助函数的具体规则：

- `_assign_pair()`：从角色数据中读取纹理，分别赋给主层和副层；检测 Alpha，设置 `remove_white`；给主层设置 `primary`，副层设置 `secondary`。
- `_copy_pair()`：复制 `texture`、`theme_color`、`remove_white` 和构图参数，不共享材质。
- `_set_pair_progress()`：同时设置一对主/副材质的 `progress`。
- `_commit_interrupted_target()`：若 `_tween` 正在运行，先 `kill()`，把当前 incoming 层设为完全显示并记为 `current_key`，再开始下一次切换。
- `_kill_transition()`：终止 Tween 并递增 `_generation`，使旧回调失效。

`_generation` 很重要。仅仅 `kill()` Tween 不足以防止旧的完成回调在边界帧修改新状态。

## 7. 修改 pause_menu.gd

### 7.1 新增状态

```gdscript
var silhouette_transition: SilhouetteTransition
var selected_menu_index := 0
```

原来的 `silhouette`、`silhouette_shadow` 可以在迁移完成后删除。`onomatopoeia` 仍可由 `PauseMenu` 管理，也可以后续移入组件；第一版不要同时重构两件事。

### 7.2 在固定层创建组件

在 `_build_overlay()` 中，创建 `content_root` 之前加入：

```gdscript
silhouette_transition = SilhouetteTransition.new()
silhouette_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
_place(silhouette_transition, Rect2(650, 55, 840, 790))
overlay.add_child(silhouette_transition)

content_root = Control.new()
content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
overlay.add_child(content_root)
```

组件内部的主层铺满 `Rect2(0, 0, 840, 790)`；副层使用 `Rect2(50, 30, 790, 745)`。这些数值对应当前主、副剪影位置，可在不改变现有构图的情况下替换实现。

### 7.3 主菜单初始化

在 `_show_main_page()` 中移除创建两张 `TextureRect` 的代码，改为：

```gdscript
silhouette_transition.visible = true
selected_menu_index = 0
var first_item: Dictionary = MenuThemeData.MENU_ITEMS[0]
var first_theme := MenuThemeData.theme_for(str(first_item["character"]))
silhouette_transition.set_initial(
    str(first_item["character"]),
    first_theme["primary"],
    first_theme["secondary"]
)
```

`_show_archive_page()`、`_show_guide_page()`、`_show_tutorial_page()` 和 `_show_settings_page()` 开头设置：

```gdscript
silhouette_transition.visible = false
```

返回 `_show_main_page()` 时再恢复。这样子页面不会残留主菜单剪影。

### 7.4 焦点变化时播放转场

将 `_select_main_item()` 调整为：

```gdscript
func _select_main_item(index: int, animate := true) -> void:
    if index < 0 or index >= MenuThemeData.MENU_ITEMS.size():
        return

    var previous_index := selected_menu_index
    selected_menu_index = index
    var item: Dictionary = MenuThemeData.MENU_ITEMS[index]
    var character_key := str(item["character"])
    var selected_theme := MenuThemeData.theme_for(character_key)

    _set_character_theme(character_key, animate)
    if animate:
        silhouette_transition.transition_to(
            character_key,
            selected_theme["primary"],
            selected_theme["secondary"],
            1 if index > previous_index else -1
        )
    _apply_main_button_styles(index)
```

同时从 `_set_character_theme()` 删除以下直接替换纹理的逻辑：

```gdscript
_set_portrait(silhouette, character_key, true)
_set_portrait(silhouette_shadow, character_key, true)
```

主题颜色 Tween 与剪影 Tween 可以并行，但两者时长都设为约 0.26 秒，避免背景已经换色而人物还没落位。

### 7.5 鼠标防抖

现在每个按钮在 `mouse_entered` 时立即 `grab_focus()`。当鼠标快速横穿六项时，会连续触发五次切换。组件必须能打断 Tween；此外建议只对鼠标增加 35～50 ms 防抖，键盘焦点仍立即响应。

实现方式是在按钮 `mouse_entered` 时记录递增 token，再用短 `SceneTreeTimer` 验证鼠标仍在按钮上后才 `grab_focus()`。不要冻结输入，也不要让转场阻止按钮点击。

## 8. 点击进入子页面的整屏转场（第二阶段）

第一阶段稳定后，可给组件增加：

```gdscript
signal cover_reached
func play_page_cover(direction: int) -> void
```

点击子页面时不要立即执行 `_show_archive_page()`，而是：

1. 禁止再次激活按钮，但保留 `Esc`；
2. 当前剪影在 120 ms 内放大到 1.18，并让副色层横向错位约 90 px；
3. 同时用同一撕裂 Shader 驱动一个全屏 `ColorRect/TextureRect`，在遮罩覆盖率约 65% 时发出 `cover_reached`；
4. 收到信号后调用目标 `_show_*_page()`；
5. 目标页面在遮罩后创建完成，再用 140 ms 将遮罩切走；
6. 恢复输入。

页面切换必须用一个统一入口，避免每个按钮各写一份异步代码：

```gdscript
func _request_page(page_callable: Callable) -> void:
    if page_transition_active:
        return
    page_transition_active = true
    silhouette_transition.play_page_cover(1)
    await silhouette_transition.cover_reached
    page_callable.call()
    await silhouette_transition.play_cover_release()
    page_transition_active = false
```

`CONTINUE`、`EXIT` 和确认弹窗不建议在第一版接入整屏转场：`CONTINUE` 涉及解除暂停，`EXIT` 涉及确认层，它们的生命周期不同。先覆盖四个普通子页面，确认稳定后再单独处理。

## 9. 声音与可访问性

- 焦点切换只播放很短的纸张/切割音，不要每次播放完整冲击音；连续切换时限制为每 60 ms 最多一次。
- 点击进入页面播放更重的一次确认音，和焦点音分开。
- 设置中增加“减少菜单动态效果”后，选项转场时长可改为 0，直接调用 `set_initial()`；页面转场改成 100 ms 纯遮挡切换。
- 不要用大幅屏幕闪白。剪影主色和副色已经足够表达冲击感。

## 10. 测试与验收

扩展 `tests/test_pause_menu.gd`：

1. 打开菜单后，初始剪影为 `night_chain`。
2. 聚焦 `ARCHIVE` 后，`target_key == "crimson_thorn"`；等待 0.3 秒后 `current_key` 同步。
3. 在 0.1 秒内连续聚焦 2、4、6 项，最终只允许 `molten_core` 完成，不残留有效 Tween。
4. 转场过程中点击当前按钮，实际进入的页面必须与当前焦点一致。
5. 进入任意子页面后，常驻剪影不可见；返回主菜单后恢复。
6. `Tab / Esc` 返回时不遗留输入锁、Tween 或全屏遮罩。
7. 1280×720、1600×900、1920×1080 三档分辨率下，剪影不越界、不遮挡左侧按钮。

扩展 `tests/capture_pause_menu.gd`，至少抓取：

```text
menu_transition_start.png     # 进度 0.0
menu_transition_middle.png    # 进度约 0.5，应同时看到两张被切开的剪影
menu_transition_end.png       # 进度 1.0，只剩目标剪影
```

验收标准：

- 单次切换在 300 ms 内完成；
- 快速移动焦点不会排队播放旧动画；
- 中间帧没有整张矩形图片边界、白底或双重实心人物；
- 动画结束后旧层 Alpha/遮罩为 0；
- 页面关闭与返回战斗的暂停状态不受影响；
- 低端机器上暂停菜单保持 60 FPS；若 Shader 造成压力，优先降低撕裂分段数量，不降低人物纹理清晰度。

## 11. 推荐实施顺序

1. 新增 Shader 和双层组件，仅用两名角色做切换验证。
2. 接入 `_select_main_item()`，覆盖六个菜单项并完成连续输入打断。
3. 统一六张素材的画布和锚点，修正人物跳动。
4. 加入拟声词缩放和短音效。
5. 补齐自动测试与三档截图。
6. 最后再实现点击进入子页面的全屏遮挡转场。

按这个顺序，第一至第三步就能完成用户可见的“每个菜单项拥有自己的剪影，并在选项间进行 P5R 风格转场”；后续页面遮挡属于增强，不应成为第一版上线的前置条件。
