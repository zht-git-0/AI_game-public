-- aimer.lua —— 走近、对准、开火
-- 关键在距离：远处差一度就打飞，子弹弹回来会打死自己。
-- 所以先靠近到四格内，站定对准，一发的。

function act(s)
  local my, foe = s.my, s.foe
  local dx, dy = foe.x - my.x, foe.y - my.y
  local dist = math.sqrt(dx * dx + dy * dy)

  local ang = math.atan(dy, dx)
  if ang < 0 then ang = ang + 2 * math.pi end
  local want = math.floor(ang / (2 * math.pi) * 256 + 0.5) % 256
  local diff = (want - my.dir + 128) % 256 - 128

  -- 正前方半格是不是墙
  local a = my.dir / 256 * 2 * math.pi
  local nx = my.x + math.cos(a) * s.tile / 2
  local ny = my.y + math.sin(a) * s.tile / 2
  local blocked = s.walls[math.floor(ny / s.tile) * s.w + math.floor(nx / s.tile) + 1] == 1

  -- 太远：一边靠近一边转向；顶到墙就贴着墙绕
  if dist > 4 * s.tile then
    if blocked or math.abs(diff) > 8 then
      if diff > 0 then return "FWD+RIGHT" end
      return "FWD+LEFT"
    end
    return "FWD"
  end

  -- 四格内：原地微调角度，差得不多才值的开火
  if math.abs(diff) > 3 then
    if diff > 0 then return "RIGHT" end
    return "LEFT"
  end

  if #s.bullets == 0 and my.cooldown == 0 then
    return "FIRE"
  end
  return "NONE"
end
