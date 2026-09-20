# 架构说明

## 定位

Aegis Royale 是**完全离线的单机建造大逃杀**。所有角色、地形、风暴、掉落、AI 与结算都在本地场景树中运行。项目不设计服务器、网络复制、客户端预测或反作弊。

渲染后端为 **Forward+**（Vulkan）。若目标机器不支持，可切换到 `gl_compatibility`。

## 运行时装配

`scripts/main.gd` 是唯一入口，负责：

1. 读取 `LocalProfile`（`user://aegis_royale_profile.json`）。
2. 显示 `Lobby`。
3. 收到开始信号后按顺序构建世界：
   - `WorldEnvironment`（程序化天空、雾、SSAO、Glow、Filmic）
   - `DirectionalLight3D`（4 级阴影分割，最大 160 m）
   - `Terrain`（高度场）
   - `MapBuilder`（兴趣点、道路、植被、战利品）
   - `Storm`
   - `PlayerController` + N 个 `Bot`
   - `HUD`
   - 暂停层
4. 逐帧统计存活人数并判定胜负。

## 模块职责

| 文件 | 职责 |
|---|---|
| `core/materials.gd` | 材质缓存工厂，统一全场景渲染状态 |
| `character/character_model.gd` | 程序化人形骨架，暴露具名关节 |
| `character/animator.gd` | 读取速度/瞄准/下蹲/空中状态驱动关节角度 |
| `character/actor.gd` | 战斗单位基类：移动、重力、生命护盾、武器状态机、弹药、物品、拾取、伤害结算 |
| `character/player.gd` | 玩家：独立镜头枢轴、越肩弹簧臂、建造/编辑/交互输入 |
| `weapons/weapon_db.gd` | 武器与消耗品数据表、稀有度、评分函数 |
| `weapons/weapon_rig.gd` | 第三人称武器模型、枪口、火光、持枪/瞄准姿态混合 |
| `combat/effects.gd` | 静态特效：曳光、命中、爆炸、烟尘、碎屑 |
| `combat/projectile.gd` | 火箭：重力抛射、射线防穿透、球形范围衰减 |
| `build/build_piece.gd` | 结构几何、3×3 单元、编辑拓扑、耐久与碎裂 |
| `build/build_system.gd` | 网格目标计算、合法性校验、连发建造、选格编辑、AI 建造接口 |
| `world/terrain.gd` | 高度场生成、兴趣点/道路削平、网格与碰撞、高度查询 |
| `world/building_kit.gd` | 建筑构件：带门窗的墙、楼板、楼梯、屋顶、塔、仓库、瞭望塔、集装箱 |
| `world/map_builder.gd` | 兴趣点定义、道路定义、建筑布置、植被散布、战利品分布 |
| `world/storm.gd` | 8 阶段缩圈、中心偏移、圈外伤害、AI 查询接口 |
| `world/harvest_prop.gd` | 可采集资源（木/石/金属） |
| `world/loot_pickup.gd` | 地面战利品，进入范围自动拾取 |
| `world/loot_container.gd` | 宝箱，按分级生成掉落 |
| `ai/bot.gd` | 感知、记忆、效用状态机、建造战术 |
| `ui/hud.gd` | 单次 `_draw` 绘制全部 HUD 元素 |
| `ui/lobby.gd` | 大厅、设置面板 |
| `ui/local_profile.gd` | 本地 JSON 档案 |

## 地形数据模型

- 岛屿 320 × 320 m，`RES = 100`，共 101 × 101 个高度采样点。
- 高度 = `多层 Simplex 噪声 × 海岸衰减 + 中央高地 - 海面偏移`。
- 削平顺序：先生成原始高度 → 兴趣点圆盘混合削平 → 道路走廊混合削平。
- `height_at(x, z)` 做双线性插值，供建造合法性、AI 落点、放置道具使用。
- `normal_at` / `slope_at` 由高度场差分求得，用于植被密度与顶点着色。
- 碰撞使用 `ArrayMesh.create_trimesh_shape()`，避免非均匀缩放碰撞体。

## 建造数据模型

- 平面网格 4 m，垂直层高 3 m。
- **墙**：占所在格的一条边；键为 `wall:cellX:level:cellZ:edge`。因此在自己所在格转四次即可四面包围。
- **地板 / 斜坡**：占整格；键为 `type:cellX:level:cellZ`。
- **锥顶**：放在角色所在格的上一层，作为屋顶。
- 占用表是一份**共享 Dictionary**（GDScript 中 Dictionary 为引用类型），由 `main.gd` 持有并传给每个 `BuildSystem`，因此不同角色的建造会互相占位。
- 结构销毁时通过 `tree_exiting` 回调清除占用键。
- 合法性：材料、最大距离 15 m、占用冲突、地形高度下限。
- 墙与地板保存 9 个单元的状态数组，编辑时逐格重建网格与碰撞。

## AI 决策

每帧分频执行：扫描（0.12–0.30 s）、瞄准误差刷新（0.30–0.75 s）、状态决策（0.22–0.45 s）。

1. 风暴危险度最高优先级 → `ROTATE`。
2. 有存活目标：低血 → `DEFEND`；近距离且激进 → `PUSH`；否则 `ENGAGE`。
3. 无目标且需要补给 → `DEFEND`（治疗）。
4. 否则 `LOOT`。

建造触发点：受击反应补墙、交战中随机掩体、推进时墙+斜坡、低血四面建盒。

## 性能

默认 32 个战斗单位。当前规模下全部保留完整物理实体。扩展到 60+ AI 或更高画质时应：

- 远距离 AI 降频为战略模拟，近距离保持高频战术更新。
- 植被与装饰改 MultiMesh；建筑碰撞按区域启停。
- 感知查询分帧，避免同帧遍历全部角色。
- 地图分区块，远处兴趣点用简化代理。
- 特效与拾取物对象池化。

## 知识产权约束

地图仅复用「中心高价值区、外围主题据点、普通聚落、道路/河网连接」这类通用关卡设计规律。
不得导入第三方游戏提取资产，不得复制其岛屿轮廓、坐标、建筑组合、POI 名称、角色、UI 美术、声音、标志或逐项专有数值表。
玩法结构可以相近，具体表达与内容必须独立创作。
