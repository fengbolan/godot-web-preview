# 《Hoomans Are Gone》完整游戏设计文档

版本：当前 Godot 复现版  
目标读者：接手复刻的游戏开发者、技术美术、数值策划  
项目类型：2D 俯视角动作肉鸽 / 生存割草 / 单局构筑

## 1. 设计目标

本游戏复刻一个“废墟竞技场中的刀盾狗主角，在异变怪群中坚持 12 分钟”的 2D 动作肉鸽原型。玩家通过移动、冲刺、手动刀弧、毒瓶、磁吸和自动电链持续清怪，升级时在三张“质变卡”中选择构筑方向，局外通过废料购买永久成长。

复刻目标不是做一个占位 Demo，而是交付一个可玩的完整小型动作肉鸽：

- 单局目标明确：坚持 12 分钟，击败终局首领。
- 战斗输入简单：移动、冲刺、左键刀弧、Q 毒瓶、R 磁吸。
- 构筑有分化：电、刀、毒、生存四条方向。
- 数值可持续扩张：刷怪强度、敌人血量、敌人伤害、Boss 压力随时间上升。
- 局外有保留价值：废料用于永久升级。
- 画面必须读得清：废墟地图、主角朝向动画、敌人血条、拾取物、范围提示、Boss 预警、小地图、技能冷却。

## 2. 游戏概览

| 项目 | 规格 |
| --- | --- |
| 游戏名 | Hoomans Are Gone / 人类没了 |
| 类型 | 2D 俯视角动作肉鸽 |
| 引擎 | Godot 4.6.2 |
| 目标分辨率 | 1280 x 720 |
| 单局时长 | 720 秒，12 分钟 |
| 主角 | 刀盾狗，金毛犬战士，皮甲、红围巾、圆盾、短刀 |
| 地图 | 废墟竞技场，暗色石路、蓝色晶体、火光、破损建筑 |
| 胜利条件 | 12 分钟 Boss 压力点后击败终局晶化首领 |
| 失败条件 | 主角生命降至 0 |
| 局外资源 | 废料 |
| 核心构筑 | 电链、刀弧、毒池、生存补给 |

## 3. 核心体验支柱

1. 清晰的生存压力  
   玩家被限制在椭圆竞技场内，敌人从边界不断进入。早期让玩家熟悉移动和拾取，中期加入喷吐和精英词缀，后期通过 Boss、重兽和更高刷怪密度制造压力。

2. 自动与手动混合战斗  
   电链和刀弧会自动循环释放，玩家也可以手动左键挥刀、Q 投掷毒瓶、Space 冲刺。这样既有割草游戏的自动成长，也保留动作游戏的操作反馈。

3. 构筑可读  
   升级卡分为电、刀、毒、生存四类，并用不同颜色、图标、稀有度边框和效果摘要展示。玩家应该能看懂“这张卡在加强哪条路线”。

4. 长局递进  
   敌人数量上限、刷怪包大小、敌人血量、敌人速度、敌人伤害都会随时间提升。3、6、9、12 分钟触发 Boss 压力点。

5. 局外积累  
   结算废料用于局外背包，永久提升生命、伤害、拾取范围和移动速度，让玩家愿意重复游玩。

## 4. 画面设计

### 4.1 整体视觉

画面为固定 2D 俯视角 / 轻等距视角。背景是一张高精度废墟竞技场图，整体暗蓝灰色，辅以青蓝晶体和暖色火光。角色、敌人和 UI 均叠加在这张地图之上。

视觉关键词：

- 后末日废墟
- 暗色石路
- 蓝色晶体光
- 火盆暖光
- 圆形/椭圆竞技场边界
- 金毛犬战士主角
- 紫色异变敌人
- 蓝青色电链特效
- 绿色毒池
- 金色刀弧

### 4.2 画面布局

| 区域 | 内容 |
| --- | --- |
| 左上 | 玩家信息面板：名字、等级、生命条、经验条、击杀、废料 |
| 顶部偏左 | 连杀提示和构筑计数条 |
| 右上 | 时间、目标时间、补给倒计时、小地图 |
| 中央 | 战斗场地、主角、敌人、拾取物、特效 |
| 右下 | 技能状态栏：Space 冲刺、Q 毒瓶、R 磁吸、AUTO 电链 |
| 居中弹窗 | 升级三选一、结算面板 |
| 菜单右侧 | 局外背包 |

### 4.3 地图规格

| 项目 | 数值 |
| --- | --- |
| 世界绘制尺寸 | 1280 x 720 |
| 地图原图 | `assets/map/arena_base.png` |
| 地图原图尺寸 | 1672 x 941 |
| 绘制方式 | 拉伸绘制到 `WORLD_SIZE + Vector2(16, 10)`，偏移 `(-8, -5)` |
| 竞技场中心 | `(640, 366)` |
| 可走边界 | 椭圆 |
| 可走半轴 | X = 560，Y = 326 |
| 边界线颜色 | 青灰，透明度约 0.22 |
| 进度线 | 在边界外侧画一圈青色计时弧 |

可走区域不是圆形，而是符合地图透视的椭圆。所有角色、敌人、毒池、补给、Boss 预警点都应使用同一套椭圆边界逻辑。

边界限制公式：

```text
offset = position - ARENA_CENTER
radii = ARENA_RADII - margin
normalized = Vector2(offset.x / radii.x, offset.y / radii.y)

if length(normalized) > 1:
    clamped = normalize(normalized)
    position = ARENA_CENTER + Vector2(clamped.x * radii.x, clamped.y * radii.y)
```

### 4.4 主角表现

主角为金毛犬战士，装备圆盾和短刀。必须有四朝向动画，不允许只做简单镜像或静态贴图。

当前动画规格：

| 动作 | 文件 | 朝向 | 帧数 |
| --- | --- | --- | --- |
| 站立 / 防御 | `player_dog_idle_sheet.png` | 下、右、上、左 | 每方向 4 帧 |
| 移动 | `player_dog_move_sheet.png` | 下、右、上、左 | 每方向 8 帧 |
| 攻击 | `player_dog_attack_sheet.png` | 下、右、上、左 | 每方向 8 帧 |
| 冲刺 | `player_dog_dash_sheet.png` | 下、右、上、左 | 每方向 6 帧 |
| 受击 | `player_dog_hurt_sheet.png` | 下、右、上、左 | 每方向 4 帧 |

所有主角动作使用 `assets/sprites/player_dog_anim_meta.json` 记录每帧裁切框、脚底锚点和绘制缩放。渲染时应以脚底点对齐到 `player.pos + Vector2(0, 26)`，避免角色漂浮。

### 4.5 敌人表现

敌人为紫色异变生物，分为啃噬者、腐液喷吐者、甲壳重兽、晶化首领。敌人可使用单张精细 sprite，不要求完整动作表，但要有：

- 受击白闪。
- 非满血时显示血条。
- Boss 显示更宽血条。
- 精英词缀显示外圈颜色。
- 中毒、流血、感电显示状态弧或图标。

### 4.6 特效规范

| 特效 | 表现 |
| --- | --- |
| 电链 | 青色折线，链接多个敌人 |
| 分叉电流 | 较浅青色短链 |
| 刀弧 | 金色弧线，围绕主角朝向绘制 |
| 冲刺 | 青色短线拖尾和冲刺起手环 |
| 毒池 | 半透明绿色圆域，外圈描边 |
| 过载 | 青色扩散环 |
| Boss 预警 | 未触发时青色圆域，触发时红色十字和红圈 |
| 补给 | 木箱矩形，金色描边，绿色/青色提示环 |
| 拾取物 | 菱形晶体，经验为青色，废料为金色，治疗为绿色 |

## 5. 输入设计

| 输入 | 行为 |
| --- | --- |
| WASD / 方向键 | 移动 |
| Space | 冲刺 |
| 鼠标左键 | 手动刀弧 |
| Q | 投掷毒瓶 |
| R | 磁吸拾取物 |
| Esc | 战斗中撤回营地；局外/结算页返回标题 |

鼠标方向决定手动刀弧方向。若鼠标距离主角太近，使用最近一次冲刺方向或默认向右。

## 6. 状态机

| 状态 | 说明 |
| --- | --- |
| `menu` | 标题菜单，进入废墟、局外背包、重置存档 |
| `play` | 主战斗状态 |
| `level_up` | 升级三选一，游戏暂停在选择页 |
| `meta` | 局外背包 |
| `game_over` | 结算页 |

状态转换：

```text
menu -> play: 点击进入废墟
menu -> meta: 点击局外背包
play -> level_up: 经验达到升级阈值
level_up -> play: 选择质变 / 跳过
play -> game_over: HP <= 0 / Esc 撤回 / 终局 Boss 死亡
game_over -> play: 再来一局
game_over -> meta: 局外背包
meta -> menu: 回到标题
```

## 7. 单局流程

### 7.1 开局初始化

开局时：

- 清空敌人、拾取物、投射物、毒池、危险区、补给箱、特效、伤害数字、通知。
- 时间归零。
- 初始刷 8 只啃噬者。
- 玩家位置为 `ARENA_CENTER + Vector2(0, 84)`。
- 初始等级 1。
- 初始经验 0。
- 初始升级需求 16。
- 首个补给时间为 42 秒。
- Boss 压力点为 180、360、540、720 秒。

### 7.2 胜负条件

| 结果 | 条件 |
| --- | --- |
| 失败 | 主角 HP <= 0 |
| 撤退 | 战斗中按 Esc |
| 胜利 | 终局晶化首领死亡 |

12 分钟时会刷终局首领，但胜利判定发生在终局首领死亡时。

### 7.3 战斗循环顺序

每帧更新顺序：

1. 若处于 hitstop，只更新特效并跳过其他逻辑。
2. 增加运行时间。
3. 递减玩家冷却和状态计时。
4. 更新玩家移动、冲刺、手动技能。
5. 更新刷怪、补给、Boss。
6. 更新危险区。
7. 更新补给箱。
8. 更新敌人 AI。
9. 更新投射物。
10. 更新毒池。
11. 更新拾取物吸附。
12. 更新自动武器。
13. 更新特效与伤害数字。
14. 清理死亡敌人，发放奖励。
15. 检查玩家死亡。

## 8. 玩家数值

### 8.1 基础数值

| 属性 | 初始值 | 说明 |
| --- | --- | --- |
| 最大生命 | 95 | 受局外“犬舍训练”影响 |
| 移动速度 | 154 | 受局外“旧世战靴”影响 |
| 全伤害倍率 | 1.0 | 受局外“线圈研究”影响 |
| 护甲 | 0 | 每次受击直接减伤 |
| 拾取范围 | 58 | 受局外“野外背包”影响 |
| 经验倍率 | 1.0 | 影响经验拾取 |
| 碰撞半径 | 20 | 角色受击/拾取判定 |

局外加成公式：

```text
max_hp = 95 + kennel_training_level * 10
move_speed = 154 + old_world_boots_level * 4
damage_mult = 1.0 + coil_research_level * 0.05
pickup_radius = 58 + field_pockets_level * 12
```

### 8.2 移动与冲刺

| 项目 | 数值 |
| --- | --- |
| 普通移速 | `stats.move_speed` |
| 击杀狂热加速 | +34，持续取决于升级 |
| 残血加速阈值 | 当前生命 / 最大生命 < 35% |
| 冲刺速度 | 620 |
| 冲刺持续 | 0.18 秒 |
| 冲刺动画 | 0.30 秒 |
| 冲刺无敌 | 0.32 秒 |
| 初始冲刺冷却 | 2.5 秒 |
| 最低冲刺冷却 | 0.55 秒，代码强制下限 |

冲刺结束时，如果拥有 `dash_slash`，释放一次半径 102 的圆形斩击。

### 8.3 受击

受击公式：

```text
damage_taken = max(1, incoming_damage - armor)
player.hp -= damage_taken
player.invuln = 0.48
hurt_animation = 0.32
combo = 0
hitstop = 0.045
shake = max(shake, 0.34)
```

如果拥有护盾爆裂且冷却结束：

```text
shield_burst_cd = 7.5
invuln = 0.75
对 150 范围内敌人造成：
46 + electric_damage + shield_burst_damage
```

## 9. 武器与技能

### 9.1 电链

基础数值：

| 属性 | 值 |
| --- | --- |
| 伤害 | 21 |
| 冷却 | 0.78 秒 |
| 弹跳次数 | 3 |
| 链距 | 155 |
| 第一个目标额外搜索范围 | +80 |
| 分叉概率 | 0 |

释放逻辑：

1. 从玩家位置或雷核位置作为起点。
2. 搜索范围内最近且未访问敌人。
3. 对目标造成电伤并生成电链特效。
4. 按 `fork_chance` 判定是否额外分叉到新目标。
5. 当前起点移动到刚命中的目标。
6. 重复 `chain_count` 次。

分叉命中：

```text
fork_damage = electric_damage * 0.58 * damage_scale
fork_range = chain_range * 0.85
```

雷核：

- 每个雷核围绕玩家半径 66 旋转。
- 雷核每 0.58 秒释放一次电链。
- 雷核电链伤害倍率为 0.62。

### 9.2 刀弧

基础数值：

| 属性 | 值 |
| --- | --- |
| 伤害 | 25 |
| 冷却 | 0.96 秒 |
| 命中距离 | 92 |
| 半角 | 0.72 弧度 |
| 击退 | 42 |
| 暴击基础概率 | 5% |

刀弧有两种来源：

- 自动循环：冷却到 0 后自动释放。
- 手动输入：左键且冷却到 0 时释放。

命中判定：

```text
distance_to_enemy <= 92 + enemy.radius
abs(angle_between(aim, enemy_direction)) <= slash_arc
```

暴击：

```text
crit_chance = 0.05 + min(0.16, combo * 0.002)
crit_multiplier = 1.85
```

如果刀弧造成击杀，并拥有狂热升级，则刷新狂热移速时间。

### 9.3 冲刺刀光

触发条件：拥有 `dash_slash` 且冲刺结束。

```text
radius = 102
damage = slash_damage * (0.82 + dash_slash_damage)
push = 70
animation_duration = 0.38
```

### 9.4 毒瓶与毒池

基础数值：

| 属性 | 值 |
| --- | --- |
| 毒伤 | 9 |
| 冷却 | 5.2 秒 |
| 持续 | 4.0 秒 |
| 半径 | 54 |
| 手动输入 | Q |
| 自动投掷条件 | 毒冷却低于 4.4 秒 |

毒池 tick：

```text
tick_interval = 0.28
damage_per_tick = poison_damage * 0.28
```

中毒状态：

```text
poison_time = max(current, 3.6 + poison_duration * 0.18)
poison_dps = max(current, poison_damage * 1.25)
slow = max(current, poison_slow)
```

喷吐者投射物命中玩家时，也会在命中点生成 0.55 倍规模毒池。

### 9.5 磁吸

| 属性 | 值 |
| --- | --- |
| 输入 | R |
| 冷却 | 7.5 秒 |
| 额外拾取半径 | +220 |
| 影响对象 | 场上所有拾取物 |

拾取物吸附速度：

```text
pull_speed = 190 + (radius - distance) * 3
```

实际拾取距离为 24。

## 10. 伤害系统

### 10.1 通用伤害公式

```text
dmg = base_amount * damage_mult

if player_hp_ratio < 0.35:
    dmg *= 1 + low_hp_damage

if combo > 0 and combo_damage > 0:
    dmg *= 1 + min(0.45, combo * combo_damage)

if target_poisoned and kind != poison_dot:
    dmg *= 1 + poison_vulnerability

if slash_execute_condition:
    dmg *= 1.75
    force_crit = true

if electric_execute_condition:
    dmg *= 1.55
    force_crit = true

if crit:
    dmg *= 1.85
```

### 10.2 处决

刀系处决：

```text
if kind == slash and execute_threshold > 0:
    threshold = execute_threshold + min(0.08, combo * 0.001)
    if enemy_hp_ratio <= threshold:
        dmg *= 1.75
        force_crit = true
```

电系处决：

```text
if kind == electric and shock_execute > 0 and shock_stacks > 0:
    if enemy_hp_ratio <= shock_execute:
        dmg *= 1.55
        force_crit = true
```

### 10.3 状态

| 状态 | 来源 | 效果 |
| --- | --- | --- |
| 感电 | 电伤 | 3.2 秒，最多 8 层 |
| 过载 | 感电达到 4 层且拥有过载 | 清空层数，对 82 范围敌人造成电磁伤害 |
| 中毒 | 毒池 | 持续毒伤、可附带减速和易伤 |
| 流血 | 刀弧且拥有流血升级 | 2.6 秒持续伤害，DPS 可叠加，上限 70 |
| 精英再生 | 精英词缀 | 每 0.8 秒回复 1.8% 最大生命 |

状态伤害 tick 间隔为 0.35 秒。

## 11. 敌人设计

### 11.1 敌人基础表

| ID | 名称 | HP | 速度 | 伤害 | XP | 半径 | 质量 | 分数 | 角色定位 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| crawler | 啃噬者 | 34 | 76 | 8 | 4 | 19 | 1.0 | 8 | 基础近战怪 |
| spitter | 腐液喷吐者 | 52 | 55 | 9 | 6 | 21 | 1.1 | 13 | 远程喷吐怪 |
| brute | 甲壳重兽 | 138 | 43 | 18 | 14 | 31 | 2.4 | 32 | 高血量压迫怪 |
| alpha | 晶化首领 | 860 | 35 | 24 | 90 | 55 | 5.5 | 220 | Boss |

### 11.2 时间缩放

普通敌人生成时：

```text
hp = base_hp * (1 + run_time / 520)
max_hp = hp
speed = base_speed * (1 + run_time / 1100)
damage = base_damage * (1 + run_time / 720)
```

### 11.3 敌人 AI

通用：

- 每帧朝玩家方向移动。
- 敌人被限制在竞技场边界内，但允许额外边界缓冲 `extra = 44`，避免刚刷出就被夹死。
- 与玩家距离小于 `enemy.radius + player.radius + 4` 时，造成接触伤害。

喷吐者：

- 距离玩家小于 330 时，进入喷吐逻辑。
- 移动速度降为有效速度的 28%。
- 射击冷却 1.7 到 2.7 秒。
- 投射物速度 245，生命周期 4 秒。
- 投射物命中玩家后造成伤害，并生成 0.55 倍毒池。

### 11.4 精英词缀

85 秒后普通敌人有概率成为精英：

```text
elite_chance = clamp((run_time - 85) / 760, 0, 0.24)
```

| 词缀 | 效果 |
| --- | --- |
| swift | 速度 x1.45，HP x0.88 |
| armored | HP x1.68，速度 x0.84，质量 x1.45 |
| volatile | 伤害 x1.28，速度 x1.1，死亡爆炸 |
| regenerating | HP x1.25，每 0.8 秒回复 1.8% 最大生命 |

volatile 死亡爆炸：

```text
radius = 92
damage_to_player = enemy.damage * 1.2
damage_to_enemies = damage_to_player * 0.45
enemy_push = 58
```

## 12. 刷怪与强度曲线

### 12.1 普通刷怪

刷怪间隔：

```text
interval = max(0.24, 1.08 - run_time / 620)
```

存活上限：

```text
max_alive = 46 + min(92, run_time / 4)
```

每波刷怪数量：

```text
pack = 1 + int(run_time / 110)
```

怪物类型权重：

```text
if run_time > 130 and roll > 0.86:
    brute
elif run_time > 55 and roll > 0.68:
    spitter
else:
    crawler
```

说明：

- 0 到 55 秒：只出啃噬者。
- 55 秒后：约 32% 概率出腐液喷吐者。
- 130 秒后：约 14% 概率出甲壳重兽；腐液喷吐者保持中段概率；其余出啃噬者。

### 12.2 Boss 压力点

| 时间 | 事件 |
| --- | --- |
| 180 秒 | 第一只晶化首领 |
| 360 秒 | 第二只晶化首领 |
| 540 秒 | 第三只晶化首领 |
| 720 秒 | 终局晶化首领 |

Boss HP 倍率：

```text
hp_mult = 1 + boss_index * 0.58
if final:
    hp_mult += 1.45
```

Boss 速度与伤害：

```text
speed = base_speed * (1 + boss_index * 0.08)
damage = base_damage * (1 + boss_index * 0.18)
```

终局 Boss 额外半径 +16。

### 12.3 Boss 技能

Boss 每次施法随机选择 3 种模式之一。普通 Boss 冷却为 4.4 到 6.4 秒；终局 Boss 冷却为 3.2 到 4.8 秒。

| 模式 | 普通 Boss | 终局 Boss |
| --- | --- | --- |
| 晶刺新星 | 半径 132，预警 0.88 秒，伤害 x1.08 | 半径 172，预警 0.88 秒，伤害 x1.08 |
| 晶体点名 | 4 个玩家附近危险区，半径 42，预警 0.62 到 1.02 秒，伤害 x0.82 | 7 个危险区 |
| 召唤异变群 | 召唤 3 个 crawler/spitter | 召唤 5 个 crawler/spitter |

召唤中每个敌人 78% 为 crawler，22% 为 spitter。

## 13. 成长系统

### 13.1 经验与升级

经验来自击杀敌人掉落的 XP 晶体和补给箱。拾取 XP 后：

```text
player.xp += pickup.amount * xp_gain
```

升级公式：

```text
if xp >= xp_next:
    xp -= xp_next
    level += 1
    xp_next = floor(xp_next * 1.18 + 8)
    enter level_up state
```

初始升级需求为 16。

前 10 级经验需求参考：

| 等级 | 升到下一级所需 XP |
| --- | ---: |
| 1 -> 2 | 16 |
| 2 -> 3 | 26 |
| 3 -> 4 | 38 |
| 4 -> 5 | 52 |
| 5 -> 6 | 69 |
| 6 -> 7 | 89 |
| 7 -> 8 | 113 |
| 8 -> 9 | 141 |
| 9 -> 10 | 174 |
| 10 -> 11 | 213 |

### 13.2 升级选择

升级时进入 `level_up` 状态，显示 3 张随机质变卡。选择后回到战斗。

规则：

- 只从未达到 `max_stacks` 的升级中抽取。
- 当前实现为随机洗牌后取前 3 张，没有按稀有度加权。
- 可花费 3 本局废料重抽。
- 可跳过：恢复 18 生命并获得 2 本局废料。

### 13.3 四大构筑

| 构筑 | 颜色 | 玩法 |
| --- | --- | --- |
| 电 | 青色 | 电链、分叉、雷核、感电、过载、静电处决 |
| 刀 | 金色 | 刀弧、击退、冲刺刀光、流血、低血处决、连杀伤害 |
| 毒 | 绿色 | 毒池、冷却缩短、毒伤、减速、易伤、死亡毒雾、疫病传播 |
| 生存 | 浅蓝 | 生命、护甲、拾取、补给、护盾爆裂、残血反扑 |

### 13.4 局内质变表

| ID | 名称 | 构筑 | 稀有度 | 上限 | 效果 |
| --- | --- | --- | --- | ---: | --- |
| chain_swarm | 雷网形态 | 电 | 稀有 | 4 | 弹跳 +1，链距 +28，电伤 +4 |
| forked_current | 分叉电流 | 电 | 精良 | 4 | 分叉 +16%，电伤 +3 |
| capacitor_fang | 蓄电獠牙 | 电 | 普通 | 8 | 电伤 +8，电冷却 -0.05 |
| storm_orbit | 雷核伴飞 | 电 | 史诗 | 3 | 雷核 +1，电伤 +6 |
| overload_mark | 过载标记 | 电 | 稀有 | 3 | 过载开启，感电伤害 +7，链距 +12 |
| static_execution | 静电处决 | 电 | 史诗 | 2 | 电处决线 +8%，电伤 +8 |
| frenzy_cut | 兽性连击 | 刀 | 精良 | 5 | 刀伤 +10，刀冷却 -0.08，击杀后狂热 0.6 秒 |
| wide_arc | 裂颅横扫 | 刀 | 普通 | 6 | 刀伤 +8，刀弧 +0.14，击退 +18 |
| dash_blade | 冲刺刀光 | 刀 | 稀有 | 3 | 冲刺刀光开启，刀光倍率 +0.18，冲刺冷却 -0.22 |
| razor_bleed | 锯齿刀口 | 刀 | 精良 | 5 | 流血 +5，刀伤 +4 |
| execution_instinct | 处决本能 | 刀 | 史诗 | 3 | 处决线 +9%，连杀伤害 +0.3%/层 |
| venom_spores | 剧毒孢子 | 毒 | 精良 | 5 | 毒伤 +7，毒时长 +0.8 |
| acid_bloom | 酸蚀绽放 | 毒 | 稀有 | 3 | 毒范围 +18，死亡毒雾开启 |
| toxic_vial | 腐液瓶 | 毒 | 普通 | 7 | 毒冷却 -0.45，毒伤 +3 |
| neurotoxin | 神经毒素 | 毒 | 稀有 | 3 | 中毒减速 +12%，中毒易伤 +8% |
| plague_chain | 疫病传播 | 毒 | 史诗 | 2 | 疫病传播开启，毒伤 +5 |
| scrap_armor | 废铁护甲 | 生存 | 普通 | 6 | 最大生命 +12，护甲 +1 |
| magnet_heart | 磁心项圈 | 生存 | 普通 | 5 | 拾取 +18，经验 +8% |
| shield_burst | 护盾爆裂 | 生存 | 稀有 | 3 | 护盾爆裂开启，爆裂 +18，最大生命 +8 |
| adrenal_path | 肾上腺路线 | 生存 | 史诗 | 3 | 移速 +18，冲刺冷却 -0.38，拾取 +12 |
| field_scavenger | 战地拾荒 | 生存 | 精良 | 4 | 补给 +1，废料 +12% |
| last_stand | 残血反扑 | 生存 | 稀有 | 2 | 残血伤害 +18%，残血移速 +18 |

冷却类效果有下限：

```text
electric_cooldown / slash_cooldown / poison_cooldown / dash_cooldown >= 0.12
```

但冲刺触发时还会用：

```text
dash_cd = max(0.55, dash_cooldown)
```

## 14. 掉落、连杀和结算

### 14.1 击杀奖励

普通敌人死亡：

- 必定掉落 XP，数量为敌人表中的 `xp`。
- 16% 概率掉落废料，数量为 `1 + int(run_time / 240)`。
- 3.5% 概率掉落治疗，数量 14。

Boss 死亡：

- 掉落废料 `24 + next_boss_index * 8`。
- 掉落 8 个 XP，每个 16。

### 14.2 连杀

每次击杀：

```text
combo += 1
max_combo = max(max_combo, combo)
combo_timer = 3.2
score += round(enemy.score * (1 + min(1.0, combo * 0.018)))
```

若 3.2 秒内没有继续击杀，连杀归零。受击也会清空连杀。

### 14.3 补给箱

首个补给在 42 秒出现，之后每 58 到 78 秒出现一次。

补给开启条件：玩家距离补给箱小于 46。

补给内容：

```text
scrap_amount = 8 + int(run_time / 95) + supply_luck * 3
xp_count = 4 + supply_luck
xp_amount_each = 10 + supply_luck * 2
heal_chance = 0.55 + supply_luck * 0.08
heal_amount = 18 + supply_luck * 4
```

### 14.4 结算

```text
earned = run_scrap + int(score / 125)
if won:
    earned += 80
```

结算后更新：

- 总废料。
- 最佳生存时间。
- 最高击杀。
- 最高连杀。

## 15. 局外背包

局外资源为废料。局外升级的消耗公式：

```text
cost = base_cost + level * base_cost / 2
```

| ID | 名称 | 最大等级 | 基础消耗 | 每级效果 |
| --- | --- | ---: | ---: | --- |
| kennel_training | 犬舍训练 | 5 | 30 | 最大生命 +10 |
| coil_research | 线圈研究 | 5 | 36 | 全伤害 +5% |
| field_pockets | 野外背包 | 4 | 28 | 拾取范围 +12 |
| old_world_boots | 旧世战靴 | 4 | 32 | 移动速度 +4 |

## 16. UI 设计规格

### 16.1 标题菜单

位置：左侧面板 `(54, 60)`，尺寸 `(396, 560)`。

内容：

- 游戏中文标题：人类没了！
- 英文副标题：Hoomans Are Gone
- 简短说明。
- 按钮：进入废墟、局外背包、重置存档。
- 操作提示。

### 16.2 HUD

左上玩家面板：

- 名称和等级：`刀盾狗 Lv.X`
- HP 条：红色。
- XP 条：青色。
- 击杀数。
- 本局废料。

顶部构筑条：

- 当连杀 >= 3 时显示连杀倍率。
- 显示电、刀、毒、生存四个构筑计数。

右上时间面板：

- 当前时间。
- 目标 12:00。
- 补给倒计时。
- 小地图。

右下技能栏：

| 槽位 | 文案 | 说明 |
| --- | --- | --- |
| Space | 冲刺 | 显示冲刺冷却遮罩 |
| Q | 毒瓶 | 显示毒瓶冷却遮罩 |
| R | 磁吸 | 显示磁吸冷却遮罩 |
| AUTO | 电链 | 显示电链冷却遮罩 |

### 16.3 升级选择页

位置：中间面板 `(226, 108)`，尺寸 `(828, 484)`。

内容：

- 标题：选择一次质变。
- 副文案：随机不是盲选：每张卡都推动一条可预期构筑。
- 三张卡横排。
- 控制按钮：重抽 -3 废料；跳过：回血 + 废料。

卡牌结构：

- 图标区域：按构筑使用生成式图标。
- 标题：升级名称。
- 标签：稀有度 / 构筑 / 已选层数。
- 当前构筑层数。
- 摘要描述。
- 前四个效果摘要。
- 选择质变按钮。

稀有度颜色：

| 稀有度 | 显示 | 颜色倾向 |
| --- | --- | --- |
| common | 普通 | 灰蓝 |
| uncommon | 精良 | 青色 |
| rare | 稀有 | 金色 |
| epic | 史诗 | 紫色 |

### 16.4 结算页

显示：

- 清剿成功 / 撤离/阵亡。
- 原因。
- 生存时间 / 12:00。
- 等级、击杀、最高连杀、分数。
- 本局废料、结算废料、总废料。
- 按钮：再来一局、局外背包、回到标题。

## 17. 资产清单

### 17.1 地图

| 文件 | 用途 |
| --- | --- |
| `assets/map/arena_base.png` | 废墟竞技场背景 |

### 17.2 主角

| 文件 | 用途 |
| --- | --- |
| `assets/sprites/player_dog.png` | 主角备用单张立绘 |
| `assets/sprites/player_dog_idle_sheet.png` | 站立动画 |
| `assets/sprites/player_dog_move_sheet.png` | 移动动画 |
| `assets/sprites/player_dog_attack_sheet.png` | 攻击动画 |
| `assets/sprites/player_dog_dash_sheet.png` | 冲刺动画 |
| `assets/sprites/player_dog_hurt_sheet.png` | 受击动画 |
| `assets/sprites/player_dog_anim_meta.json` | 主角动作帧裁切和锚点元数据 |

### 17.3 敌人

| 文件 | 用途 |
| --- | --- |
| `assets/sprites/enemy_crawler.png` | 啃噬者 |
| `assets/sprites/enemy_spitter.png` | 腐液喷吐者 |
| `assets/sprites/enemy_brute.png` | 甲壳重兽 |
| `assets/sprites/enemy_alpha.png` | 晶化首领 |

### 17.4 UI 图标

| 文件 | 用途 |
| --- | --- |
| `assets/ui/icon_electric.png` | 电构筑 |
| `assets/ui/icon_blade.png` | 刀构筑 |
| `assets/ui/icon_poison.png` | 毒构筑 |
| `assets/ui/icon_survival.png` | 生存构筑 |

## 18. 数据文件规格

### 18.1 敌人数据

路径：`Data/enemies.json`

字段：

```json
{
  "id": "crawler",
  "name": "啃噬者",
  "sprite": "enemy_crawler",
  "hp": 34,
  "speed": 76,
  "damage": 8,
  "xp": 4,
  "radius": 19,
  "mass": 1,
  "score": 8
}
```

### 18.2 局内升级数据

路径：`Data/upgrades.json`

字段：

```json
{
  "id": "chain_swarm",
  "name": "雷网形态",
  "build": "电",
  "rarity": "rare",
  "max_stacks": 4,
  "summary": "电链多弹跳 1 次，连锁范围扩大。",
  "effects": {
    "chain_count": 1,
    "chain_range": 28,
    "electric_damage": 4
  }
}
```

### 18.3 局外升级数据

路径：`Data/meta_upgrades.json`

字段：

```json
{
  "id": "kennel_training",
  "name": "犬舍训练",
  "desc": "每级 +10 最大生命。",
  "max": 5,
  "base_cost": 30
}
```

### 18.4 存档数据

路径：`user://hoomans_save.json`

结构：

```json
{
  "scrap": 0,
  "meta": {},
  "best_time": 0.0,
  "best_kills": 0,
  "best_combo": 0
}
```

## 19. 技术实现建议

### 19.1 场景结构

当前项目使用单一主场景：

```text
scenes/Main.tscn
scripts/Main.gd
```

主节点为 `Node2D`，负责：

- 输入映射。
- 资源加载。
- UI 构建。
- 战斗状态。
- 所有实体数组。
- 渲染。
- 存档。

复刻时可以继续使用单脚本架构，也可以拆分为：

- `GameController`
- `PlayerController`
- `EnemyManager`
- `WeaponSystem`
- `UpgradeSystem`
- `MetaProgression`
- `HudView`
- `AssetRegistry`

但必须保留本文件中定义的数值行为。

### 19.2 实体数据结构

本项目使用字典数组存储实体：

```text
player: Dictionary
stats: Dictionary
enemies: Array[Dictionary]
pickups: Array[Dictionary]
projectiles: Array[Dictionary]
pools: Array[Dictionary]
hazards: Array[Dictionary]
supply_crates: Array[Dictionary]
effects: Array[Dictionary]
damage_numbers: Array[Dictionary]
notifications: Array[Dictionary]
```

复刻时可以改为 typed class，但字段语义应保持一致。

### 19.3 渲染顺序

推荐绘制顺序：

1. 地图背景。
2. 暗色覆盖层。
3. 竞技场边界和计时弧。
4. 毒池。
5. 危险区。
6. 补给箱。
7. 拾取物。
8. 敌方投射物。
9. 敌人。
10. 玩家。
11. 特效。
12. 伤害数字。
13. HUD。

### 19.4 主角动画实现

渲染时不要直接绘制整张帧格，应使用元数据裁切主体：

```text
frame_meta = player_dog_anim_meta[action].frames[direction][frame]
source_rect = frame_meta.source
anchor = frame_meta.anchor
draw_scale = action.draw_scale
dest = foot_position - anchor * draw_scale
draw source_rect at dest with source_size * draw_scale
```

动作优先级：

```text
hurt > attack > dash > move > idle
```

方向判定：

```text
if abs(vec.x) > abs(vec.y):
    right or left
else:
    down or up
```

### 19.5 自动测试要求

至少保留 smoke 测试：

- 能加载主场景。
- 能开始一局。
- 主角动画元数据能加载。
- idle/move/attack/dash/hurt 帧数符合预期。
- 新竞技场边界不是旧窄圆。
- 能模拟若干秒战斗、升级、选卡、开补给、刷 Boss、触发伤害。

当前运行命令：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke.gd
```

## 20. 平衡目标

### 20.1 早期 0 到 3 分钟

目标：

- 玩家能理解移动、拾取、升级。
- 敌人大多为啃噬者。
- 电链和刀弧能稳定清小怪。
- 第一只 Boss 前应达到 3 到 5 级。

风险：

- 拾取范围太小会让新手漏经验。
- 电链过弱会导致 2 分钟前就被围死。

### 20.2 中期 3 到 9 分钟

目标：

- 构筑方向成型。
- 喷吐者和精英词缀迫使玩家走位。
- Boss 技能提供短期爆发压力。
- 补给箱提供回血和废料缓冲。

风险：

- 毒池如果冷却过低会造成全屏自动清怪，应依靠 `poison_cooldown < 4.4` 才自动投掷。
- 冲刺刀光过强时会让刀系无脑穿怪，应通过冲刺冷却下限控制。

### 20.3 后期 9 到 12 分钟

目标：

- 敌人数量明显增多。
- 重兽成为地形压力。
- Boss 与群怪叠加形成危险窗口。
- 玩家需要依赖局内构筑协同，不只是基础武器。

风险：

- 若存活上限过低，后期没有压迫感。
- 若 Boss 技能预警太短，玩家会觉得不公平。

## 21. 复刻验收标准

### 21.1 必须达成

- 可以从菜单进入游戏。
- 可以完整游玩至少 12 分钟。
- WASD、Space、左键、Q、R、Esc 全部可用。
- 地图显示为废墟竞技场，角色能在椭圆范围内移动。
- 角色有四朝向移动、攻击、冲刺、受击和站立动画。
- 敌人能从边界刷出并追击玩家。
- 电链、刀弧、毒池、冲刺刀光、磁吸均能正常工作。
- 升级时出现三选一卡牌。
- 所有局内升级都能生效。
- Boss 在 3、6、9、12 分钟出现。
- 终局 Boss 死亡后胜利结算。
- 废料可用于局外背包升级。

### 21.2 推荐达成

- 小地图显示敌人、拾取物、补给和玩家。
- Boss 血条显示。
- 连杀显示。
- 构筑计数显示。
- 伤害数字按伤害类型变色。
- 屏幕震动和 hitstop 反馈存在。
- 升级卡有图标、稀有度颜色和效果摘要。

### 21.3 不在当前版本范围内

当前版本没有完整音频系统、粒子系统、关卡切换、多角色、装备栏、剧情对话、联网或手柄适配。复刻时可以增加，但不要影响上述核心循环。

## 22. 复刻开发顺序建议

1. 创建 Godot 2D 项目和主场景。
2. 加载地图并建立 1280 x 720 绘制基础。
3. 实现椭圆竞技场边界。
4. 实现玩家移动、冲刺和动画锚点。
5. 实现敌人数据读取、刷怪、追击、碰撞伤害。
6. 实现拾取物、经验、升级。
7. 实现电链、刀弧、毒池。
8. 实现局内升级表和三选一 UI。
9. 实现 Boss、危险区、投射物、精英词缀。
10. 实现结算、废料、局外背包。
11. 接入 HUD、小地图、技能冷却、构筑计数。
12. 跑 smoke 测试并做 12 分钟长局平衡。

## 23. 快速数值总表

| 系统 | 关键数值 |
| --- | --- |
| 单局目标 | 720 秒 |
| 地图中心 | `(640, 366)` |
| 可走半轴 | `(560, 326)` |
| 初始 HP | 95 |
| 初始移速 | 154 |
| 初始拾取范围 | 58 |
| 初始升级 XP | 16 |
| XP 需求增长 | `floor(xp_next * 1.18 + 8)` |
| 初始电链 | 21 伤害，0.78 秒，3 跳，155 链距 |
| 初始刀弧 | 25 伤害，0.96 秒，92 距离，0.72 半角 |
| 初始毒池 | 9 毒伤，5.2 秒冷却，4 秒持续，54 半径 |
| 冲刺 | 620 速度，0.18 秒持续，0.32 秒无敌，2.5 秒冷却 |
| 磁吸 | 7.5 秒冷却，+220 拾取范围 |
| 补给 | 42 秒首刷，之后 58 到 78 秒 |
| Boss 时间 | 180 / 360 / 540 / 720 秒 |
| 连杀窗口 | 3.2 秒 |
| 结算废料 | 本局废料 + `score / 125`，胜利额外 +80 |

