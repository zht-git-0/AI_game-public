# 怎么写一个 AI

你在平台上交的是一段 **Lua 脚本**。平台把它放进沙箱，每 1/30 秒调用一次，
你的返回值决定这辆坦克这一拍做什么。

## 入口

只有一个函数：

```lua
function act(s)
  return "FWD"
end
```

`act` 每一拍被调用一次，`s` 是只读的战场快照。返回值是一条指令字符串（可以合并，见下）。

同一段脚本会活一整局，所以**可以在函数外存状态**——比如记一下自己转了几次：

```lua
local tick = 0
function act(s)
  tick = tick + 1
  if tick % 30 < 10 then return "FWD+RIGHT" end
  return "FWD"
end
```

## 状态对象 s

| 字段 | 类型 | 说明 |
|---|---|---|
| `s.my` | table | 自己：`{x, y, dir}` |
| `s.foe` | table | 对手：`{x, y, dir}` |
| `s.my.dir` | 0~255 | 朝向。**同时也是运动方向**，0 是屏幕右方，数值增大往屏幕下方转 |
| `s.my.cooldown` | int | 开火冷却，0 表示这一拍可以开火 |
| `s.bullets` | array | 场上所有子弹：`{x, y, dir, bounces, ttl}` |
| `s.walls` | array | 77 个元素（11 列 × 7 行），`1` 表示实心墙 |
| `s.w` / `s.h` | int | 地图列数 / 行数（当前 11 和 7） |
| `s.tile` | int | 一格的边长，内部单位 |

### 关于坐标

坐标是**内部单位**，一格等于 `s.tile`（15360）。别自己背这个数，用 `s.tile`：

```lua
local col = math.floor(s.my.x / s.tile)   -- 第几列，从 0 开始
```

### 关于 s.walls

一维数组，**下标从 1 开始**，索引是 `(行-1) * 列数 + 列`：

```lua
local function is_wall(s, col, row)   -- col, row 都从 1 开始
  return s.walls[(row - 1) * s.w + col] == 1
end
```

地图四周永远是墙，别想着开出去。

## 指令表

返回值是字符串，可以**用 `+` 合并**：

| 指令 | 作用 |
|---|---|
| `"FWD"` | 前进 |
| `"BACK"` | 后退 |
| `"LEFT"` | 左转（每拍 6 档） |
| `"RIGHT"` | 右转（每拍 6 档） |
| `"FIRE"` | 开火 |
| `"NONE"` | 什么都不做 |

合并的例子：

```lua
return "FWD+RIGHT"      -- 边走边转，走弧线
return "FWD+FIRE"       -- 边冲边射
```

`LEFT` 和 `RIGHT` 同时给会互相抵消；`FWD` 和 `BACK` 同理。
不认识的指令当 `NONE` 处理。

也可以返回数组：`return {"FWD", "FIRE"}`，效果一样，看你习惯。

## 你跑在什么环境里

- **只有四个库**：基础库、`math`、`string`、`table`。
  没有 `io`、没有 `os`、没有 `package`、没有网络、没有随机数。
- **每拍有时间预算**（5 毫秒）。超时会沿用你上一次的动作，并且记一次超时。
  偶尔超时不会立刻死，但一局里超太多次会很难看。
- **跑局有总时长上限**（30 秒）。真死循环会被掐掉。

所以：别写 `while true do end`，别指望 `math.random`（根本没有）。

## 几个能用的套路

### 1. 算准角度再开火

```lua
local my, foe = s.my, s.foe
local ang = math.atan(foe.y - my.y, foe.x - my.x)
if ang < 0 then ang = ang + 2 * math.pi end
local want = math.floor(ang / (2 * math.pi) * 256 + 0.5) % 256
local diff = (want - my.dir + 128) % 256 - 128   -- 正数要右转，负数要左转
```

`diff` 的绝对值小于 6 就是差不多对准了（一拍的转向量是 6 档）。

### 2. 看有没有墙挡着

从自己到对手画一条线，按 `s.tile` 采样，碰上 `1` 就说明挡住了：

```lua
local clear, dist, step, k = true, math.sqrt(dx*dx + dy*dy), s.tile / 8, 2
while k * step < dist - s.tile do
  local x = my.x + math.cos(ang) * k * step
  local y = my.y + math.sin(ang) * k * step
  if s.walls[math.floor(y / s.tile) * s.w + math.floor(x / s.tile) + 1] == 1 then
    clear = false
    break
  end
  k = k + 1
end
```

### 3. 别被自己的子弹打死

子弹最多弹三次才消失，**弹回来的子弹一样能打死你**。
所以要么等 `#s.bullets == 0` 再开火，要么确认自己和目标之间真的没有墙。

## 怎么交上来

```
POST https://aigameground.com/api/submit
Content-Type: application/json
x-arena-token: <提交码>

{"name": "你的名字", "source": "<Lua 源码>"}
```

立刻返回 `202` 和一个任务号：

```json
{"ok": true, "job": "1-ab12cd34", "position": 1}
```

然后轮询 `GET /api/job/<任务号>`，直到 `status` 是 `done` 或 `error`：

```json
{"status": "done", "result": {"ok": true, "bot": {"rating": 1020}, "log": [...]}}
```

**名字是先到先得的**：第一次提交某个名字，返回里会带一串 `secret`；
以后改同名必须带上它，否则会提示名字已被占。

提交码目前是邀请制——找站主要。

## 完整示例

见 [examples/](examples/)：

- `minimal.lua` —— 最小可跑，二十行，只会开和转向（打不中人，但不会死）
- `aimer.lua` —— 走近、对准、开火；重点在「为什么必须靠到四格内才开枪」
- `kiter.lua` —— 控制距离的放风筝打法，近了退、远了追

三个都在真实内核上跑过：`aimer` 和 `kiter` 对靶子是几胜几平零负，
`minimal` 全是平局——它压根不开火，拿来验证环境用的。
