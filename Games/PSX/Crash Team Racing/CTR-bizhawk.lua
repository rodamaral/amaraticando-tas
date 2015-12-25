---------------------------------------------------------------------------
--  Crash Team Racing [NTSC-U] [SCUS-94426] Utility Script for BizHawk
--  http://tasvideos.org/BizHawk.html
--  
--  Author: Rodrigo A. do Amaral (Amaraticando)
--  Git repository: https://github.com/rodamaral/amaraticando-tas
---------------------------------------------------------------------------

-- Currently, only basic resources and functions
-- NTSC-U only for now :(
-- Better display using the PSX > Options > Mednafen Mode (4:3 AR)

-- Function's alias
local u8 = mainmemory.read_u8
local s8  = mainmemory.read_s8
local u16  = mainmemory.read_u16_le
local s16  = mainmemory.read_s16_le
local u24  = mainmemory.read_u24_le
local s24  = mainmemory.read_s24_le
local u32  = mainmemory.read_u32_le
local s32  = mainmemory.read_s32_le
local fmt = string.format
local floor = math.floor

-- Constants
local BIZHAWK_FONT_WIDTH = 10
local BIZHAWK_FONT_HEIGHT = 14

local ram={
	on_level = 0x0008D447,
	environment = 0x0008D0FC,
    track = 0x0008D930,
    character  = 0x00086E84,
    lap = 0x001FFE38
}

local track_name = {
	[0]  = "Crash Cove",		[1]  = "Roo's Tubes",		[2]  = "Tiger Temple",
	[3]  = "Coco Park",			[4]  = "Mystery Caves",		[5]  = "Blizzard Bluff",
	[6]  = "Sewer Speedway",	[7]  = "Dingo Canyon",		[8]  = "Papu's Pyramid",
	[9]  = "Dragon Mines",		[10] = "Polar Pass",		[11] = "Cortex Castle",
	[12] = "Tiny Arena",		[13] = "Hot Air Skyway",	[14] = "N.Gin Labs",
	[15] = "Oxide Station",		[16] = "Slide Coliseum",	[17] = "Turbo Track"
}

local racer_name = {
	[0]  = "Crash Bandicoot",	[1]  = "Dr. Neo Cortex",	[2]  = "Tiny Tiger",	[3]  = "Coco Bandicoot",
	[4]  = "N. Gin",			[5]  = "Dingodile",       	[6]  = "Polar",     	[7]  = "Pura",
	[8]  = "Pinstripe",       	[9]  = "Papu Papu",			[10] = "Ripper Roo",    [11] = "Komodo Joe",
	[12] = "Dr. N. Tropy",    	[13] = "Penta Penguin",     [14] = "Fake Crash",  	[15] = "Nitros Oxide"
}

local Joypad = {}


local Movie_active, Readonly, Framecount, Lagcount, Rerecords, Game_region
local Lastframe_emulated, Starting_subframe_last_frame, Size_last_frame, Final_subframe_last_frame
local Nextframe, Starting_subframe_next_frame, Starting_subframe_next_frame, Final_subframe_next_frame
local function bizhawk_status()
    Movie_active = movie.isloaded()  -- BizHawk
    Readonly = movie.getreadonly()  -- BizHawk
    Framecount = movie.length()  -- BizHawk
    Lagcount = emu.lagcount()  -- BizHawk
    Rerecords = movie.getrerecordcount()  -- BizHawk
    Is_lagged = emu.islagged()  -- BizHawk
    Game_region = emu.getdisplaytype()  -- BizHawk
    
    -- Last frame info
    Lastframe_emulated = emu.framecount()
    
    -- Next frame info (only relevant in readonly mode)
    Nextframe = Lastframe_emulated + 1
end


-- Get screen values of the game and emulator areas
local Border_left, Border_right, Border_top, Border_bottom, Buffer_width, Buffer_height
local Screen_size, Screen_width, Screen_height, AR_x, AR_y
local function bizhawk_screen_info()
    Border_left = client.borderwidth()  -- Borders' dimensions
    Border_right = Border_left
    Border_top = client.borderheight()
    Border_bottom = Border_top
    
    Buffer_width = client.bufferwidth()  -- Game area
    Buffer_height = client.bufferheight()
    
	Screen_size = client.getwindowsize()  -- Emulator area
	Screen_width = client.screenwidth()
	Screen_height = client.screenheight()
    
    AR_x = Buffer_width/400
	AR_y = Buffer_height/300
end


local function get_joypad()
    if Movie_active then
        if Readonly then   -- get joypad
            Joypad = emu.framecount() < movie.length() and movie.getinput(emu.framecount()) or joypad.get(1)
        else
            Joypad = movie.getinput(emu.framecount() - 1)
        end
    else
        Joypad = {}
    end
end


local function draw_text(x, y, text, text_color, outline_color)
    -- Reads external variables
    local game_screen_x = Border_left
    local game_screen_y = Border_top
    
    gui.text(x + game_screen_x, y + game_screen_y, text, outline_color, text_color)
end


local function alert_text(x_pos, y_pos, text, text_color, bg_color)
    -- Reads external variables
    local font_width  = BIZHAWK_FONT_WIDTH
    local font_height = BIZHAWK_FONT_HEIGHT
    local text_length = string.len(text)
    
    --gui.drawBox(x_pos/AR_x, y_pos/AR_y, (x_pos + text_length)/AR_x + 2, (y_pos + font_height)/AR_y + 1, 0, bg_color)
    
    gui.text(x_pos + Border_left - 2, y_pos + Border_top - 2, text, bg_color, bg_color)
    gui.text(x_pos + Border_left + 0, y_pos + Border_top - 2, text, bg_color, bg_color)
    gui.text(x_pos + Border_left - 2, y_pos + Border_top + 0, text, bg_color, bg_color)
    --gui.text(x_pos + Border_left + 1, y_pos + Border_top + 1, text, bg_color, bg_color)
    
    gui.text(x_pos + Border_left, y_pos + Border_top, text, bg_color, text_color)
end


local function show_movie_info()
    local y_text = - Border_top
    local x_text = 0
    local width = BIZHAWK_FONT_WIDTH
    
    local rec_color = (Readonly or not Movie_active) and 0xffffffff or 0xffff0000
    local recording_bg = (Readonly or not Movie_active) and 0 or 0xffff0000
    
    -- Read-only or read-write?
    local movie_type = (not Movie_active and "No movie ") or (Readonly and "Movie " or "REC ")
    draw_text(x_text, y_text, movie_type, rec_color, recording_bg)
    
    if Movie_active then
        -- Frame count
        x_text = x_text + width*string.len(movie_type)
        local movie_info
        if Readonly then
            movie_info = string.format("%d/%d", Lastframe_emulated, Framecount)
        else
            movie_info = string.format("%d", Lastframe_emulated)
        end
        draw_text(x_text, y_text, movie_info)  -- Shows the latest frame emulated, not the frame being run now
        
        -- Rerecord count
        x_text = x_text + width*string.len(movie_info)
        local rr_info = string.format(" %d ", Rerecords)
        draw_text(x_text, y_text, rr_info, 0x80e0e0e0)
        
        -- Lag count
        x_text = x_text + width*string.len(rr_info)
        draw_text(x_text, y_text, Lagcount, 0xffff0000)
    end
    
end


local function show_joypad()
    if not Movie_active then return end
    
    local x_text, y_text = 10, Buffer_height - 40
    local current_input = ""
    gui.text(x_text, y_text, "^v<>s$STOXlLrR", 0, 0x20ffffff)  -- base
    joypad.set({Cross = true}, 1)
    
    if Joypad["P1 Up"] then current_input = current_input .. "^" end
    if Joypad["P1 Down"] then current_input = current_input .. "v" end
    if Joypad["P1 Left"] then current_input = current_input .. "<" end
    if Joypad["P1 Right"] then current_input = current_input .. ">" end
    if Joypad["P1 Select"] then current_input = current_input .. "s" end
    if Joypad["P1 Start"] then current_input = current_input .. "$" end
    if Joypad["P1 Square"] then current_input = current_input .. "S" end
    if Joypad["P1 Triangle"] then current_input = current_input .. "T" end
    if Joypad["P1 Circle"] then current_input = current_input .. "O" end
    if Joypad["P1 Cross"] then current_input = current_input .. "X" end
    if Joypad["P1 L1"] then current_input = current_input .. "l" end
    if Joypad["P1 L2"] then current_input = current_input .. "L" end
    if Joypad["P1 R1"] then current_input = current_input .. "r" end
    if Joypad["P1 R2"] then current_input = current_input .. "R" end
    
    gui.text(x_text, y_text, current_input, 0, 0xff0000)
end


local Prev = {}-- test
local function level_mode_info()
	local environment_number = u8(ram["environment"])
	local racer_number = u8(ram["character"]) or 0
	local track_number = u8(ram["track"]) or 0
	
	if racer_number>=0 and racer_number<=15 then 
		--gui.text(0, 0, fmt("%s", racer_name[racer_number]))
	end
    if track_number>=0 and track_number<=17 then
		--gui.text(0, 14, fmt("%s - Environment %d", track_name[track_number], environment_number))
	end
	
    local offset = u32(0x8d674)
    --local offset = u32(0x99014)  -- another character
    local address = offset - 0x80000000
    
    if address >= 0x200000 - 0x600 or address < 0 then  -- 0x600 is semi-arbitrary here
        gui.text(100, 100, "OFFSET OUT OF BOUNDS", 0, 0xff0000)
        return
    end
    
    local absolute_subspeed = u8(address + 0x38c)
    local absSpeed = u8(address + 0x38d)
    local horizontal_subspeed = u8(address + 0x38e)
	local horiSpeed = s8(address + 0x38f)
    local vertical_subspeed = u8(address + 0x390)
	local vertSpeed = s8(address + 0x391)
    local zspeed = mainmemory.read_s32_be(address + 0x392) -- TEST
	local turboReserves = u16(address + 0x3e2) --
	local slideTimer = u16(address + 0x3dc) --
    local absPos = u8(address + 0x489) --
	local absSubPos = u8(address + 0x488) --
	local maxAbsPos = u8(address + 0x48d) --
	local maxAbsSubPos = u8(address + 0x48c) --
	local jumpTimer = u16(address + 0x3fc)
	local landing = u8(address + 0x3f0)
    local wumpa_count = u8(address + 0x30) --
    local number_position = u8(address + 0x482) + 1 --
    local timer = u32(address + 0x514) -- new
    
    -- Positions  (from 0xed4 to 0xedf)
    local x = s32(address + 0x2d4) --
    local x_pos = floor(x/0x100)
    local x_subpixel = x%0x100
    local x_speed = s32(address + 0x88)
    local z = s32(address + 0x2d8) --
    local z_pos = floor(z/0x100)
    local z_subpixel = z%0x100
    local z_speed = s32(address + 0x8c)
    local y = s32(address + 0x2dc) --
    local y_pos = floor(y/0x100)
    local y_subpixel = y%0x100
    local y_speed = s32(address + 0x90)
    -- previous positions from 0xee0 to 0xeeb
    ---[[
    local x2 = s32(address + 0x2e0) --
    local x_pos2 = floor(x/0x100)
    local x_subpixel2 = x%0x100
    local z2 = s32(address + 0x2e4) --
    local z_pos2 = floor(z/0x100)
    local z_subpixel2 = z%0x100
    local y2 = s32(address + 0x2e8) --
    local y_pos2 = floor(y/0x100)
    local y_subpixel2 = y%0x100
    local deslocamento = math.sqrt((x2-x)^2 + (y2-y)^2 + (z2-z)^2)
    local deslocamento_horizontal = math.sqrt((x2-x)^2 + (y2-y)^2)
    gui.text(64, 0, fmt("%f, %f", deslocamento/256, deslocamento_horizontal/256), "darkblue", "yellow")
    
    --[[
    Prev.timer = not Prev.timer
    if Prev.x then gui.text(128, 128, x - Prev.x) end
    if Prev.y then gui.text(128, 144, y - Prev.y) end
    if Prev.z then gui.text(128, 158, z - Prev.z) end
    Prev.x = x
    Prev.y = y
    Prev.z = z
    --]]
    
    -- Direction
    local direction = 0xc00 - s16(address + 0x39a)
    local moving_direction = 0xc00 - s16(address + 0x396)
    local vertical_direction = s16(address + 0x3a0)
    local x_angle = math.sin(moving_direction*math.pi/2048)
    local y_angle = math.cos(moving_direction*math.pi/2048)
    local combined_speed = 256*absSpeed + absolute_subspeed -- test
    local horizontal_speed = math.sqrt(combined_speed^2 - (256*vertSpeed+ vertical_subspeed)^2)/256 -- test
    local effective_inclination1 = s8(address + 0x31b)
    local effective_inclination2 = s8(address + 0x33b)
    local speed_inclination = s8(address + 0x94)
    
    -- SPECIAL
    local x_txt, y_txt, delta_y = 0, Buffer_height - 64, 20
    -- gui.text(0, 500, fmt("OFFSET %X", address), "black", "magenta")
	alert_text(x_txt, y_txt, fmt("Abs. Sp. = %d.%.2x - %d", absSpeed, absolute_subspeed, absSpeed*256+absolute_subspeed), 0xffff0000, 0xff000000)
    y_txt = y_txt + delta_y
    --alert_text(x_txt, y_txt, fmt("Hor: %3d.%.2x", horiSpeed, horizontal_subspeed), 0xffff0000, 0xff000000)
    gui.drawBox(0, 200, 8*14, 216, 0x800000ff, 0x800000ff)
    gui.drawText(0, 200, fmt("Hor: %3d.%.2x", horiSpeed, horizontal_subspeed), 0xffff0000, 16)
    y_txt = y_txt + delta_y
    
    -- Positions
    x_txt, y_txt = - Border_left, 64
    --[[
    draw_text(10, 64, x.."|"..x2..": "..(x-x2).." vs "..x_speed)
    draw_text(10, 68, y.."|"..y2..": "..(y-y2).." vs "..y_speed)
    draw_text(10, 72, z.."|"..z2..": "..(z-z2).." vs "..z_speed)
    --]]
    ---[[
    draw_text(x_txt, y_txt, fmt("X = %d.%.2x", x_pos, x_subpixel))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Y = %d.%.2x [%d.%.2x - %d]", y_pos, y_subpixel, vertSpeed, vertical_subspeed, 256*vertSpeed+vertical_subspeed))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Z = %d.%.2x", z_pos, z_subpixel))
    y_txt = y_txt + delta_y
    --]]
    
    draw_text(x_txt, y_txt, fmt("Dir: %d (%f, %f)", direction, 256*horizontal_speed*x_angle, 256*horizontal_speed*y_angle), "red")
    y_txt = y_txt + delta_y
    gui.text(x_txt, y_txt, horizontal_speed, "blue") --
    y_txt = y_txt + delta_y
    
    -- RIGHT
    x_txt, y_txt = Buffer_width, 0
	draw_text(x_txt, y_txt, fmt("Turbo %d/32767", turboReserves))
    y_txt = y_txt + delta_y
	draw_text(x_txt, y_txt, fmt("Slide: %5d", slideTimer))
    y_txt = y_txt + delta_y
	draw_text(x_txt, y_txt, fmt("Abs Pos: %3d.%02x/%3d.%02x", absPos, absSubPos, maxAbsPos, maxAbsSubPos))
    y_txt = y_txt + delta_y
	draw_text(x_txt, y_txt, fmt("Jump: %5d", jumpTimer))
    y_txt = y_txt + delta_y
	draw_text(x_txt, y_txt, fmt("Land: %3d", landing))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Effec. Incl.(%d, %d) %d", effective_inclination1, effective_inclination2, speed_inclination))
    y_txt = y_txt + delta_y
    --y_txt = y_txt + delta_y
    --draw_text(x_txt, y_txt, fmt("Wumpa: %x: %d", address + 0x30, wumpa_count), "orange") -- test
    --y_txt = y_txt + delta_y
    --draw_text(x_txt, y_txt, fmt("Position: %d", number_position), "blue") -- test
    
    -- Random shit
    --[[
    local estimated_speed = math.max(0, math.sqrt((absSpeed*256+absolute_subspeed)^2 - (256*vertSpeed+vertical_subspeed)^2) - 120)
    draw_text(68, 65, estimated_speed)-- test
    
    gui.text(64, 32, timer, "black", "purple")
    gui.text(64, 48, s32(address + 0x3a8))
    gui.text(64, 64, fmt("%x: %d", address + 0x392, zspeed))
    gui.text(64, 80, moving_direction)
    gui.text(64, 96, "Ver. Dir. "..vertical_direction)
    --]]
end

local function crash_team_racing()
	local input_video_advance = u8(0x98800) ~= 0
    local on_level = s8(ram["on_level"])
    
    if input_video_advance then
        gui.text(Buffer_width/2, 0, "INPUT", "black", "red")
    end
    
    --if on_level==2 then
        gui.text(0, 0, "Game Mode: " .. on_level, "black", "white", "topright")
		level_mode_info()
	--end
	return
end


while true do
    -- Get emulator status and settings
    bizhawk_status()
    bizhawk_screen_info()
    get_joypad()
    if emu.islagged() then  -- BizHawk: outside show_movie_info
        gui.drawText(200, 20, " LAG ", 0xffff0000, 20)
    end
    
    -- Display relevant emu info
    show_movie_info()
    show_joypad()
    
    -- Game functions
    crash_team_racing()
    
    emu.frameadvance()
end
