-- emulator: up-to-date lsnes
-- game: Super Mario World
-- this displays all possible blocks within the level
-- doesn't flip tiles yet

local TILE_WIDTH, TILE_HEIGHT = 32, 64
local BITMAP_WIDTH, BITMAP_HEIGHT = 8, 8
local DEBUG_INFO = false

-- table of all palettes
local palette_db = {}

-- table of palettes that changed last frame, or that must be recalculated
local unset_palettes = {}

-- table of all 8x8 tiles
local tile_db = {}

-- table of all 8x8 tiles that changed last frame, or that must be recalculated
local unset_tiles = {}

-- tilemap displaying all types of tiles in the level stores in VRAM
local tilemap = gui.tiled_bitmap.new(TILE_WIDTH, TILE_HEIGHT, BITMAP_WIDTH, BITMAP_HEIGHT)

-- read only region
local vram_region = memory.readregion("BUS", 0x0d8000, 0x8000)

local function copy_bitmap(src)
  local width, height = src:size()
  local dest = gui.bitmap.new(width, height)
  dest:blit(0, 0, src, 0, 0, width, height)

  return dest
end

local function create_tile(tile)
  -- vhopppcc cccccccc format
  local id, color, priority, xflip, yflip = bit.bfields(tile, 10, 3, 1, 1, 1)
  xflip = xflip > 0
  yflip = yflip > 0

  local palette = palette_db[color]
  local bitmap = tile_db[id]

  --[[ ignore flipping for now
  local bitmap = copy_bitmap(tile_db[id])
  if xflip then bitmap:hflip() end
  if yflip then bitmap:vflip() end
  --]]

  return bitmap, palette
end

local function update_tilemap(x, y, tile)
  local bitmap, palette = create_tile(tile)
  tilemap:set(x, y, bitmap, palette)
end

local function create_map16_gfx()
  local ptr_region = memory.readregion("WRAM", 0x0fbe, 0x400)
  local x, y = 0, 0

  for id = 0, 0x1ff do
    local pointer = ptr_region[2*id] + 256*ptr_region[2*id + 1]

    local ul = vram_region[pointer - 0x8000 + 0] + 256*vram_region[pointer - 0x8000 + 1]
    local ll = vram_region[pointer - 0x8000 + 2] + 256*vram_region[pointer - 0x8000 + 3]
    local ur = vram_region[pointer - 0x8000 + 4] + 256*vram_region[pointer - 0x8000 + 5]
    local lr = vram_region[pointer - 0x8000 + 6] + 256*vram_region[pointer - 0x8000 + 7]

    -- update current 16x16 block
    update_tilemap(x, y, ul)
    update_tilemap(x, y + 1, ll)
    update_tilemap(x + 1, y, ur)
    update_tilemap(x + 1, y + 1, lr)

    -- update tilemap entry
    x = x + 2
    if x >= TILE_WIDTH then
      x = 0
      y = y + 2
    end
  end
end

local function create_palette_db()
  for id = 0, 7 do
    palette_db[id] = bsnes.dump_palette("CGRAM", id*0x20, 16, true)
  end
end

local function update_palette_db()
  for id in pairs(unset_palettes) do
    bsnes.redump_palette(palette_db[id], "CGRAM", id*0x20, true)
    unset_palettes[id] = nil
  end
end

local function create_tile_db()
  for id = 0, 0x3ff, 1 do
      tile_db[id] = bsnes.dump_sprite("VRAM", 0x20 * id, 1, 1)
  end
end

local function update_tile_db()
  for id in pairs(unset_tiles) do
    bsnes.redump_sprite(tile_db[id], "VRAM", 0x20 * id)
    unset_tiles[id] = nil
  end
end

-- for some debugging
local function display_range(region, start, size, stride, palette)
  local x = - BITMAP_WIDTH*TILE_WIDTH
  local y = 0

  for id = 0, math.floor(size/stride) - 1 do
    local bitmap = bsnes.dump_sprite(region, start + stride * id, 1, 1)
    bitmap:draw(x, y, palette)

    x = x + 8
    if x >= 0 then
      x = - BITMAP_WIDTH*TILE_WIDTH
      y = y + 8
    end
  end

  gui.solidrectangle(x, y, 8, 8, "red")
  gui.text(0, 0, math.floor(size/stride))
end

---------------------------------
---------------------------------

local map16_change_checker = memory.compare_new("WRAM", 0x0fbe, 0x400)

for id = 0, 0x3ff do
  memory.registerwrite("VRAM", 0x20 * id, function()
    unset_tiles[id] = true
  end)
end

for id = 0, 7 do
  memory.registerwrite("CGRAM", 0x20 * id, function()
    unset_palettes[id] = true
  end)
end

local function size(t) local c = 0; for a, b in pairs(t) do c = c + 1; end return c; end

function on_paint()
  local left_gap = BITMAP_WIDTH*TILE_WIDTH
  gui.bottom_gap(64)
  gui.left_gap(left_gap)

  if DEBUG_INFO then
    gui.text(0, 448, string.format("Tiles: %d ; Pals: %d", size(unset_tiles), size(unset_palettes)), 0xffffff, -1, 0x20)
  end

  if map16_change_checker() then
    create_map16_gfx()
  end
  update_palette_db()
  update_tile_db()

  gui.solidrectangle(-left_gap, 0, BITMAP_WIDTH*TILE_WIDTH, BITMAP_HEIGHT*32, 0x000020)
  gui.solidrectangle(-left_gap, BITMAP_HEIGHT*32, BITMAP_WIDTH*TILE_WIDTH, BITMAP_HEIGHT*32, 0x200000)
  tilemap:draw(-left_gap, 0)

  if DEBUG_INFO then
    gui.text(0, 448 + 16, string.format("RAM: %.3f MiB", collectgarbage("count")/1024), "red", -1, 0x20)
  end
end

function on_video()
  gui.set_video_scale(2, 2)
  on_paint()
end

function on_post_load()
  for id = 0, 0x3ff do
    unset_tiles[id] = true
  end
  for id = 0, 7 do
    unset_palettes[id] = true
  end

  gui.repaint()
end

create_palette_db()
create_tile_db()
create_map16_gfx()
gui.repaint()
