-- Compatibility:
gui.pixelText = gui.pixelText or gui.drawText  -- for old versions of BizHawk

-- Definitions:

local IWRAM = {
  trueFrameCounter = 0x2bc2, -- 1 byte
  effectiveFrameCounter = 0x2bc3, -- 1 byte
  cameraX = 0x2bf0, -- 2 bytes
  cameraY = 0x2bf4, -- 2 bytes
  gameClock = 0x54c6, -- 1 byte
  
  marioDirection = 0x3f91, -- 1 byte unsigned
  marioSubspeed = 0x3f94, --1 byte unsigned
  marioXSpeed = 0x3f95, -- 1 byte signed
  marioYSpeed = 0x3f99, -- 1 byte signed
  marioXPosition = 0x3fbc, -- 2 bytes signed
  marioYPosition = 0x3fc0, -- 2 bytes signed
  marioXSubpixel = 0x3fc8, -- 1 byte unsigned
  marioYSubpixel = 0x3fca, -- 1 byte unsigned
  marioPMeter = 0x3fd2, -- 1 byte unsigned
  marioInvincibility = 0x4015, -- 1 byte
  marioTakeoffMeter = 0x401d, -- 1 byte unsigned
  marioPowerup = 0x42e8, -- 1 byte
  
  -- cape
  capeFallPose = 0x3ffa, -- 1 byte
  capeAirCaught = 0x3ffc, -- 1 byte signed
  capeFallTimer = 0x4023, -- 1 byte
  capeSpinTimer = 0x4024, -- 1 byte unsigned
  
  -- timers
  bluePSwitchTimer = 0x402b, -- 1 byte
}

local sprite_colors = {
  [0] = "red", "blue", "green", "yellow", "magenta", "cyan", "violet", "purple", "gold", "orange", "brown", "darkblue"
}

local spriteBlockOffset = 0x36e4
local spriteBlockSize = 100

-- Functions:

local function DisplayClock()
  local trueFrame = mainmemory.read_u8(IWRAM.trueFrameCounter)
  local effectiveFrame = mainmemory.read_u8(IWRAM.effectiveFrameCounter)
  local gameClock = mainmemory.read_u8(IWRAM.gameClock)
  
  gui.text(client.bufferwidth(), 0, string.format("Frame %d, %d", trueFrame, effectiveFrame))
  gui.pixelText(155, 1, gameClock, "red", "black")
end

local function DisplaySpriteInfo()
  local xText, yText, yDelta = client.bufferwidth(), 64, 14
  local cameraX = mainmemory.read_s16_le(IWRAM.cameraX)
  local cameraY = mainmemory.read_s16_le(IWRAM.cameraY)
  
  for slot = 0, 11 do
    local offset = spriteBlockOffset + slot*spriteBlockSize
    local spriteStatus = mainmemory.read_u8(offset + 0x1c)
    
    if spriteStatus ~= 0 then
      local spriteNumber = mainmemory.read_u8(offset + 0x1a)
      local spriteXSpeed = mainmemory.read_s16_le(offset + 0x09)/16
      local spriteYSpeed = mainmemory.read_s16_le(offset + 0x0d)/16
      local spriteXPosition = mainmemory.read_s16_le(offset + 0x02)
      local spriteYPosition = mainmemory.read_s16_le(offset + 0x06)
      local spriteXSubpixel = mainmemory.read_u8(offset + 0x01)
      local spriteYSubpixel = mainmemory.read_u8(offset + 0x05)
      local spriteStunTime = mainmemory.read_u8(offset + 0x22)
      local spriteReleaseTime = mainmemory.read_u8(offset + 0x23)
      
      -- display
      gui.text(xText, yText, string.format("%d: %s(%.2x, %x) %d.%.2x[%d] %d.%.2x[%d]",
        slot, spriteStunTime == 0 and "" or spriteStunTime, spriteNumber, spriteStatus,
        spriteXPosition, spriteXSubpixel, spriteXSpeed, spriteYPosition, spriteYSubpixel, spriteYSpeed),
        sprite_colors[slot] or "white"
      )
      yText = yText + yDelta
      
      local nextSpriteStr = string.format("#%d%s", slot, spriteReleaseTime == 0 and "" or " " .. spriteReleaseTime)
      gui.pixelText(spriteXPosition - cameraX, spriteYPosition - cameraY, nextSpriteStr, sprite_colors[slot] or "white")
    end
  end
end

local function DisplayTimers()
  local xText, yText, height = 0, 160, 14
  local format = string.format
  local read = mainmemory.read_u8
  
  local effectiveFrame = mainmemory.read_u8(IWRAM.effectiveFrameCounter)
  
  local DisplayCounter = function(label, address, default, mult, frame, color)
    local value = read(address)
    
    if value == default then return end
    yText = yText + height
    local color = color or 0xffffffff
    
    gui.text(xText, yText, format("%s: %d", label, (value * mult) - frame), color)
  end
  
  DisplayCounter("Invinc.", IWRAM.marioInvincibility, 0, 1, 0)
  DisplayCounter("Pow", IWRAM.bluePSwitchTimer, 0, 4, effectiveFrame % 4, "blue")
end

local function DisplayMarioInfo()
  local xText, yText, yDelta = 0, 64, 14
  
  local marioPowerup = mainmemory.read_u8(IWRAM.marioPowerup)
  local marioXPosition = mainmemory.read_s16_le(IWRAM.marioXPosition)
  local marioYPosition = mainmemory.read_s16_le(IWRAM.marioYPosition)
  local marioXSubpixel = mainmemory.read_u8(IWRAM.marioXSubpixel)
  local marioYSubpixel = mainmemory.read_u8(IWRAM.marioYSubpixel)
  local marioXSpeed = mainmemory.read_s8(IWRAM.marioXSpeed)
  local marioYSpeed = mainmemory.read_s8(IWRAM.marioYSpeed)
  local marioPMeter = mainmemory.read_u8(IWRAM.marioPMeter)
  local marioTakeoffMeter = mainmemory.read_u8(IWRAM.marioTakeoffMeter)
  local marioDirection = mainmemory.read_u8(IWRAM.marioDirection)
  local marioSubspeed = mainmemory.read_u8(IWRAM.marioSubspeed)
  local cameraX = mainmemory.read_s16_le(IWRAM.cameraX)
  local cameraY = mainmemory.read_s16_le(IWRAM.cameraY)
  
  gui.text(xText, yText, string.format("Meter %d, %d %s", marioPMeter, marioTakeoffMeter, marioDirection == 0 and "<-" or "->"))
  yText = yText + yDelta
  gui.text(xText, yText, string.format("Pos %d.%.2x, %d.%.2x", marioXPosition, marioXSubpixel, marioYPosition, marioYSubpixel))
  yText = yText + yDelta
  gui.text(xText, yText, string.format("Speed %+2d%s, %d", marioXSpeed, marioSubspeed == 0 and "" or "*", marioYSpeed))
  yText = yText + yDelta
  
  if marioPowerup == 2 then
    local capeFallPose = mainmemory.read_u8(IWRAM.capeFallPose)
    local capeAirCaught = mainmemory.read_s8(IWRAM.capeAirCaught)
    local capeFallTimer = mainmemory.read_u8(IWRAM.capeFallTimer)
    local capeSpinTimer = mainmemory.read_u8(IWRAM.capeSpinTimer)
    
    gui.text(xText, yText, string.format("Cape (%d, %d)/(%d, %d)", capeSpinTimer, capeFallTimer, capeFallPose, capeAirCaught), "gold")
    yText = yText + yDelta
  end
  
  gui.text(xText, yText, string.format("Camera %d, %d", cameraX, cameraY))
end

-- Callbacks and settings
if client.SetClientExtraPadding then  -- check it, because of old versions of BizHawk
  client.SetClientExtraPadding(0, 0, 324, 0)
end

event.onexit(function()
  if client.SetClientExtraPadding then  -- check it, because of old versions of BizHawk
    client.SetClientExtraPadding(0, 0, 0, 0)
  end
end)

while true do
  DisplayClock()
  DisplayMarioInfo()
  DisplaySpriteInfo()
  DisplayTimers()
  
  emu.frameadvance()
end
