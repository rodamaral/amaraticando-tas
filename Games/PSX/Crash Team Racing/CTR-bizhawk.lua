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

local MainRAM={
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

-- Variables
local Prev = {}
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
        x_text = x_text + width*#movie_type
        local movie_info
        if Readonly then
            movie_info = fmt("%d/%d", Lastframe_emulated, Framecount)
        else
            movie_info = fmt("%d", Lastframe_emulated)
        end
        draw_text(x_text, y_text, movie_info)  -- Shows the latest frame emulated, not the frame being run now
        
        -- Rerecord count
        x_text = x_text + width*#movie_info
        local rr_info = fmt(" %d ", Rerecords)
        draw_text(x_text, y_text, rr_info, 0x80e0e0e0)
        
        -- Lag count
        x_text = x_text + width*#rr_info
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


local function other_game_mechanics(address)
    local x_txt, y_txt, delta_y = Buffer_width, 20, 20
    
    -- Read RAM
    local turboReserves = u16(address + 0x3e2) --
	local slideTimer = u16(address + 0x3dc) --
	local jumpTimer = u16(address + 0x3fc)
	local landing = u8(address + 0x3f0)
    local wumpa_count = u8(address + 0x30) --
    local number_position = u8(address + 0x482) + 1 --
    local timer = u32(address + 0x514) -- new
    
	draw_text(x_txt, y_txt, fmt("Turbo %d/32767", turboReserves))
    y_txt = y_txt + delta_y
	draw_text(x_txt, y_txt, fmt("Slide: %5d", slideTimer))
    y_txt = y_txt + delta_y
	draw_text(x_txt, y_txt, fmt("Jump: %5d", jumpTimer))
    y_txt = y_txt + delta_y
	draw_text(x_txt, y_txt, fmt("Land: %3d", landing))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Wumpa: %x: %d", address + 0x30, wumpa_count), "orange") -- test
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Position: %d", number_position), "blue") -- test
    
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

local function level_mode_info()
	local environment_number = u8(MainRAM["environment"])
	local racer_number = u8(MainRAM["character"]) or 0
	local track_number = u8(MainRAM["track"]) or 0
	
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
    gui.text(0, 0, fmt("$%.6x ", address), "black", "cyan", "bottomright")
    gui.text(0, 20, "-", nil, nil, "bottomright")
    
    -- Read RAM
    local absolute_subspeed = s8(address + 0x38c)
    local absSpeed = u8(address + 0x38d)
	local speed_meter = s16(address + 0x38e)
	local vertical_speed = s16(address + 0x390)
    local zspeed = mainmemory.read_s32_be(address + 0x392) -- TEST
    local absPos = u8(address + 0x489) --
	local absSubPos = u8(address + 0x488) --
	local maxAbsPos = u8(address + 0x48d) --
	local maxAbsSubPos = u8(address + 0x48c) --
    local horizontal_speed_decrementation = s16(address + 0x3b2)
    local horizontal_speed = speed_meter - horizontal_speed_decrementation
    
    -- Positions  (from 0xed4 to 0xedf)
    local x = s32(address + 0x2d4)
    local x_speed = s32(address + 0x88)
    local z = s32(address + 0x2d8) --
    local z_speed = s32(address + 0x8c)
    local y = s32(address + 0x2dc) --
    local y_speed = s32(address + 0x90)
    
    -- previous positions from 0xee0 to 0xeeb
    local x2 = s32(address + 0x2e0) --
    local z2 = s32(address + 0x2e4) --
    local y2 = s32(address + 0x2e8) --
    local deslocamento = math.sqrt((x2-x)^2 + (y2-y)^2 + (z2-z)^2)
    local deslocamento_horizontal = math.sqrt((x2-x)^2 + (y2-y)^2)
    
    -- Direction
    local direction = 0xc00 - s16(address + 0x39a)
    local moving_direction = 0xc00 - s16(address + 0x396)
    local vertical_direction = s16(address + 0x3a0)
    local x_angle = math.sin(moving_direction*math.pi/2048)
    local y_angle = math.cos(moving_direction*math.pi/2048)
    local effective_inclination1 = s8(address + 0x31b)
    local effective_inclination2 = s8(address + 0x33b)
    local speed_inclination = s8(address + 0x94)
    
    -- SPECIAL
    local x_txt, y_txt, delta_y = 0, Buffer_height - 32, 20
	alert_text(x_txt, y_txt, fmt("Abs. Sp. = %d.%.2x - %d", absSpeed, absolute_subspeed, absSpeed*256+absolute_subspeed), 0xffff0000, 0xff000000)
    gui.drawBox(0, 200, 8*14, 216, 0x800000ff, 0x800000ff)
    gui.drawText(0, 200, fmt("Hor: %5d", horizontal_speed), 0xffff0000, 16)
    
    -- Positions
    x_txt, y_txt = - Border_left, 64
    draw_text(x_txt, y_txt, fmt("X = %d (%d)", x, x- x2))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Y = %d (%d)", y, y - y2))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Z = %d (%d) [%d]", z, z - z2, vertical_speed))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("%f, %f", deslocamento, deslocamento_horizontal), "yellow", "darkblue")
    y_txt = y_txt + delta_y
    
    -- Down
	draw_text(x_txt, y_txt, fmt("Abs Pos: %3d.%02x/%3d.%02x", absPos, absSubPos, maxAbsPos, maxAbsSubPos))
    y_txt = y_txt + delta_y
    draw_text(x_txt, y_txt, fmt("Effec. Incl.(%d, %d) %d", effective_inclination1, effective_inclination2, speed_inclination))
    y_txt = y_txt + delta_y
    
    -- RIGHT
    --other_game_mechanics(address)  -- edit
end

local function crash_team_racing()
	local input_video_advance = u8(0x98800) ~= 0
    local on_level = s8(MainRAM["on_level"])
    
    if input_video_advance then
        gui.text(Buffer_width/2, 0, "INPUT", "black", "red")
    end
    
    --if on_level==2 then
        gui.text(0, 0, "Game Mode: " .. on_level, "black", "white", "topright")
		level_mode_info()
	--end
	return
end


-- Execute


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
