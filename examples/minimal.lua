-- minimal.lua —— 最小可跑：一直往前开，撞墙就往右转
-- 十几行，用来确认自己的环境能跑通

function act(s)
  local my = s.my
  local a = my.dir / 256 * 2 * math.pi
  local nx = my.x + math.cos(a) * s.tile / 2
  local ny = my.y + math.sin(a) * s.tile / 2
  local blocked = s.walls[math.floor(ny / s.tile) * s.w + math.floor(nx / s.tile) + 1] == 1

  if blocked then
    return "RIGHT"
  end
  return "FWD"
end
