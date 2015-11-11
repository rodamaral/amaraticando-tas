--#############################################################################
-- CONFIG:

local OPTIONS = {
    -- Hotkeys  (look at the manual to see all the valid keynames)
    -- make sure that the hotkeys below don't conflict with previous bindings
    hotkey_increase_opacity = "equals",  -- to increase the opacity of the text: the '='/'+' key 
    hotkey_decrease_opacity = "minus",   -- to decrease the opacity of the text: the '_'/'-' key
    
    -- Script settings
    use_custom_fonts = true,
    use_movie_editor_tool = true,
    
    -- Lateral gaps (initial values)
    left_gap = 40*8 + 2,
    right_gap = 32,
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
    button_text = 0x00300030,
}

-- TODO: make them global later, to export the module
local LSNES = {}
local ROM_INFO = {}
local CONTROLLER = {}
local MOVIE = {}
local draw = {}

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
local SCRIPT_DEBUG_INFO = false


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
local Movie_editor_renderctx


-- unsigned to signed (based in <bits> bits)
local function signed(num, bits)
    local maxval = 1<<(bits - 1)
    if num < maxval then return num else return num - 2*maxval end
end


-- Transform the binary representation of base into a string
-- For instance, if each bit of a number represents a char of base, then this function verifies what chars are on
local function decode_bits(data, base)
    local i = 1
    local size = base:len()
    local direct_concatenation = size <= 45  -- Performance: I found out that the .. operator is faster for 45 operations or less
    local result
    
    if direct_concatenation then
        result = ""
        for ch in base:gmatch(".") do
            if bit.test(data, size - i) then
                result = result .. ch
            else
                result = result .. " "
            end
            i = i + 1
        end
    else
        result = {}
        for ch in base:gmatch(".") do
            if bit.test(data, size-i) then
                result[i] = ch
            else
                result[i] = " "
            end
            i = i + 1
        end
        result = table.concat(result)
    end
    
    return result
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
    font = font or Font  -- TODO: change Font to draw.Font_name ?
    return CUSTOM_FONTS[font] and CUSTOM_FONTS[font].width or LSNES.FONT_WIDTH
end


function draw.font_height(font)
    font = font or Font
    return CUSTOM_FONTS[font] and CUSTOM_FONTS[font].height or LSNES.FONT_HEIGHT
end


function LSNES.get_rom_info()
    ROM_INFO.is_loaded = movie.rom_loaded()
    if ROM_INFO.is_loaded then
        -- ROM info
        local movie_info = movie.get_rom_info()
        ROM_INFO.slots = #movie_info
        ROM_INFO.hint = movie_info[1].hint
        ROM_INFO.hash = movie_info[1].sha256
        
        -- Game info
        local game_info = movie.get_game_info()
        ROM_INFO.game_type = game_info.gametype
        ROM_INFO.game_fps = game_info.fps
    else
        -- ROM info
        ROM_INFO.slots = 0
        ROM_INFO.hint = false
        ROM_INFO.hash = false
        
        -- Game info
        ROM_INFO.game_type = false
        ROM_INFO.game_fps = false
    end
    
    ROM_INFO.info_loaded = true
    print"> Read rom info"
end


function LSNES.get_controller_info()
    local info = CONTROLLER
    
    info.ports = {}
    info.num_ports = 0
    info.total_buttons = 0
    info.total_controllers = 0
    info.button_array = {} -- TEST
    local complete_input_sequence = "" -- TEST
    
    for port = 0, 2 do  -- SNES
        info.ports[port] = input.port_type(port)
        if not info.ports[port] then break end
        info.num_ports = info.num_ports + 1
    end
    
    for lcid = 1, 8 do
        local port, controller = input.lcid_to_pcid2(lcid)
        local ci = (port and controller) and input.controller_info(port, controller) or nil
        local symbols = {}
        
        if ci then
            info[lcid] = {port = port, controller = controller}
            info[lcid].type = ci.type
            info[lcid].class = ci.class
            info[lcid].classnum = ci.classnum
            info[lcid].button_count = ci.button_count
            info[lcid].symbols = {}
            info[lcid].symbol_sequence = ""  -- TEST
            for button, inner in ipairs(ci.buttons) do
                info[lcid].symbols[button] = inner.symbol
                info[lcid].symbol_sequence = info[lcid].symbol_sequence .. (inner.symbol or " ")  -- TODO: include axes, that don't have a symbol
                info.button_array[#info.button_array + 1] = {port = port, controller = controller, button = button} -- TEST
                --print(button, inner.symbol)
            end
            
            -- Some
            info.total_buttons = info.total_buttons + ci.button_count
            info.total_controllers = info.total_controllers + 1
            complete_input_sequence = complete_input_sequence .. info[lcid].symbol_sequence -- TEST
            
        elseif lcid > 0 then
            break
        end
    end
    info.complete_input_sequence = complete_input_sequence
    
    -- debug
    if SCRIPT_DEBUG_INFO then
        for lcid = 1, 8 do
            local tb = info[lcid]
                print(lcid, ":")
                if type(tb) == "table" then
                    for c,d in pairs(tb) do
                        print("", c, d)
                    end
                else
                    print("", tb)
                end
        end
    end
    --------
    
    info.info_loaded = true
    print"> Read controller info"
end


-- Get initial frame boudary state: -- EDIT
LSNES.frame_boundary = movie.pollcounter(0, 0, 0) ~= 0 and "middle" or "start"  -- test / hack
-- cannot be "end" in a repaint, only in authentic paints. When script starts, it should never be authentic
function LSNES.get_movie_info()
    LSNES.pollcounter = movie.pollcounter(0, 0, 0)
    
    -- DEBUG
    if LSNES.frame_boundary ~= "middle" and LSNES.Runmode == "pause_break" then error"Frame boundary: middle case not accounted!" end
    
    MOVIE.readonly = movie.readonly()
    MOVIE.framecount = movie.framecount()
    MOVIE.subframe_count = movie.get_size()
    MOVIE.lagcount = movie.lagcount()
    MOVIE.rerecords = movie.rerecords()
    
    -- CURRENT
    MOVIE.current_frame = movie.currentframe() + ((LSNES.frame_boundary == "end") and 1 or 0)
    if MOVIE.current_frame == 0 then MOVIE.current_frame = 1 end  -- after the rewind, the currentframe isn't updated to 1
    
    MOVIE.current_poll = (LSNES.frame_boundary ~= "middle") and 1 or LSNES.pollcounter + 1
    -- TODO: this should be incremented after all the buttons have been polled
    
    MOVIE.size_past_frame = LSNES.size_frame(MOVIE.current_frame - 1)  -- somehow, the order of calling size_Frame matters!
    MOVIE.size_current_frame = LSNES.size_frame(MOVIE.current_frame)  -- how many subframes of current frames are stored in the movie
    MOVIE.last_frame_started_movie = MOVIE.current_frame - (LSNES.frame_boundary == "middle" and 0 or 1) --test
    if MOVIE.last_frame_started_movie <= MOVIE.framecount then
        MOVIE.current_starting_subframe = movie.current_first_subframe() + 1
        if LSNES.frame_boundary == "end" then
            MOVIE.current_starting_subframe = MOVIE.current_starting_subframe + MOVIE.size_past_frame  -- movie.current_first_subframe() isn't updated
        end                                                                                        -- until the frame boundary is "start"
    else
        MOVIE.current_starting_subframe = MOVIE.subframe_count + (MOVIE.current_frame - MOVIE.framecount)
    end
    
    if MOVIE.size_current_frame == 0 then MOVIE.size_current_frame = 1 end  -- fix it
    MOVIE.current_internal_subframe = (MOVIE.current_poll > MOVIE.size_current_frame) and MOVIE.size_current_frame or MOVIE.current_poll
    MOVIE.current_subframe = MOVIE.current_starting_subframe + MOVIE.current_internal_subframe - 1
    -- for frames with subframes, but not written in the movie
    
    -- PAST SUBFRAME
    MOVIE.frame_of_past_subframe = MOVIE.current_frame - (MOVIE.current_internal_subframe == 1 and 1 or 0)
    
    -- TEST INPUT
    MOVIE.last_input_computed = LSNES.get_input(MOVIE.subframe_count)
end


function LSNES.debug_movie()
    local x, y = 150, 100
    
    draw.text(x, y, "subframe_update: " .. tostringx(LSNES.subframe_update))
    y = y + 16
    draw.text(x, y, string.format("currentframe: %d, framecount: %d, count_frames: %d",  movie.currentframe(), movie.framecount(),  movie.count_frames()))
    y = y + 16
    draw.text(x, y, string.format("get_size: %d",  movie.get_size()))
    y = y + 16
    draw.text(x, y, "current_first_subframe: " .. movie.current_first_subframe())
    y = y + 16
    draw.text(x, y, "pollcounter: " .. movie.pollcounter(0, 0, 0))
    y = y + 16
    draw.text(x, y, LSNES.frame_boundary)
    y = y + 16
    
    for a, b in pairs(MOVIE) do
        gui.text(x, y, string.format("%s %s", a, tostring(b)), 'yellow', 0x80000000)
        y = y + 16
    end
    --[[
    x = 200
    y = 16
    local colour = {[1] = 0xffff00, [2] = 0x00ff00}
    for controller = 0, 3 do
        for control = 0, 15 do
            if y >= 432 then
                y = 16
                x = x + 48
            end
            draw.text(x, y, control .. " " .. movie.pollcounter(0, controller, control), 0xff0000, 0x20000000)
            y = y + 16
        end
    end
    for port = 1, 2 do
        for controller = 0, 3 do
            for control = 0, 15 do
                if y >= 432 then
                    y = 16
                    x = x + 48
                end
                draw.text(x, y, control .. " " .. movie.pollcounter(port, controller, control), colour[(2*port + controller)%2 + 1], 0x20000000)
                y = y + 16
            end
        end
    end
    --]]
end


function LSNES.get_screen_info()
    LSNES.left_gap = LSNES.left_gap or OPTIONS.left_gap  -- Lateral gaps TODO: why did I write this?
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


-- displays a button everytime in (x,y)
-- object can be a text or a dbitmap
-- if user clicks onto it, fn is executed once
draw.buttons_table = {}
function draw.button(x, y, object, fn, extra_options)
    local always_on_client, always_on_game, ref_x, ref_y, button_pressed
    if extra_options then
        always_on_client, always_on_game, ref_x, ref_y, button_pressed = extra_options.always_on_client, extra_options.always_on_game,
                                                                extra_options.ref_x, extra_options.ref_y, extra_options.button_pressed
    end
    
    local width, height
    local object_type = type(object)
    
    if object_type == "string" then
        width, height = draw.font_width(), draw.font_height()
        x, y, width = draw.text_position(x, y, object, width, height, always_on_client, always_on_game, ref_x, ref_y)
    elseif object_type == "userdata" then  -- lsnes specific
        width, height = object:size()
        x, y = draw.text_position(x, y, nil, width, height, always_on_client, always_on_game, ref_x, ref_y)
    elseif object_type == "boolean" then
        width, height = LSNES_FONT_WIDTH, LSNES_FONT_HEIGHT
        x, y = draw.text_position(x, y, nil, width, height, always_on_client, always_on_game, ref_x, ref_y)
    else error"Type of buttton not supported yet"
    end
    
    -- draw the button
    if button_pressed then
        gui.box(x, y, width, height, 1, 0x808080, 0xffffff, 0xe0e0e0) -- unlisted colour
    else
        gui.box(x, y, width, height, 1)
    end
    
    if object_type == "string" then
        draw.text(x, y, object, COLOUR.button_text, -1, -1)  -- EDIT
    elseif object_type == "userdata" then
        object:draw(x, y)
    elseif object_type == "boolean" then
        gui.solidrectangle(x +1, y + 1, width - 2, height - 2, 0x00ff00)  -- unlisted colour
    end
    
    -- updates the table of buttons
    table.insert(draw.buttons_table, {x = x, y = y, width = width, height = height, object = object, action = fn})
end


-- Returns frames-time conversion
local function frame_time(frame)
    if not ROM_INFO.info_loaded or not ROM_INFO.is_loaded then return "no time" end
    
    local total_seconds = frame / ROM_INFO.game_fps
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
    gui.left_gap(LSNES.left_gap)  -- for input display -- TEST
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
    
    local rec_color = MOVIE.readonly and COLOUR.text or COLOUR.warning
    local recording_bg = MOVIE.readonly and COLOUR.background or COLOUR.warning_bg 
    
    -- Read-only or read-write?
    local movie_type = MOVIE.readonly and "Movie " or "REC "
    x_text = draw.alert_text(x_text, y_text, movie_type, rec_color, recording_bg)
    
    -- Frame count
    local movie_info
    if MOVIE.readonly then
        movie_info = string.format("%d/%d", MOVIE.last_frame_started_movie, MOVIE.framecount)
    else
        movie_info = MOVIE.last_frame_started_movie
    end
    x_text = draw.text(x_text, y_text, movie_info)  -- Shows the latest frame emulated, not the frame being run now
    
    -- Rerecord and lag count
    x_text = draw.text(x_text, y_text, string.format("|%d ", MOVIE.rerecords), COLOUR.weak)
    x_text = draw.text(x_text, y_text, MOVIE.lagcount, COLOUR.warning)
    
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
    
    local str = frame_time(MOVIE.last_frame_started_movie)    -- Shows the latest frame emulated, not the frame being run now
    draw.alert_text(LSNES.Buffer_width, LSNES.Buffer_height, str, COLOUR.text, recording_bg, false, 1.0, 1.0)
    
    if LSNES.Is_lagged then
        gui.textHV(LSNES.Buffer_middle_x - 3*LSNES.FONT_WIDTH, 2*LSNES.FONT_HEIGHT, "Lag", COLOUR.warning, draw.change_transparency(COLOUR.warning_bg, draw.Bg_global_opacity))
    end
    
end


function LSNES.size_frame(frame)
    return frame > 0 and movie.frame_subframes(frame) or -1
end


function LSNES.get_input(subframe)
    local total = MOVIE.subframe_count or movie.get_size()
    
    return (subframe <= total and subframe > 0) and movie.get_frame(subframe - 1) or false
end


function LSNES.set_input(subframe, data)
    local total = MOVIE.subframe_count or movie.get_size()
    local current_subframe = MOVIE.current_subframe
    
    if subframe <= total and subframe > current_subframe then
        movie.set_frame(subframe - 1, data)
    --[[
    elseif subframe == current_subframe then
        local lcid = 
        input.joyset(lcid, )
    --]]
    end
end


function LSNES.treat_input(input_obj)
    local presses = {}
    local index = 1
    local number_controls = CONTROLLER.total_controllers
    for lcid = 1, number_controls do
        local port, cnum = CONTROLLER[lcid].port, CONTROLLER[lcid].controller
        local is_gamepad = CONTROLLER[lcid].class == "gamepad"
        
        -- Currently shows all ports and controllers
        for control = 1, CONTROLLER[lcid].button_count do
            local button_value, str
            if is_gamepad or control > 2 then  -- only the first 2 buttons can be axis
                button_value = input_obj:get_button(port, cnum, control-1)
                str = button_value and CONTROLLER[lcid].symbols[control] or " "
            else
                button_value = input_obj:get_axis(port, cnum, control-1)
                str = button_value%10  -- FIX: should display the whole number for axis
            end
            
            presses[index] = str
            index = index + 1
        end
    end
    
    return table.concat(presses)
end


function subframe_to_frame(subf)
    local total_frames = MOVIE.framecount or movie.count_frames(nil)
    local total_subframes = MOVIE.subframe_count or movie.get_size(nil)
    
    if total_subframes < subf then return total_frames + (subf - total_subframes) --end
    else return movie.subframe_to_frame(subf - 1) end
end


-- Colour schemes:
-- white: readonly frames
-- yellow: readwrite frames
-- blue: subframes
-- reddish: nullinput after the end of the movie, in readonly mode
-- cyan: delayed subframe input that will be saved but wasn't yet (lsnes bug)
-- green: "Unrecorded" message
function LSNES.display_input()
    -- Font
    local default_color = MOVIE.readonly and COLOUR.text or 0xffff00
    local width  = LSNES.FONT_WIDTH
    local height = LSNES.FONT_HEIGHT
    
    -- Input grid settings
    local grid_width, grid_height = width*CONTROLLER.total_buttons, LSNES.Buffer_height
    local x_grid, y_grid = - grid_width, 0
    local grid_subframe_slots = grid_height//height - 1  -- discount the header
    grid_height = (grid_subframe_slots + 1)*height  -- if grid_height is not a multiple of height, cut it
    local past_inputs_number = (grid_subframe_slots - 1)//2  -- discount the present
    local future_inputs_number = grid_subframe_slots - past_inputs_number  -- current frame is included here
    local y_present = y_grid + (past_inputs_number + 1)*height  -- add header
    local x_text, y_text = x_grid, y_present - height
    
    -- Extra settings
    local color, subframe_around = nil, false
    local input
    local subframe = MOVIE.current_subframe
    local frame = MOVIE.frame_of_past_subframe -- frame corresponding to subframe-1
    local length_frame_string = #tostringx(subframe + future_inputs_number - 1)
    local x_frame = x_text - length_frame_string*width - 2
    local starting_subframe_grid = subframe - past_inputs_number
    local last_subframe_grid = subframe + future_inputs_number - 1
    
    -- Draw background
    local complete_input_sequence = CONTROLLER.complete_input_sequence
    for y = 1, grid_subframe_slots do
        gui.text(x_text, 16*y, complete_input_sequence, 0xc0ffffff)
    end
    -- Draw grid
    local colour = 0x909090
    gui.rectangle(x_text, y_present, grid_width, height, 1, 0xff0000, 0xc0ff0000)
    gui.rectangle(x_grid, y_grid, grid_width, grid_height, 1, colour)
    local total_previous_button = 0
    for line = 1, CONTROLLER.total_controllers, 1 do
        -- fmt("%d:%d", CONTROLLER[line].port, CONTROLLER[line].controller) -> better header?
        gui.text(x_grid + width*total_previous_button + 1, y_grid, line, colour, nil, COLOUR.halo)
        if line == CONTROLLER.total_controllers then break end
        total_previous_button = total_previous_button + CONTROLLER[line].button_count
        gui.line(x_grid + width*total_previous_button, y_grid, x_grid + width*total_previous_button, grid_height - 1, colour)
    end
    
    for subframe_id = subframe - 1, subframe - past_inputs_number, -1 do  -- discount header?
        if subframe_id <= 0 then
            starting_subframe_grid = 1
            break
        end
        
        local is_nullinput, is_startframe, is_delayedinput
        local raw_input = LSNES.get_input(subframe_id)
        if raw_input then
            input = LSNES.treat_input(raw_input)
            is_startframe = raw_input:get_button(0, 0, 0)
            if not is_startframe then subframe_around = true end
            color = is_startframe and default_color or 0xff
        elseif frame == MOVIE.current_frame then
            gui.text(0, 0, "frame == MOVIE.current_frame", "red", nil, "black") -- test -- delete
            input = LSNES.treat_input(MOVIE.last_input_computed)
            is_delayedinput = true
            color = 0x00ffff
        else
            input = "NULLINPUT"
            is_nullinput = true
            color = 0xff8080
        end
        
        gui.text(x_frame, y_text, frame, color, nil, COLOUR.halo)
        gui.text(x_text, y_text, input, color)
        
        if is_startframe or is_nullinput then
            frame = frame - 1
        end
        y_text = y_text - height
    end
    
    y_text = y_present
    frame = MOVIE.current_frame
    
    for subframe_id = subframe, subframe + future_inputs_number - 1 do
        local raw_input = LSNES.get_input(subframe_id)
        local input = raw_input and LSNES.treat_input(raw_input) or "Unrecorded"
        
        if raw_input and raw_input:get_button(0, 0, 0) then
            if subframe_id ~= MOVIE.current_subframe then frame = frame + 1 end
            color = default_color
        else
            if raw_input then
                subframe_around = true
                color = 0xff
            else
                color = 0x00ff00
            end
        end
        
        gui.text(x_frame, y_text, frame, color, nil, COLOUR.halo)
        gui.text(x_text, y_text, input, color)
        y_text = y_text + height
        
        if not raw_input then
            last_subframe_grid = subframe_id
            break
        end
    end
    
    -- TEST -- edit
    LSNES.subframe_update = subframe_around
    gui.subframe_update(LSNES.subframe_update)
    
    -- Button settings
    local x_button = (User_input.mouse_x - x_grid)//width
    local y_button = (User_input.mouse_y - (y_grid + y_present))//height
    if x_button >= 0 and x_button < CONTROLLER.total_buttons and
    y_button >= 0 and y_button <= last_subframe_grid - subframe then
        gui.solidrectangle(width*(User_input.mouse_x//width), height*(User_input.mouse_y//height), width, height, 0xb000ff00)
    end
    
    -- Debug
    if SCRIPT_DEBUG_INFO then
        gui.text(0, 100, string.format("%d %d", x_button, y_button), "red", "black")
    end
    --------
    
    x_button = x_button + 1  -- FIX IT
    local tab = CONTROLLER.button_array[x_button]
    if tab and LSNES.Runmode == "pause" then
        if SCRIPT_DEBUG_INFO then
            --print(MOVIE.current_subframe + y_button, CONTROLLER.button_array[x_button].port, CONTROLLER.button_array[x_button].controller, CONTROLLER.button_array[x_button].button)
        end
        return MOVIE.current_subframe + y_button, tab.port, tab.controller, tab.button - 1  -- FIX IT, hack to edit 'B' button
    end
end


function LSNES.left_click()
    if SCRIPT_DEBUG_INFO then print"left_click" end -- delete
    
    -- Movie Editor
    subframe = LSNES.frame
    port = LSNES.port
    controller = LSNES.controller
    button = LSNES.button
    if subframe and port and controller and button then
        local INPUTFRAME = LSNES.get_input(subframe)
        if not INPUTFRAME then return end
        
        local status = INPUTFRAME:get_button(port, controller, button)
        --[[
        local is_gamepad = input.controller_info(port, controller).class == "gamepad"
        local status
        if is_gamepad or button >= 2 then  -- only the first 2 buttons can be axis
            status = INPUTFRAME:get_button(port, controller, button-1)
        else
            print"AXXXXIS"
            status = INPUTFRAME:get_axis(port, controller, button-1)
        end
        
        local new_status
        if status == true or status == false then new_status = not status else new_status = (status + 1)%256 end
        print("----", is_gamepad, status, new_status)
        --]]
        
        if subframe <= MOVIE.subframe_count and subframe >= MOVIE.current_subframe then
            movie.edit(subframe - 1, port, controller, button, not status)  -- 0-based
        end
        
        if SCRIPT_DEBUG_INFO then
            print(subframe, port, controller, button, status) -- delete
        end
    end
    
    -- Script buttons
    for _, field in ipairs(draw.buttons_table) do
        -- if mouse is over the button
        if mouse_onregion(field.x, field.y, field.x + field.width, field.y + field.height) then
                field.action()
                return
        end
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


function on_frame_emulated()
    LSNES.Is_lagged = memory.get_lag_flag()
    LSNES.frame_boundary = "end"
end

function on_frame()
    LSNES.frame_boundary = "start"
    if not movie.rom_loaded() then  -- only useful with null ROM
        gui.repaint()
    end
end


function on_input(subframe)
    LSNES.frame_boundary = "middle"
end


function on_paint(authentic_paint)
    if SCRIPT_DEBUG_INFO then gui.solidrectangle(0, 0, 512, 448, 0x20000000) end  -- delete
    
    -- Initial values, don't make drawings here
    read_raw_input()
    LSNES.Runmode = gui.get_runmode()
    LSNES.Lsnes_speed = settings.get_speed()
    
    LSNES.get_screen_info()
    if not ROM_INFO.info_loaded then LSNES.get_rom_info() end
    if not CONTROLLER.info_loaded then LSNES.get_controller_info() end
    LSNES.get_movie_info()
    LSNES.left_gap = 8*CONTROLLER.total_buttons + 6*8 -- TEST
    create_gaps()
    
    if not authentic_paint then gui.text(-8, -16, "*") end
    --draw.text(0, LSNES.Buffer_height - 32, tostringx(CONTROLLER.ports))
    
    if OPTIONS.use_movie_editor_tool then
        LSNES.frame, LSNES.port, LSNES.controller, LSNES.button = LSNES.display_input()  -- test: fix names
    end
    if SCRIPT_DEBUG_INFO then LSNES.debug_movie() end
    show_movie_info(OPTIONS.display_movie_info)
    
    -- TEST
    -- Input button
    if User_input.mouse_inwindow == 1 then
        draw.button(0, 0, OPTIONS.use_movie_editor_tool and "Hide Input" or "Show Input", function()
            OPTIONS.use_movie_editor_tool = not OPTIONS.use_movie_editor_tool
        end, {always_on_client = true, ref_x = 1.0, ref_y = 1.0})
    end
    
    if SCRIPT_DEBUG_INFO then gui.text(2, 432, string.format("Garbage %.0fkB", collectgarbage("count")), "orange", nil, "black") end -- remove
end


-- Loading a state
function on_pre_load(...)
    if SCRIPT_DEBUG_INFO then print("PRE LOAD", ...) end
    LSNES.frame_boundary = "start"
    LSNES.Is_lagged = false
end


function on_post_load(...)
    if SCRIPT_DEBUG_INFO then print("POST LOAD", ...) end
end


-- Functions called on specific events
function on_readwrite()
    gui.repaint()
end


-- Rewind functions
function on_rewind()
    LSNES.frame_boundary = "start"
end


function on_movie_lost(kind)
    if SCRIPT_DEBUG_INFO then print("ON MOVIE LOST", kind) end
    
    if kind == "reload" then  -- just before reloading the ROM in rec mode or closing/loading new ROM
        ROM_INFO.info_loaded = false
        CONTROLLER.info_loaded = false
        
    elseif kind == "load" then -- this is called just before loading / use on_post_load when needed
        CONTROLLER.info_loaded = false
        
    end
    
end


function on_idle()
    if User_input.mouse_inwindow == 1 then gui.repaint() end
    set_idle_timeout(1000000//30)
end


--#############################################################################
-- ON START --

LSNES.subframe_update = false
gui.subframe_update(LSNES.subframe_update)  -- TODO: this should be true when paused or in heavy slowdown -- EDIT

-- KEYHOOK callback
on_keyhook = Keys.altkeyhook

-- Key presses:
Keys.registerkeypress("mouse_inwindow", gui.repaint)
Keys.registerkeypress(OPTIONS.hotkey_increase_opacity, function() draw.increase_opacity() end)
Keys.registerkeypress(OPTIONS.hotkey_decrease_opacity, function() draw.decrease_opacity() end)
Keys.registerkeypress("mouse_left", function() LSNES.left_click(); gui.repaint() end)
Keys.registerkeypress("period", function()
    LSNES.subframe_update = not LSNES.subframe_update
    gui.subframe_update(LSNES.subframe_update)
    gui.repaint()
end)

set_idle_timeout(1000000//30)
gui.repaint()
