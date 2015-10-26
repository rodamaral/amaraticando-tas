---------------------------------------------------------------------------
--  lsnes - CUSTOMFONT creator from char-set image
--  This creates a font file that lsnes can understand.
--  For instance, this image http://uzebox.org/wiki/index.php?title=File:Font6x8.png
--  is transformed into this font: https://mega.nz/#!FsljRLQC!lph-VA0dPQm_kzjypnN3wVg0qFaAEDeoVK_q_vgUcQE
--  The image must have this structure, with black background and white text.
--  
--  Author: Rodrigo A. do Amaral (Amaraticando)
--  Git repository: https://github.com/rodamaral/amaraticando-tas
---------------------------------------------------------------------------

--#############################################################################
-- CONFIGURATION:

-- where you'd like to save the font?
local NEW_FONT_PATH = [[C:\full path here\name.font]]

-- where you'd like to read the image from?
local font_set_dbitmap_path = [[C:\full path here\original_image.png]]

-- Dimensions of each glyph (EDIT IT!)
local glyph_width = 8
local glyph_height = 12

-- Number of tiles in the char set
local set_width = 16 -- how many tiles per row
local set_height = 7 -- how many tiles per column

-- ASCII characters used. Must be the same of the image, from left to right (first), and from top to bottom
local characters_sequence = [[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~]] .. "\127"

-- END OF CONFIGURATION
--#############################################################################

-- convert the original png dbitmap to a bitmap suitable for fonts
local function dbitmap_to_blackwhite_bitmap(dbitmap)
    local w, h =  dbitmap:size()
    local bitmap = gui.bitmap.new(w, h)
    local color
    
    local palette = gui.palette.new()
    palette:set(0, 0)
    palette:set(1, 0xffffff)
    
    for x = 0, w - 1 do
        for y = 0, h - 1 do
            color = dbitmap:pget(x,y)
            bitmap:pset(x, y, color < 0x808080 and 0 or 1)
        end
    end
    
    return bitmap
end

-- Verify whether the original image exists
if type(font_set_dbitmap_path) ~= "string" or not io.open(font_set_dbitmap_path) then error("Wrong path for original image") end

-- make the black and white bitmap
local font_set_dbitmap = gui.image.load_png(font_set_dbitmap_path)  --- this function is crashing the emulator for some pngs
local font_set_bitmap = dbitmap_to_blackwhite_bitmap(font_set_dbitmap)
local new_font = gui.font.new()

-- read each tile of the original image
local glyph_help = {}  -- debug
local index = 0
for ch in string.gmatch(characters_sequence, ".") do
    local h = index//set_width
    local w = index%set_width
    local glyph = gui.bitmap.new(glyph_width, glyph_height)
    local color
    
    for y = 0, glyph_height - 1 do
        for x = 0, glyph_width - 1 do
            color = font_set_bitmap:pget(glyph_width*w + x, glyph_height*h + y)
            glyph:pset(x, y, color)
        end
    end
    
    --print(index, ch, w, h, glyph)  -- debug
    index = index + 1
    glyph_help[ch] = glyph
    new_font:edit(ch, glyph)
end

-- the bad character
do
    local glyph = gui.bitmap.new(glyph_width, glyph_height)
    for y = 0, glyph_height - 1 do
        for x = 0, glyph_width - 1 do
            color = (x%2 == 0 and y%2 == 0) and 0 or 1
            glyph:pset(x, y, color)
        end
    end
    new_font:edit("", glyph)
end

--print(new_font)  -- debug
new_font:dump(NEW_FONT_PATH)  -- if there's an old file, there'll be a backup
print("Saved new font at "  .. NEW_FONT_PATH)

function on_paint()
    gui.right_gap(300)
    
    gui.text(0, 0, "New font:", "white", "black")
    new_font(0, 16, characters_sequence, "white", nil, "black")
    gui.text(0, 32, "Standard font:", "white", "black")
    gui.text(0, 48, characters_sequence, "white", nil, "black")
    
    local palette = gui.palette.new()
    palette:set(0, 0)
    palette:set(1, 0xffffff)
    
    local x, y = 16, 100
    for a, b in pairs(glyph_help) do
        b:draw(x, y, palette)
        x = x + 32
        if x >= 500 then
            y = y + 32
            x = 16
        end
    end
    
    font_set_bitmap:draw(0, 300, palette)
end

gui.repaint()
