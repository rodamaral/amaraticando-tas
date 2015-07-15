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

local ram={
	on_level = 0x0008D447,
	environment = 0x0008D0FC,
    track = 0x0008D930,
    character  = 0x00086E84,
    lap = 0x001FFE38
}

-- OFFSET = -17612 + DCache/0x88
local ram_racer_timetrial={
	[13] = 0,		[6]  = 1732,	[9]  = 3332,	[3]  = 4380,	[10] = 4488,
	[12] = 6456,	[2]  = 6476,	[4]  = 6700,	[8]  = 7164,	[14] = 7872,
	[1]  = 8668,	[11] = 9444,	[7]  = 9816,	[0]  = 10260,	[5]  = 10628
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


-- Get screen values of the game and emulator areas
local Border_left, Border_right, Border_top, Border_bottom, Buffer_width, Buffer_height
local Screen_size, Screen_width, Screen_height, Pixel_rate_x, Pixel_rate_y
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
    
    Pixel_rate_x = Buffer_width/256
	Pixel_rate_y = Buffer_height/224
end


-- Changes the default behavior of gui.text
function new_gui_text(x, y, text, text_color, outline_color)
    -- Reads external variables
    local game_screen_x = Border_left
    local game_screen_y = Border_top
    
    --outline_color = change_transparency(outline_color, 0.8)
    --text_color =    change_transparency(text_color, 0.8)
    gui.text(x + game_screen_x, y + game_screen_y - 2, text, outline_color, text_color)
end

local function scaled_text(x, y, text, text_color, outline_color)
    -- Reads external variables
    local game_screen_x = Border_left
    local game_screen_y = Border_top
    local scaled_x = x*Buffer_width*0.01
    local scaled_y = y*Buffer_height*0.01
    
    --outline_color = change_transparency(outline_color, 0.8)
    --text_color =    change_transparency(text_color, 0.8)
    gui.text(scaled_x + game_screen_x, scaled_y + game_screen_y - 2, text, outline_color, text_color)
end


local function info()
	local environment_number = mainmemory.read_u8(ram["environment"])
	local racer_number = mainmemory.read_u8(ram["character"]) or 0
	local track_number = mainmemory.read_u8(ram["track"]) or 0
	
	if racer_number>=0 and racer_number<=15 then 
		--new_gui_text(0, 0, string.format("%s", racer_name[racer_number]))
	end
    if track_number>=0 and track_number<=17 then
		--new_gui_text(0, 14, string.format("%s - Environment %d", track_name[track_number], environment_number))
	end
	
    local offset = mainmemory.read_u32_le(0x8d674)
    local address = offset - 0x80000000
    
    local absolute_subspeed = mainmemory.read_u8(address + 0x38c)
    local absSpeed = mainmemory.read_u8(address + 0x38d)
    local horizontal_subspeed = mainmemory.read_u8(address + 0x38e)
	local horiSpeed = mainmemory.read_s8(address + 0x38f)
    local vertical_subspeed = mainmemory.read_u8(address + 0x390)
	local vertSpeed = mainmemory.read_s8(address + 0x391)
	local turboReserves = mainmemory.read_u16_le(address + 0x3e2)
	local slideTimer = mainmemory.read_u16_le(address + 0x3dc)
	local absPos = mainmemory.read_u8(address + 0x489)
	local absSubPos = mainmemory.read_u8(address + 0x488)
	local maxAbsPos = mainmemory.read_u8(address + 0x48d)
	local maxAbsSubPos = mainmemory.read_u8(address + 0x48c)
	local jumpTimer = mainmemory.read_u16_le(address + 0x3fc)
	local landing = mainmemory.read_u8(address + 0x3f0)
    local wumpa_count = mainmemory.read_u8(address + 0x30) -- test
    local number_position = mainmemory.read_u8(address + 0x482) + 1 -- test
    
    -- Positions  (from 0xed4 to 0xedf)
    local x = mainmemory.read_s32_le(address + 0x2d4)
    local x_pos = math.floor(x/0x100)
    local x_subpixel = x%0x100
    local z = mainmemory.read_s32_le(address + 0x2d8)
    local z_pos = math.floor(z/0x100)
    local z_subpixel = z%0x100
    local y = mainmemory.read_s32_le(address + 0x2dc)
    local y_pos = math.floor(y/0x100)
    local y_subpixel = y%0x100
    -- previous positions from 0xee0 to 0xeeb
    ---[[
    local x2 = mainmemory.read_s32_le(address + 0x2e0)
    local x_pos2 = math.floor(x/0x100)
    local x_subpixel2 = x%0x100
    local z2 = mainmemory.read_s32_le(address + 0x2e4)
    local z_pos2 = math.floor(z/0x100)
    local z_subpixel2 = z%0x100
    local y2 = mainmemory.read_s32_le(address + 0x2e8)
    local y_pos2 = math.floor(y/0x100)
    local y_subpixel2 = y%0x100
    local deslocamento = math.sqrt((x2-x)^2 + (y2-y)^2 + (z2-z)^2)
    local deslocamento_horizontal = math.sqrt((x2-x)^2 + (y2-y)^2)
    gui.text(64, 0, string.format("%f, %f", deslocamento/256, deslocamento_horizontal/256), "darkblue", "yellow")
    --]]
    
    -- Direction
    local direction = 0xc00 - mainmemory.read_s16_le(address + 0x39a)
    local x_angle = math.sin(direction*math.pi/2048)
    local y_angle = math.cos(direction*math.pi/2048)
    local combined_speed = 256*absSpeed + absolute_subspeed -- test
    local horizontal_speed = math.sqrt(combined_speed^2 - (256*vertSpeed+ vertical_subspeed)^2)/256 -- test
    local effective_inclination1 = mainmemory.read_s8(address + 0x31b)
    local effective_inclination2 = mainmemory.read_s8(address + 0x33b)
    local speed_inclination = mainmemory.read_s8(address + 0x94)
    
    gui.text(0, 500, string.format("OFFSET %X", address), "black", "magenta")
	scaled_text(75, 60, string.format("Abs. Sp. = %d.%.2x", absSpeed, absolute_subspeed))
	scaled_text(88.5, 85, string.format("%3d.%.2x", horiSpeed, horizontal_subspeed), "red")
	scaled_text(75, 62.5, string.format("Vrt. Sp. = %d.%.2x", vertSpeed, vertical_subspeed))
	scaled_text(78, 92, string.format("Turbo %d/32767", turboReserves))
	scaled_text(78.75, 86, string.format("%5d", slideTimer))
	scaled_text(40, 00, string.format("%3d.%02x/%3d.%02x", absPos, absSubPos, maxAbsPos, maxAbsSubPos))
	scaled_text(86.75, 78, string.format("%5d", jumpTimer))
	scaled_text(89, 80.5, string.format("%3d", landing))
    scaled_text(68, 10, string.format("%x: %d", address + 0x30, wumpa_count), "orange") -- test
    scaled_text(12, 90, number_position, "blue") -- test
    
    -- Positions
    scaled_text(10, 64, string.format("X = %d.%.2x", x_pos, x_subpixel))
    scaled_text(10, 68, string.format("Y = %d.%.2x", y_pos, y_subpixel))
    scaled_text(10, 72, string.format("Z = %d.%.2x", z_pos, z_subpixel))
    
    scaled_text(10, 76, string.format("%d (%f, %f)", direction, combined_speed*x_angle, combined_speed*y_angle), "red")
    gui.text(600, 0, horizontal_speed, "blue") --
    scaled_text(10, 80, string.format("Effec. Incl.(%d, %d) %d", effective_inclination1, effective_inclination2, speed_inclination))
end

local function display()
	local on_level = mainmemory.read_s8(ram["on_level"])
    
    if on_level==2 then
		info()
	end
	return
end

while true do
    bizhawk_screen_info()
    
	display()
	
    emu.frameadvance()
end
