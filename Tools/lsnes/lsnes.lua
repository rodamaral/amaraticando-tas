--#############################################################################
-- CONFIG:

local OPTIONS = {
    -- Hotkeys  (look at the manual to see all the valid keynames)
    -- make sure that the hotkeys below don't conflict with previous bindings
    hotkey_increase_opacity = "equals",  -- to increase the opacity of the text: the '='/'+' key 
    hotkey_decrease_opacity = "minus",   -- to decrease the opacity of the text: the '_'/'-' key
    
    -- Script settings
    use_custom_fonts = true,
    
    -- Lateral gaps (initial values)
    left_gap = 20*8 + 2,
    right_gap = 100,  -- 17 maximum chars of the Level info
    top_gap = 20,
    bottom_gap = 8,
}

-- Colour settings
local COLOUR = {
    transparency = -1,
    
    -- Text
    default_text_opacity = 1.0,
    default_bg_opacity = 0.4,
    text = 0xffffff,
    background = 0x000000,
    halo = 0x000040,
    warning = 0x00ff0000,
    warning_bg = 0x000000ff,
    warning2 = 0xff00ff,
    weak = 0x00a9a9a9,
    very_weak = 0xa0ffffff,
}

-- EDIT???
LSNES = {}
draw = {}

-- Font settings
LSNES.FONT_HEIGHT = 16
LSNES.FONT_WIDTH = 8
CUSTOM_FONTS = {
        [false] = { file = nil, height = LSNES.FONT_HEIGHT, width = LSNES.FONT_WIDTH }, -- this is lsnes default font
        
        snes9xlua =       { file = [[data/snes9xlua.font]],        height = 16, width = 10 },
        snes9xluaclever = { file = [[data/snes9xluaclever.font]],  height = 16, width = 08 }, -- quite pixelated
        snes9xluasmall =  { file = [[data/snes9xluasmall.font]],   height = 09, width = 05 },
        snes9xtext =      { file = [[data/snes9xtext.font]],       height = 11, width = 08 },
        verysmall =       { file = [[data/verysmall.font]],        height = 08, width = 04 }, -- broken, unless for numerals
}

-- Others
local INPUT_RAW_VALUE = "value"  -- name of the inner field in input.raw() for values


-- END OF CONFIG < < < < < < <
--#############################################################################
-- INITIAL STATEMENTS:


-- Load environment
local bit, gui, input, movie, memory, memory2 = bit, gui, input, movie, memory, memory2
local string, math, table, next, ipairs, pairs, io, os, type = string, math, table, next, ipairs, pairs, io, os, type

-- Script verifies whether the emulator is indeed Lsnes - rr2 version / beta23 or higher
if not lsnes_features or not lsnes_features("text-halos") then
    error("This script works in a newer version of lsnes.")
end

-- Text/draw.Bg_global_opacity is only changed by the player using the hotkeys
-- Text/Bg_opacity must be used locally inside the functions
draw.Text_global_opacity = COLOUR.default_text_opacity
draw.Bg_global_opacity = COLOUR.default_bg_opacity
draw.Text_local_opacity = 1
draw.Bg_local_opacity = 1

-- Verify whether the fonts exist and create the custom fonts' drawing function
draw.font = {}
for font_name, value in pairs(CUSTOM_FONTS) do
    if value.file and not io.open(value.file) then
        print("WARNING:", string.format("./%s is missing.", value.file))
        CUSTOM_FONTS[font_name] = nil
    else
        draw.font[font_name] = font_name and gui.font.load(value.file) or gui.text
    end
end

local fmt = string.format

-- Compatibility of the memory read/write functions
local u8  = function(address, value) if value then memory2.WRAM:byte(address, value) else
    return memory.readbyte("WRAM", address) end
end
local s8  = function(address, value) if value then memory2.WRAM:sbyte(address, value) else
    return memory.readsbyte("WRAM", address) end
end
local u16  = function(address, value) if value then memory2.WRAM:word(address, value) else
    return memory.readword("WRAM", address) end
end
local s16  = function(address, value) if value then memory2.WRAM:sword(address, value) else
    return memory.readsword("WRAM", address) end
end
local u24  = function(address, value) if value then memory2.WRAM:hword(address, value) else
    return memory.readhword("WRAM", address) end
end
local s24  = function(address, value) if value then memory2.WRAM:shword(address, value) else
    return memory.readshword("WRAM", address) end
end


--#############################################################################
-- SCRIPT UTILITIES:


-- Variables used in various functions
local Previous = {}
local User_input = {}


-- unsigned to signed (based in <bits> bits)
local function signed(num, bits)
    local maxval = 1<<(bits - 1)
    if num < maxval then return num else return num - 2*maxval end
end


-- Transform the binary representation of base into a string
-- For instance, if each bit of a number represents a char of base, then this function verifies what chars are on
local function decode_bits(data, base)
    local result = {}
    local i = 1
    local size = base:len()
    
    for ch in base:gmatch(".") do
        if bit.test(data, size-i) then
            result[i] = ch
        else
            result[i] = " "
        end
        i = i + 1
    end
    
    return table.concat(result)
end


local function mouse_onregion(x1, y1, x2, y2)
    -- Reads external mouse coordinates
    local mouse_x = User_input.mouse_x
    local mouse_y = User_input.mouse_y
    
    -- From top-left to bottom-right
    if x2 < x1 then
        x1, x2 = x2, x1
    end
    if y2 < y1 then
        y1, y2 = y2, y1
    end
    
    if mouse_x >= x1 and mouse_x <= x2 and  mouse_y >= y1 and mouse_y <= y2 then
        return true
    else
        return false
    end
end


-- Those 'Keys functions' register presses and releases. Pretty much a copy from the script of player Fat Rat Knight (FRK)
-- http://tasvideos.org/userfiles/info/5481697172299767
Keys = {}
Keys.KeyPress=   {}
Keys.KeyRelease= {}

function Keys.registerkeypress(key,fn)
-- key - string. Which key do you wish to bind?
-- fn  - function. To execute on key press. False or nil removes it.
-- Return value: The old function previously assigned to the key.

    local OldFn= Keys.KeyPress[key]
    Keys.KeyPress[key]= fn
    --Keys.KeyPress[key]= Keys.KeyPress[key] or {}
    --table.insert(Keys.KeyPress[key], fn)
    input.keyhook(key,type(fn or Keys.KeyRelease[key]) == "function")
    return OldFn
end


function Keys.registerkeyrelease(key,fn)
-- key - string. Which key do you wish to bind?
-- fn  - function. To execute on key release. False or nil removes it.
-- Return value: The old function previously assigned to the key.

    local OldFn= Keys.KeyRelease[key]
    Keys.KeyRelease[key]= fn
    input.keyhook(key,type(fn or Keys.KeyPress[key]) == "function")
    return OldFn
end


function Keys.altkeyhook(s,t)
-- s,t - input expected is identical to on_keyhook input. Also passed along.
-- You may set by this line: on_keyhook = Keys.altkeyhook
-- Only handles keyboard input. If you need to handle other inputs, you may
-- need to have your own on_keyhook function to handle that, but you can still
-- call this when generic keyboard handling is desired.

    if     Keys.KeyPress[s]   and (t[INPUT_RAW_VALUE] == 1) then
        Keys.KeyPress[s](s,t)
    elseif Keys.KeyRelease[s] and (t[INPUT_RAW_VALUE] == 0) then
        Keys.KeyRelease[s](s,t)
    end
end


local function get_last_frame(advance)
    local cf = movie.currentframe() - (advance and 0 or 1)
    if cf == -1 then print"NEGATIVE FRAME!!!!!!!!!!!" cf = 0 end
    
    return cf
end


-- Stores the raw input in a table for later use. Should be called at the start of paint and timer callbacks
local function read_raw_input()
    for key, inner in pairs(input.raw()) do
        User_input[key] = inner[INPUT_RAW_VALUE]
    end
    User_input.mouse_x = math.floor(User_input.mouse_x)
    User_input.mouse_y = math.floor(User_input.mouse_y)
end


-- Extensions to the "gui" function, to handle fonts and opacity
draw.Font_name = false


function draw.opacity(text, bg)
    draw.Text_local_opacity = text or draw.Text_local_opacity
    draw.Bg_local_opacity = bg or draw.Bg_local_opacity
    
    return draw.Text_local_opacity, draw.Bg_local_opacity
end


function draw.font_width(font)
    font = font or Font
    return CUSTOM_FONTS[font] and CUSTOM_FONTS[font].width or LSNES.FONT_WIDTH
end


function draw.font_height(font)
    font = font or Font
    return CUSTOM_FONTS[font] and CUSTOM_FONTS[font].height or LSNES.FONT_HEIGHT
end


function LSNES.get_emu_status()
    LSNES.Runmode = gui.get_runmode()
    LSNES.Lsnes_speed = settings.get_speed()
    
end

function LSNES.get_rom_info()
    local ROM_info = {}
    
    ROM_info.is_loaded = movie.rom_loaded()
    if ROM_info.is_loaded then
        -- ROM info
        local movie_info = movie.get_rom_info()
        ROM_info.slots = #movie_info
        ROM_info.hint = movie_info[1].hint
        ROM_info.hash = movie_info[1].sha256
        
        -- Game info
        local game_info = movie.get_game_info()
        ROM_info.game_type = game_info.gametype
        ROM_info.game_fps = game_info.fps
    else
        -- ROM info
        ROM_info.slots = 0
        ROM_info.hint = false
        ROM_info.hash = false
        
        -- Game info
        ROM_info.game_type = false
        ROM_info.game_fps = false
    end
    
    return ROM_info
end

function LSNES.get_controller_info()
    local controller_info = {}
    
    controller_info.ports = {}
    controller_info.num_ports = 0
    for port = 0, math.huge do
        controller_info.ports[port] = input.port_type(port)
        if not controller_info.ports[port] then break end
        controller_info.num_ports = controller_info.num_ports + 1
    end
    
    for lcid = 0, math.huge do
        local port, controller = input.lcid_to_pcid2(lcid)
        local info = (port and controller) and input.controller_info(port, controller) or nil
        
        if info then
            controller_info[lcid] = {port = port, controller = controller}
            controller_info[lcid].type = info.type
            controller_info[lcid].class = info.class
            controller_info[lcid].classnum = info.classnum
            controller_info[lcid].button_count = info.button_count
            
        elseif lcid > 0 then
            break
        end
    end
    
    --[[
    for a,b in pairs(controller_info) do
        print(a,b)
    end
    --]]
    return controller_info
end

function LSNES.get_movie_info()
    local info = {}
    local decrement = LSNES.frame_boundary and 0 or 1
    
    info.Readonly = movie.readonly()
    info.Framecount = movie.framecount()
    info.Subframecount = movie.get_size()
    info.Lagcount = movie.lagcount()
    info.Rerecords = movie.rerecords()
    
    -- Last frame info
    info.Lastframe_emulated = movie.currentframe() - decrement
    if info.Lastframe_emulated < 0 then info.Lastframe_emulated = 0 end
    info.Starting_subframe_last_frame = info.Lastframe_emulated <= info.Framecount and
        movie.current_first_subframe() + 1 - decrement*movie.frame_subframes(info.Lastframe_emulated) or
        info.Subframecount + (info.Lastframe_emulated - info.Framecount)
    info.Size_last_frame = info.Lastframe_emulated >= 0 and movie.frame_subframes(info.Lastframe_emulated) or 1
    info.Final_subframe_last_frame = info.Starting_subframe_last_frame + info.Size_last_frame - 1
    
    -- Next frame info (only relevant in readonly mode)
    info.Nextframe = info.Lastframe_emulated + 1
    info.Starting_subframe_next_frame = info.Nextframe <= info.Framecount and movie.find_frame(info.Nextframe) + 1
        or movie.find_frame(info.Framecount) + (info.Nextframe - info.Framecount) + 1
    info.Size_next_frame = movie.frame_subframes(info.Nextframe)
    info.Final_subframe_next_frame = info.Starting_subframe_next_frame + info.Size_next_frame - 1
    
    return info
end

function LSNES.get_screen_info()
    LSNES.left_gap = LSNES.left_gap or OPTIONS.left_gap  -- Lateral gaps
    LSNES.right_gap = LSNES.right_gap or OPTIONS.right_gap
    LSNES.top_gap = LSNES.top_gap or OPTIONS.top_gap
    LSNES.bottom_gap = LSNES.bottom_gap or OPTIONS.bottom_gap
    
    LSNES.Padding_left = tonumber(settings.get("left-border"))  -- Advanced configuration: padding dimensions
    LSNES.Padding_right = tonumber(settings.get("right-border"))
    LSNES.Padding_top = tonumber(settings.get("top-border"))
    LSNES.Padding_bottom = tonumber(settings.get("bottom-border"))
    
    LSNES.Border_left = math.max(LSNES.Padding_left, LSNES.left_gap)  -- Borders' dimensions
    LSNES.Border_right = math.max(LSNES.Padding_right, LSNES.right_gap)
    LSNES.Border_top = math.max(LSNES.Padding_top, LSNES.top_gap)
    LSNES.Border_bottom = math.max(LSNES.Padding_bottom, LSNES.bottom_gap)
    
    LSNES.Buffer_width, LSNES.Buffer_height = gui.resolution()  -- Game area
    if LSNES.Video_callback then  -- The video callback messes with the resolution
        LSNES.Buffer_middle_x, LSNES.Buffer_middle_y = LSNES.Buffer_width, LSNES.Buffer_height
        LSNES.Buffer_width = 2*LSNES.Buffer_width
        LSNES.Buffer_height = 2*LSNES.Buffer_height
    else
        LSNES.Buffer_middle_x, LSNES.Buffer_middle_y = LSNES.Buffer_width//2, LSNES.Buffer_height//2  -- Lua 5.3
    end
    
	LSNES.Screen_width = LSNES.Buffer_width + LSNES.Border_left + LSNES.Border_right  -- Emulator area
	LSNES.Screen_height = LSNES.Buffer_height + LSNES.Border_top + LSNES.Border_bottom
    LSNES.AR_x = 2
    LSNES.AR_y = 2
end


-- Changes transparency of a color: result is opaque original * transparency level (0.0 to 1.0). Acts like gui.opacity() in Snes9x.
function draw.change_transparency(color, transparency)
    -- Sane transparency
    if transparency >= 1 then return color end  -- no transparency
    if transparency <= 0 then return COLOUR.transparency end    -- total transparency
    
    -- Sane colour
    if color == -1 then return -1 end
    
    local a = color>>24  -- Lua 5.3
    local rgb = color - (a<<24)
    local new_a = 0x100 - math.ceil((0x100 - a)*transparency)
    return (new_a<<24) + rgb
end


-- Takes a position and dimensions of a rectangle and returns a new position if this rectangle has points outside the screen
local function put_on_screen(x, y, width, height)
    local x_screen, y_screen
    width = width or 0
    height = height or 0
    
    if x < - Border_left then
        x_screen = - Border_left
    elseif x > Buffer_width + Border_right - width then
        x_screen = Buffer_width + Border_right - width
    else
        x_screen = x
    end
    
    if y < - Border_top then
        y_screen = - Border_top
    elseif y > Buffer_height + Border_bottom - height then
        y_screen = Buffer_height + Border_bottom - height
    else
        y_screen = y
    end
    
    return x_screen, y_screen
end


-- returns the (x, y) position to start the text and its length:
-- number, number, number text_position(x, y, text, font_width, font_height[[[[, always_on_client], always_on_game], ref_x], ref_y])
-- x, y: the coordinates that the refereed point of the text must have
-- text: a string, don't make it bigger than the buffer area width and don't include escape characters
-- font_width, font_height: the sizes of the font
-- always_on_client, always_on_game: boolean
-- ref_x and ref_y: refer to the relative point of the text that must occupy the origin (x,y), from 0% to 100%
--                  for instance, if you want to display the middle of the text in (x, y), then use 0.5, 0.5
function draw.text_position(x, y, text, font_width, font_height, always_on_client, always_on_game, ref_x, ref_y)
    -- Reads external variables
    local border_left     = LSNES.Border_left
    local border_right    = LSNES.Border_right
    local border_top      = LSNES.Border_top
    local border_bottom   = LSNES.Border_bottom
    local buffer_width    = LSNES.Buffer_width
    local buffer_height   = LSNES.Buffer_height
    
    -- text processing
    local text_length = text and string.len(text)*font_width or font_width  -- considering another objects, like bitmaps
    
    -- actual position, relative to game area origin
    x = ((not ref_x or ref_x == 0) and x) or x - math.floor(text_length*ref_x)
    y = ((not ref_y or ref_y == 0) and y) or y - math.floor(font_height*ref_y)
    
    -- adjustment needed if text is supposed to be on screen area
    local x_end = x + text_length
    local y_end = y + font_height
    
    if always_on_game then
        if x < 0 then x = 0 end
        if y < 0 then y = 0 end
        
        if x_end > buffer_width  then x = buffer_width  - text_length end
        if y_end > buffer_height then y = buffer_height - font_height end
        
    elseif always_on_client then
        if x < -border_left then x = -border_left end
        if y < -border_top  then y = -border_top  end
        
        if x_end > buffer_width  + border_right  then x = buffer_width  + border_right  - text_length end
        if y_end > buffer_height + border_bottom then y = buffer_height + border_bottom - font_height end
    end
    
    return x, y, text_length
end


-- Complex function for drawing, that uses text_position
function draw.text(x, y, text, text_color, bg_color, halo_color, always_on_client, always_on_game, ref_x, ref_y)
    -- Read external variables
    local font_name = draw.Font_name or false
    local font_width  = draw.font_width()
    local font_height = draw.font_height()
    text_color = text_color or COLOUR.text
    bg_color = bg_color or -1--COLOUR.background -- EDIT
    halo_color = halo_color or COLOUR.halo
    
    -- Apply transparency
    text_color = draw.change_transparency(text_color, draw.Text_global_opacity * draw.Text_local_opacity)
    bg_color = draw.change_transparency(bg_color, draw.Bg_global_opacity * draw.Bg_local_opacity)
    halo_color = draw.change_transparency(halo_color, draw.Text_global_opacity * draw.Text_local_opacity)
    
    -- Calculate actual coordinates and plot text
    local x_pos, y_pos, length = draw.text_position(x, y, text, font_width, font_height,
                                    always_on_client, always_on_game, ref_x, ref_y)
    ;
    draw.font[font_name](x_pos, y_pos, text, text_color, bg_color, halo_color)
    
    return x_pos + length, y_pos + font_height, length
end


function draw.alert_text(x, y, text, text_color, bg_color, always_on_game, ref_x, ref_y)
    -- Reads external variables
    local font_width  = LSNES.FONT_WIDTH
    local font_height = LSNES.FONT_HEIGHT
    
    local x_pos, y_pos, text_length = draw.text_position(x, y, text, font_width, font_height, false, always_on_game, ref_x, ref_y)
    
    text_color = draw.change_transparency(text_color, draw.Text_global_opacity * draw.Text_local_opacity)
    bg_color = draw.change_transparency(bg_color, draw.Bg_global_opacity * draw.Bg_local_opacity)
    gui.text(x_pos, y_pos, text, text_color, bg_color)
    
    return x_pos + text_length, y_pos + font_height, text_length
end


local function draw_over_text(x, y, value, base, color_base, color_value, color_bg, always_on_client, always_on_game, ref_x, ref_y)
    value = decode_bits(value, base)
    local x_end, y_end, length = draw.text(x, y, base, color_base, color_bg, nil, always_on_client, always_on_game, ref_x, ref_y)
    draw.font[Font](x_end - length, y_end - draw.font_height(), value, color_value or COLOUR.text)
    
    return x_end, y_end, length
end


-- Returns frames-time conversion
local function frame_time(frame)
    if not LSNES.rom or not LSNES.rom.is_loaded then return "no time" end
    
    local total_seconds = frame / LSNES.rom.game_fps
    local hours, minutes, seconds = bit.multidiv(total_seconds, 3600, 60)
    seconds = math.floor(seconds)
    
    local miliseconds = 1000* (total_seconds%1)
    if hours == 0 then hours = "" else hours = string.format("%d:", hours) end
    local str = string.format("%s%.2d:%.2d.%03.0f", hours, minutes, seconds, miliseconds)
    return str
end


-- draw a pixel given (x,y) with SNES' pixel sizes
function draw.pixel(x, y, color, shadow)
    if shadow and shadow ~= COLOUR.transparent then
        gui.rectangle(x*LSNES.AR_x - 1, y*LSNES.AR_y - 1, 2*LSNES.AR_x, 2*LSNES.AR_y, 1, shadow, color)
    else
        gui.solidrectangle(x*LSNES.AR_x, y*LSNES.AR_y, LSNES.AR_x, LSNES.AR_y, color)
    end
end

-- draws a line given (x,y) and (x',y') with given scale and SNES' pixel thickness
function draw.line(x1, y1, x2, y2, color)
    x1, y1, x2, y2 = x1*LSNES.AR_x, y1*LSNES.AR_y, x2*LSNES.AR_x, y2*LSNES.AR_y
    if x1 == x2 then
        gui.line(x1, y1, x2, y2 + 1, color)
        gui.line(x1 + 1, y1, x2 + 1, y2 + 1, color)
    elseif y1 == y2 then
        gui.line(x1, y1, x2 + 1, y2, color)
        gui.line(x1, y1 + 1, x2 + 1, y2 + 1, color)
    else
        gui.line(x1, y1, x2 + 1, y2 + 1, color)
    end
end


-- draws a box given (x,y) and (x',y') with SNES' pixel sizes
function draw.box(x1, y1, x2, y2, ...)
    -- Draw from top-left to bottom-right
    if x2 < x1 then
        x1, x2 = x2, x1
    end
    if y2 < y1 then
        y1, y2 = y2, y1
    end
    
    gui.rectangle(x1*LSNES.AR_x, y1*LSNES.AR_y, (x2 - x1 + 1)*LSNES.AR_x, (y2 - y1 + 1)*LSNES.AR_x, LSNES.AR_x, ...)
end


-- draws a rectangle given (x,y) and dimensions, with SNES' pixel sizes
function draw.rectangle(x, y, w, h, ...)
    gui.rectangle(x*LSNES.AR_x, y*LSNES.AR_y, w*LSNES.AR_x, h*LSNES.AR_y, LSNES.AR_x, ...)
end


-- Background opacity functions
function draw.increase_opacity()
    if draw.Text_global_opacity <= 0.9 then draw.Text_global_opacity = draw.Text_global_opacity + 0.1
    else
        if draw.Bg_global_opacity <= 0.9 then draw.Bg_global_opacity = draw.Bg_global_opacity + 0.1 end
    end
end


function draw.decrease_opacity()
    if  draw.Bg_global_opacity >= 0.1 then draw.Bg_global_opacity = draw.Bg_global_opacity - 0.1
    else
        if draw.Text_global_opacity >= 0.1 then draw.Text_global_opacity = draw.Text_global_opacity - 0.1 end
    end
end


-- Creates lateral gaps
local function create_gaps()
    gui.left_gap(LSNES.left_gap)  -- for input display
    gui.right_gap(LSNES.right_gap)
    gui.top_gap(LSNES.top_gap)
    gui.bottom_gap(LSNES.bottom_gap)
end


local function show_movie_info()
    -- Font
    draw.Font_name = false
    draw.opacity(1.0, 1.0)
    
    local y_text = - LSNES.Border_top
    local x_text = 0
    local width = draw.font_width()
    
    local rec_color = LSNES.movie.Readonly and COLOUR.text or COLOUR.warning
    local recording_bg = LSNES.movie.Readonly and COLOUR.background or COLOUR.warning_bg 
    
    -- Read-only or read-write?
    local movie_type = LSNES.movie.Readonly and "Movie " or "REC "
    x_text = draw.alert_text(x_text, y_text, movie_type, rec_color, recording_bg)
    
    -- Frame count
    local movie_info
    if LSNES.movie.Readonly then
        movie_info = string.format("%d(%d)/%d", LSNES.movie.Lastframe_emulated, LSNES.movie.Starting_subframe_last_frame, LSNES.movie.Framecount) -- edit
    else
        movie_info = string.format("%d(%d)", LSNES.movie.Lastframe_emulated, LSNES.movie.Starting_subframe_last_frame) -- edit
    end
    x_text = draw.text(x_text, y_text, movie_info)  -- Shows the latest frame emulated, not the frame being run now
    
    -- Rerecord and lag count
    x_text = draw.text(x_text, y_text, string.format("|%d ", LSNES.movie.Rerecords), COLOUR.weak)
    x_text = draw.text(x_text, y_text, LSNES.movie.Lagcount, COLOUR.warning)
    
    -- Run mode and emulator speed
    local lsnesmode_info
    if LSNES.Lsnes_speed == "turbo" then
        lsnesmode_info = fmt(" %s(%s)", LSNES.Runmode, LSNES.Lsnes_speed)
    elseif LSNES.Lsnes_speed ~= 1 then
        lsnesmode_info = fmt(" %s(%.0f%%)", LSNES.Runmode, 100*LSNES.Lsnes_speed)
    else
        lsnesmode_info = fmt(" %s", LSNES.Runmode)
    end
    
    x_text = draw.text(x_text, y_text, lsnesmode_info, COLOUR.weak)
    
    local str = frame_time(LSNES.movie.Lastframe_emulated)    -- Shows the latest frame emulated, not the frame being run now
    draw.alert_text(LSNES.Buffer_width, LSNES.Buffer_height, str, COLOUR.text, recording_bg, false, 1.0, 1.0)
    
    if LSNES.Is_lagged then
        gui.textHV(LSNES.Buffer_middle_x - 3*LSNES.FONT_WIDTH, 2*LSNES.FONT_HEIGHT, "Lag", COLOUR.warning, draw.change_transparency(COLOUR.warning_bg, draw.Bg_global_opacity))
    end
    
end



--#############################################################################
-- CUSTOM CALLBACKS --


local function is_new_rom()
    Previous.rom = LSNES.rom_hash
    
    if not movie.rom_loaded() then
        LSNES.rom_hash = "NULL ROM"
    else LSNES.rom_hash = movie.get_rom_info()[1].sha256
    end
    
    return Previous.rom == LSNES.rom
end


local function on_new_rom()
    if not is_new_rom() then return end
    
    LSNES.get_rom_info()
    print"NEW ROM FAGGOTS"
end


--#############################################################################
-- MAIN --


LSNES.subframe_update = false
gui.subframe_update(LSNES.subframe_update)  -- TODO: this should be true when paused or in heavy slowdown -- EDIT


-- KEYHOOK callback
on_keyhook = Keys.altkeyhook

-- Key presses:
Keys.registerkeypress(OPTIONS.hotkey_increase_opacity, function() draw.increase_opacity() end)
Keys.registerkeypress(OPTIONS.hotkey_decrease_opacity, function() draw.decrease_opacity() end)
Keys.registerkeypress("period", function()
    LSNES.subframe_update = not LSNES.subframe_update
    gui.subframe_update(LSNES.subframe_update)
    gui.repaint()
end)


function on_frame_emulated()
    LSNES.frame_boundary = true -- TEST
    LSNES.Is_lagged = memory.get_lag_flag()
end

function on_frame()
    LSNES.frame_boundary = false--true -- TEST
    if not movie.rom_loaded() then  -- only useful with null ROM
        gui.repaint()
    end
end


function on_snoop(port, controller, button, value)
    --if port == 0 then LSNES.frame_boundary = false end
end

---[[test
function subframe_to_frame(subf)
    local total_frames = LSNES.movie.Framecount or movie.count_frames(nil)
    local total_subframes = LSNES.movie.Subframecount or movie.get_size(nil)
    
    if total_subframes < subf then return total_frames + (subf - total_subframes) --end
    else return movie.subframe_to_frame(subf - 1) end
end
--]]

function LSNES.display_input()
    -- Font
    draw.Font_name = false
    draw.opacity(1.0, 1.0)
    local width  = draw.font_width()
    local height = draw.font_height()
    local before = LSNES.Buffer_height//(2*height)
    local after = before
    local y_text = 0
    
    local subframe, current_subframe, frame, input
    current_subframe = LSNES.movie.Starting_subframe_next_frame - 1
    subframe = current_subframe - before + 1
    frame = subframe >= 1 and subframe_to_frame(subframe) or 0 -- TEST
    
    local color = 0x00ff00
    for id = subframe, current_subframe do
        if id >= 1 then
            input = (id > LSNES.movie.Subframecount) and "NULLINPUT" or movie.get_frame(id - 1):serialize()
            draw.text(-LSNES.Border_left, y_text, fmt("%d %d %s", frame, id, input), color)
        end
        
        if frame + 1 > LSNES.movie.Framecount or movie.find_frame(frame + 1) == id then -- next subframe is a new frame?
            frame = frame + 1
            color = 0xffffff
        else color = 0xff -- TEST
        end
        y_text = y_text + height
        
    end
    
    draw.line(-LSNES.Border_left, 0, 0, 0, 0xff)
    draw.line(-LSNES.Border_left, LSNES.Buffer_height//4, 0, LSNES.Buffer_height//4, 0xff0000)
    draw.line(-LSNES.Border_left, LSNES.Buffer_height//2, 0, LSNES.Buffer_height//2, 0xff)
    
    subframe = current_subframe + 1
    frame = subframe_to_frame(subframe)
    
    for id = subframe, math.min(subframe + after - 1, LSNES.movie.Subframecount) do
        input = movie.get_frame(id - 1):serialize()
        draw.text(-LSNES.Border_left, y_text, fmt("%d %d %s", frame, id, input))
        
        if movie.find_frame(frame + 1) == id then -- next subframe is a new frame?
            frame = frame + 1
        end
        y_text = y_text + height
    end
    
end
--]]


-- Function that is called from the paint and video callbacks
-- from_paint is true if this was called from on_paint/ false if from on_video
local function main_paint_function(authentic_paint, from_paint)
    -- Initial values, don't make drawings here
    read_raw_input()
    LSNES.get_emu_status()
    
    if not LSNES.rom then LSNES.rom = LSNES.get_rom_info() ; print"> Read rom info" end
    if not LSNES.controller then LSNES.controller = LSNES.get_controller_info() ; print"> Read controller info" end
    LSNES.movie = LSNES.get_movie_info()
    LSNES.get_screen_info()
    create_gaps()
    
    --draw.Font_name = "snes9xtext"
    draw.text(300, 0, LSNES.subframe_update and "subframe update" or "NOT subframe up", 0xff8000)
    --draw.text(0, 48, tostring(LSNES.rom.hint))
    --draw.text(0, 64, tostringx(LSNES.controller.ports))
    --draw.text(0, 80, tostring(LSNES.frame_boundary))
    gui.text( -120, -16, movie.pollcounter(0, 0, 0), "yellow", "black") -- EDIT
    
    LSNES.display_input()
    
    show_movie_info(OPTIONS.display_movie_info)
end


local draw = draw
function on_paint(authentic_paint)
    main_paint_function(authentic_paint, true)
    
    --[=[
    local j
    gui.text(0, 0, "TESTING")
    for i = 500000, 500000+10000 do
        --movie.subframe_to_frame(500000)
        --movie.find_frame(500000)
        --movie.get_size(i)
        j = movie.current_first_subframe()
    end
    gui.text(0, 16, j)
    --]=]
end


function on_video()
    LSNES.Video_callback = true
    main_paint_function(false, false)
    LSNES.Video_callback = false
end


-- Loading a state
function on_pre_load()
    LSNES.frame_boundary = false
    LSNES.Is_lagged = false
    
end


-- Functions called on specific events
function on_readwrite()
    --LSNES.movie = false
    
    gui.repaint()
end


-- Rewind functions
function on_rewind()
    print"ON REWIND"
    --LSNES.movie = false
    
    gui.repaint()
end


function on_movie_lost(kind)
    print("ON MOVIE LOST", kind)
    
    if kind == "reload" then  -- just before reloading the ROM in rec mode or closing/loading new ROM
        LSNES.rom = false
        LSNES.controller = false
        
    elseif kind == "load" then -- this is called just before loading / use on_post_load when needed
        LSNES.controller = false
        
    end
    
end


gui.repaint()
