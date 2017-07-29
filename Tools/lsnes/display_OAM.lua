--[[
local SIZE_TABLE = {
  [0] = {8x8  and 16x16
   001 =  8x8  and 32x32
               010 =  8x8  and 64x64
               011 = 16x16 and 32x32
               100 = 16x16 and 64x64
               101 = 32x32 and 64x64
               110 = 16x32 and 32x64
               111 = 16x32 and 32x32
}
--]]

local function hex(...)
  local t = table.pack(...)

  local text = ""
  for _, b in ipairs(t) do
    if type(b) == "number" then
      text = string.format("%s %x", text, b)
    else
      text = text .. " " .. b
    end
  end

  return text
end

local function hflip(bitmap)
  local width, height = bitmap:size()
  local new = gui.bitmap.new(width, height)

  for x = 0, width - 1 do
    for y = 0, height - 1 do
      local index = bitmap:pget(x, y)
      new:pset(width - x - 1, y, index)
    end
  end

  return new
end

local function vflip(bitmap)
  local width, height = bitmap:size()
  local new = gui.bitmap.new(width, height)

  for x = 0, width - 1 do
    for y = 0, height - 1 do
      local index = bitmap:pget(x, y)
      new:pset(x, height - y - 1, index)
    end
  end

  return new
end

local function dump(offset, size, h_flag, v_flag)
  local length = 16
  local src = bsnes.dump_sprite("VRAM", offset, size, size)

  if h_flag then src:hflip() end
  --if h_flag then src = hflip(src) end
  if v_flag then src:vflip() end
  --if v_flag then src = vflip(src) end

  local dest = gui.bitmap.new(2*length, 2*length)

  dest:blit_scaled(0, 0, src, 0, 0, length, length, 2, 2)
  return dest
end

local function display_OAM()
  local OAM = memory.readregion("OAM", 0, 544)

  for i = 0, 127 do
    local table_A = 4*i
    local table_B_byte = 512 + math.floor(i/4)
    local table_B_bit = 2*(i%4)

    -- table A properties
    local x = OAM[table_A]
    local y = OAM[table_A + 1]
    local tile = OAM[table_A + 2]
    local extra_tile, c, p, h, v = bit.bfields(OAM[table_A + 3], 1, 3, 2, 1, 1)

    -- table B
    local value_B = OAM[table_B_byte]
    local extra_x = bit.test(value_B, table_B_bit + 0)
    local size = bit.test(value_B, table_B_bit + 1)

    if extra_x then x = x + 0x100 end
    if false and i < 0x20 then
      gui.text(-256 + 8*11*math.floor(i*16/512), (16*i)%512, string.format("%.2x:%d%s,%d $%x, %d %d %x %x %x",
                                                            i, x, extra_x and "*" or "", y, tile, v, h, p, c, extra_tile))
    end
    if y >= 240 then y = y - 256 end
    if x >= 0x180 then x = x - 0x200 end
    --if x < 0 then x = x + 256 end
    tile = tile + 0x100*extra_tile

    -- attempt to draw the actual tile!
    if y >= 0 then
      local m = memory.getregister
      local name = m"ppu_oam_nameselect"
      local base = m"ppu_oam_tdaddr"
      --base = 0--0xc000--0x2000
      local bitmap = dump(base + 32*tile, size and 2 or 1, h == 1, v == 1)
      local palette = bsnes.dump_palette("CGRAM", 0x100 + 32*c, 16, true)
      bitmap:draw(2*x, 2*y, palette)
    end

    -- draw
    local width = size and 16 or 8
    local height = size and 16 or 8 -- ?
    gui.rectangle(2*x, 2*y, 2*width, 2*height, 2, 0xd0ff0000)
    --gui.text(2*x, 2*y, string.format("%x %d", i, x), "yellow", -1, 0)
    --gui.text(-256 + 8*8*math.floor(i/32), (i%32)*16, string.format("%x %d", i, x), "gray", -1, 0)
  end
end


local function on_paint()
  gui.left_gap(256)
  gui.right_gap(256)
  gui.top_gap(32)
  gui.bottom_gap(64)

  display_OAM()
end

local function on_video()
  gui.set_video_scale(2, 2)
  on_paint()
end

gui.repaint()
