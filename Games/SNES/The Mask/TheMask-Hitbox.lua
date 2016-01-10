---------------------------------------------------------------------------
--  The Mask - Hitbox Script for lsnes
--  http://tasvideos.org/Lsnes.html
--  
--  Author: Rodrigo A. do Amaral (Amaraticando)
--  Git repository: https://github.com/rodamaral/amaraticando-tas
--  
--  Known ROMs:
--  Mask, The (U).smc
--  Mask, The (J).smc
--  Mask, The (E).smc
---------------------------------------------------------------------------

-- Sprite's colors
local SPRITE_COLOR = {"green", "blue", "magenta", "yellow", "orange", "gold", "cyan", "olive", "coral", "salmon", "maroon"}

 
-- Better performance/names for lsnes API
local u8 =  memory.readbyte
local s8 =  memory.readsbyte
local w8 =  memory.writebyte
local u16 = memory.readword
local s16 = memory.readsword
local w16 = memory.writeword
local u24 = memory.readhword
local s24 = memory.readshword
local w24 = memory.writehword
local gui_text = gui.text
local gui_rectangle = gui.rectangle


-- draws a box given (x,y) and (x',y') with SNES' pixel sizes
function draw_box(x1, y1, x2, y2, color_line, color_bg)
    -- Draw from top-left to bottom-right
    if x2 < x1 then
        x1, x2 = x2, x1
    end
    if y2 < y1 then
        y1, y2 = y2, y1
    end
    
    gui_rectangle(2*x1, 2*y1, 2*(x2 - x1 + 1), 2*(y2 - y1 + 1), 2, color_line, color_bg)
end


function on_paint()
    local level_mode = u8("WRAM", 0x0097)
    if level_mode < 0x05 or level_mode > 0x0c then return end
    
    local x_pos = s16("WRAM", 0x185c)
    local y_pos = s16("WRAM", 0x1860)
    local x_subpixel = u8("WRAM", 0x185b)
    local y_subpixel = u8("WRAM", 0x185f)
    local camera_x = s16("WRAM", 0x0047)
    local camera_y = s16("WRAM", 0x004f)
    
    -- The Mask hitbox (slot 7)
    local x_screen, y_screen = x_pos - camera_x, y_pos - camera_y
    local box_id = s16("WRAM", 0x1858 + 0x1a) << 4
    local left = s16("BUS", 0x838000 + box_id)
    local up = s16("BUS", 0x838002 + box_id)
    local right = s16("BUS", 0x838004 + box_id)
    local down = s16("BUS", 0x838006 + box_id)
    
    local facing_left = bit.test(u8("WRAM", 0x1858 + 0x1f), 6)
    if facing_left then left, right = - right, - left end
    local x1 = x_screen + left
    local x2 = x_screen + right
    local y1 = y_screen + up
    local y2 = y_screen + down
    
    draw_box(x1, y1, x2, y2, 0xff0000, 0xd00000ff)
    gui_text(2*x_screen, 2*y_screen, 7)
    
    -- Other sprites
    local sprites_init_pointer = u16("WRAM", 0x150a)
    local final_pointer = u16("WRAM", 0x0352)
    local sprite_count = (final_pointer - sprites_init_pointer)//107
    if sprite_count < 0 or sprite_count >= 1000 then return end -- debug: absurd sprite count, probably result of WRAM corruption
    for slot = 0, sprite_count do
        local base = sprites_init_pointer + 107*slot
        local status = u8("WRAM", base + 0x0e)
        
        if status ~= 0 and slot ~= 7 then
            local x_pos = s16("WRAM", base + 0x4)
            local y_pos = s16("WRAM", base + 0x8)
            local x_screen, y_screen = x_pos - camera_x, y_pos - camera_y
            
            -- draw nearby objects
            if x_screen >= - 200 and x_screen <= 712 or y_screen >= -200 or y_screen <= 678 then
                local box_id = s16("WRAM", base + 0x1a) << 4
                local left = s16("BUS", 0x838000 + box_id)
                local up = s16("BUS", 0x838002 + box_id)
                local right = s16("BUS", 0x838004 + box_id)
                local down = s16("BUS", 0x838006 + box_id)
                
                local facing_left = bit.test(u8("WRAM", base + 0x1f), 6)
                if facing_left then left, right = - right, - left end
                
                local x1 = x_screen + left + 1 -- why ???
                local x2 = x_screen + right
                local y1 = y_screen + up
                local y2 = y_screen + down
                
                draw_box(x1, y1, x2, y2, SPRITE_COLOR[slot%(#SPRITE_COLOR) + 1], 0xd0ff00ff)
                gui_text(2*x_screen, 2*y_screen, slot)
            end
            
        end
    end
end


function on_timer()
    set_timer_timeout(10000000)
    collectgarbage()
end


-- End of definitions, execute
local movie_hash = movie.get_rom_info()[1].sha256
if  movie_hash ~= "44cc113ce1e7616cc737adea9e8f140436c9f1c3fba57e8e9db48025d4ace632" -- U
and movie_hash ~= "30fecd9145e814e9e5550aa6a43d739c7ba11a902e2b5cf6bddd7fd06e796ca4" -- J
and movie_hash ~= "c75627d72b53eff0d8993c9f03622bd9d8a5d04975b722fe8d64a141a914b0f1" -- PAL
then print"WARNING: the current ROM seems modified, this script might not work." end

set_timer_timeout(10000000)
gui.repaint()
