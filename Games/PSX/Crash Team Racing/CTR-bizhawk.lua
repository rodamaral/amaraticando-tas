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

local TIMETRIAL_ADRESS = 0x001AC795

local ram={
	on_level = 0x0008D447,
	environment = 0x0008D0FC,
    track = 0x0008D930,
    character  = 0x00086E84,
    lap = 0x001FFE38
}

local ram_track={  --  abs Penta on Coco Park = 0x001AC795
	[3]  = 0,		[7]  = 6760,	[1]  = 78772,	[6]  = 127784,	[16] = 145852,	[9]  = 162636,
	[5]  = 179844,	[8]  = 188720,	[0]  = 197572,	[13] = 200000,	[10] = 211044,	[12] = 211740,
	[4]  = 211932,	[15] = 212564,	[11] = 213252,	[2]  = 214872,	[14] = 215340,	[17] = 224656
}

local ram_racer_timetrial={		--	(char_number -> relative adress)		abs speed Penta on Dingo Canyon=0x001DAE1FD
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
	
	local adress = TIMETRIAL_ADRESS + ram_track[track_number] + ram_racer_timetrial[racer_number]
	local absSpeed = mainmemory.read_u8(adress)
	local horiSpeed = mainmemory.read_s8(adress+2)
	local vertSpeed = mainmemory.read_s8(adress+4)
	local turboReserves = mainmemory.read_u16_le(adress+85)
	local slideTimer = mainmemory.read_u16_le(adress+79)
	local absPos = mainmemory.read_u8(adress+252)
	local absSubPos = mainmemory.read_u8(adress+251)
	local maxAbsPos = mainmemory.read_u8(adress+256)
	local maxAbsSubPos = mainmemory.read_u8(adress+255)
	local jumpTimer = mainmemory.read_u16_le(adress+111)
	local landing = mainmemory.read_u8(adress+99)
    
	scaled_text(83, 60, string.format("Abs. Sp. = %d", absSpeed))
	scaled_text(88.5, 85, string.format("%3d", horiSpeed), "red")
	scaled_text(83, 62.5, string.format("Vrt. Sp. = %d", vertSpeed))
	scaled_text(78, 92, string.format("Turbo %d/32767", turboReserves))
	scaled_text(78.75, 86, string.format("%5d", slideTimer))
	scaled_text(40, 00, string.format("%3d.%02x/%3d.%02x", absPos, absSubPos, maxAbsPos, maxAbsSubPos))
	scaled_text(86.75, 78, string.format("%5d", jumpTimer))
	scaled_text(89, 80.5, string.format("%3d", landing))
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
