-- The list of possible hotkeys are here: http://tasvideos.org/Lsnes/Keys.html
-- CONFIGURATION: change the hotkeys and modifiers, with acceptable values


local HOTKEYS = {  -- use the nil value to not bind a hotkey
    increase_emulator_speed = "equals",
    decrease_emulator_speed = "minus",
    
    toggle_background_layer_1 = "1",
    toggle_background_layer_2 = "2",
    toggle_background_layer_3 = "3",
    toggle_background_layer_4 = "4",
    toggle_sprite_layer_0 = "5",
    toggle_sprite_layer_1 = "6",
    toggle_sprite_layer_2 = "7",
    toggle_sprite_layer_3 = "8",
}

local MODIFIERS = {  -- must be a subset of [alt,ctrl,shift,meta], in this particular order. Example: "alt,shift"  , ""  , "ctrl"
    increase_emulator_speed = "ctrl",
    decrease_emulator_speed = "ctrl",
    
    toggle_background_layer_1 = "alt",
    toggle_background_layer_2 = "alt",
    toggle_background_layer_3 = "alt",
    toggle_background_layer_4 = "alt",
    toggle_sprite_layer_0 = "alt",
    toggle_sprite_layer_1 = "alt",
    toggle_sprite_layer_2 = "alt",
    toggle_sprite_layer_3 = "alt",
}

local OVERWRITE_PREVIOUS_BINDINGS = false  -- make it true, to overwrite a previous binding already associated with a hotkey/modifier


--#############################################################################
-- Things that you probably should NOT touch


local MASK = "alt,ctrl,shift,meta"  -- the list of modifiers that matter. Each value in MODIFIERS must be a subset of MASK

local commands = {
    increase_emulator_speed = [[L local speed, new = settings.get_speed(), nil local fps = movie.get_game_info().fps local values = {1/1000, 1/200, 1/100, 1/fps, 1/20, 1/10, 1/5, 1/4, 1/3, 1/2, 1, 1.5, 2, 3, 5, 10} if speed == 'turbo' or speed >= values[#values] then new = 'turbo' else for k, v in ipairs(values) do if speed >= v and speed < values[k + 1] then new = values[k + 1] break end end end print('Setting the speed to ' .. new) settings.set_speed(new)]],
    decrease_emulator_speed = [[L local speed, new = settings.get_speed(), nil local fps = movie.get_game_info().fps local values = {1/1000, 1/200, 1/100, 1/fps, 1/20, 1/10, 1/5, 1/4, 1/3, 1/2, 1, 1.5, 2, 3, 5, 10} if speed == 'turbo' then new = values[#values] else new = values[1] for k, v in ipairs(values) do if v < speed and speed <= (values[k + 1] or values[#values]) then new = v break end end end print('Setting the speed to ' .. new) settings.set_speed(new)]],
    
    toggle_background_layer_1 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local bg0 = memory.action_flags("bg1pri0") >= 2 local bg1 = memory.action_flags("bg1pri1") >= 2 memory.action("bg1pri0") if bg1 == bg0 then memory.action("bg1pri1") end print(bg0 and "Deactivating layer 1 visibility." or "Activating layer 1 visibility.")]],
    toggle_background_layer_2 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local bg0 = memory.action_flags("bg2pri0") >= 2 local bg1 = memory.action_flags("bg2pri1") >= 2 memory.action("bg2pri0") if bg1 == bg0 then memory.action("bg2pri1") end print(bg0 and "Deactivating layer 2 visibility." or "Activating layer 2 visibility.")]],
    toggle_background_layer_3 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local bg0 = memory.action_flags("bg3pri0") >= 2 local bg1 = memory.action_flags("bg3pri1") >= 2 memory.action("bg3pri0") if bg1 == bg0 then memory.action("bg3pri1") end print(bg0 and "Deactivating layer 3 visibility." or "Activating layer 3 visibility.")]],
    toggle_background_layer_4 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local bg0 = memory.action_flags("bg4pri0") >= 2 local bg1 = memory.action_flags("bg4pri1") >= 2 memory.action("bg4pri0") if bg1 == bg0 then memory.action("bg4pri1") end print(bg0 and "Deactivating layer 4 visibility." or "Activating layer 4 visibility.")]],
    toggle_sprite_layer_0 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local obj = memory.action_flags("oampri0") >= 2 memory.action("oampri0") print(obj and "Deactivating sprite 0 visibility." or "Activating sprite 0 visibility.")]],
    toggle_sprite_layer_1 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local obj = memory.action_flags("oampri1") >= 2 memory.action("oampri1") print(obj and "Deactivating sprite 1 visibility." or "Activating sprite 1 visibility.")]],
    toggle_sprite_layer_2 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local obj = memory.action_flags("oampri2") >= 2 memory.action("oampri2") print(obj and "Deactivating sprite 2 visibility." or "Activating sprite 2 visibility.")]],
    toggle_sprite_layer_3 = [[L if string.find(movie.get_game_info().core, "bsnes") ~= 1 then return end local obj = memory.action_flags("oampri3") >= 2 memory.action("oampri3") print(obj and "Deactivating sprite 3 visibility." or "Activating sprite 3 visibility.")]],
}


--#############################################################################
-- Bind each hotkey:


local binding_list = list_bindings()

for k, v in pairs(HOTKEYS) do
    local current_bind = (MODIFIERS[k] and MODIFIERS[k] or "") .. "/" .. MASK .. "|" .. HOTKEYS[k]
    
    if next(list_bindings(commands[k])) ~= nil then  -- if this command doesn't have a hotkey
        print("The command <" .. k .. "> is already assigned with the following hotkey(s):")
        for hotkey, cmd in pairs(list_bindings(commands[k])) do
            print(hotkey)
        end
    end
    
    if binding_list[current_bind] == nil then  -- if this hotkey is empty
        --print("Binding key " .. current_bind .. " to command<" .. k .. ">.")
        keyboard.bind(MODIFIERS[k], MASK, HOTKEYS[k], commands[k])
    else
        print("Binding key " .. current_bind .. " is already associated with another task.")
        if OVERWRITE_PREVIOUS_BINDINGS then
            print("Binding key " .. current_bind .. " to command <" .. k .. ">.")
            keyboard.unbind(MODIFIERS[k], MASK, HOTKEYS[k])
            keyboard.bind(MODIFIERS[k], MASK, HOTKEYS[k], commands[k])
        end
    end
    
    print("\n")
end
