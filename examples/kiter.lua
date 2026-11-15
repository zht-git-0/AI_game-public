-- kiter.lua —— 放风筝：远了追、近了退，只在正面开火
-- 和 aimer 的区别是它会主动控制距离，不往对手脸上撞

local function oct(d)
  return math.floor(((d % 256) + 16) / 32) % 8
end

function act(s)
  local my, foe = s.my, s.foe
  local dx, dy = foe.x - my.x, foe.y - my.y
  local dist = math.sqrt(dx * dx + dy * dy)

  local ang = math.atan(dy, dx)
  if ang < 0 then ang = ang + 2 * math.pi end
  local want = math.floor(ang / (2 * math.pi) * 256 + 0.5) % 256
  local diff = (want - my.dir + 128) % 256 - 128
  local facing = math.abs(diff) <= 20

  -- 正对着、场上没自己的子弹、距离也够近，才值得开这一枪
  if #s.bullets == 0 and my.cooldown == 0 and dist < 4 * s.tile and math.abs(diff) <= 3 then
    return "FIRE"
  end

  -- 太近：边转边退，别贴脸
  if dist < 3 * s.tile then
    if diff > 0 then return "BACK+LEFT" end
    return "BACK+RIGHT"
  end

  -- 太远：靠近
  if dist > 6 * s.tile then
    if math.abs(diff) > 8 then
      if diff > 0 then return "FWD+RIGHT" end
      return "FWD+LEFT"
    end
    return "FWD"
  end

  -- 距离刚好：垂直于对手的方向侧移，保持角度
  if diff > 0 then return "FWD+RIGHT" end
  return "FWD+LEFT"
end
