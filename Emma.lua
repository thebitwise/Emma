--$$\        $$$$$$\  $$\   $$\  $$$$$$\  $$$$$$$$\ 
--$$ |      $$  __$$\ $$$\  $$ |$$  __$$\ $$  _____|
--$$ |      $$ /  $$ |$$$$\ $$ |$$ /  \__|$$ |      
--$$ |      $$$$$$$$ |$$ $$\$$ |$$ |      $$$$$\    
--$$ |      $$  __$$ |$$ \$$$$ |$$ |      $$  __|   
--$$ |      $$ |  $$ |$$ |\$$$ |$$ |  $$\ $$ |      
--$$$$$$$$\ $$ |  $$ |$$ | \$$ |\$$$$$$  |$$$$$$$$\ 
--\________|\__|  \__|\__|  \__| \______/ \________|
-- coded by Lance/stonerchrist on Discord
pluto_use "0.5.0"
util.require_natives("2944b", "g")
local root = menu.my_root()

local mode = 1
local modes = {"Continuous", "Triangle", "Random", "Pulse: Rapid", "Pulse: Medium", "Pulse: Slow", "Vehicle RPM"}
local num_patterns = #modes
local pattern_selector = root:list_select("Vibration pattern", {"vibrationpattern"}, "Some patterns will delay this setting from activating. If you do not immediately notice a pattern, give it a few to kick in.", modes, 1, function(index, value)
    mode = index
end)

local stren = 255
local strength_setter = root:slider("Vibration strength", {"vibrationstrength"}, "In other words, the frequency. Will not work on patterns that dynamically change frequency.", 10, 255, 255, 1, function(val)
    stren = val
end)

local vib_toggle = root:toggle_loop("Vibrate", {"vibrate"}, "Yes.", function()
    local mode = tonumber(mode)
    switch mode do
        case 1:
            SET_CONTROL_SHAKE(0, 10, stren)
            break
        case 2:
            for i=10, 255 do
                SET_CONTROL_SHAKE(0, 100, i)
                util.yield(10)
            end
            break
        case 3: 
            SET_CONTROL_SHAKE(0, 100, math.random(10, 255))
            break
        case 4:
            SET_CONTROL_SHAKE(0, 100, stren)
            util.yield(300)
            break
        case 5:
            SET_CONTROL_SHAKE(0, 100, stren)
            util.yield(500)
            break
        case 6:
            SET_CONTROL_SHAKE(0, 100, stren)
            util.yield(1000)
            break
        case 7:
            local user_cur_car = entities.get_user_vehicle_as_pointer()
            if user_cur_car ~= 0 then 
                local rpm = math.ceil(entities.get_rpm(user_cur_car)*255)
                if rpm < 10 then 
                    rpm = 10
                end
                util.draw_debug_text(rpm)
                SET_CONTROL_SHAKE(0, 100, rpm)
                break
                util.yield(100)
            end
    end
end)

local chatcomms_root = root:list("Chat Commands", {}, "Configure chat command settings.")

local chat_comms = false
chatcomms_root:toggle("Chat commands", {}, "", function(on)
    chat_comms = on
end, false)

local cc_friend_only = true
chatcomms_root:toggle("Friends only", {}, "Only allow friends to send chat commands", function(on)
    cc_friend_only = on
end, true)

local cc_max_duration_secs = 5
chatcomms_root:slider("Max duration", {}, "The max duration players can request your controller to vibrate for, in seconds", 1, 300, 5, 1, function(val)
    cc_max_duration_secs = val
end)

local cc_cooldown = 1000
chatcomms_root:slider("Command cooldown", {}, "The cooldown each user will have to wait between sending each command, in milliseconds.", 1, 120000, 1000, 1, function(val)
    cc_cooldown = val
end)

local chat_prefixes = {'-', '\\', "'", ">"}
local command_chat_prefix = '-'
chatcomms_root:list_select("Command prefix", {}, "", chat_prefixes, 1, function(index, value)
    command_chat_prefix = value
end)

local valid_chat_commands = {"vibrate", "setpattern", "setstrength"}
chatcomms_root:action("Announce chat commands", {}, "", function()
    chat.send_message("> I am running Emma.lua. Its valid commands are " .. command_chat_prefix .. table.concat(valid_chat_commands, ', ' .. command_chat_prefix) .. ', followed by a number.', false, true, true)
end)


local handle_ptr = memory.alloc(13*8)
local function pid_to_handle(pid)
    NETWORK_HANDLE_FROM_PLAYER(pid, handle_ptr, 13)
    return handle_ptr
end

local cooldown_players = {}
chat.on_message(function(sender, reserved, text, team_chat, networked, is_auto)
    local is_friend = true
    if not chat_comms then 
        return 
    end
    local hdl = pid_to_handle(sender)
    if not NETWORK_IS_FRIEND(hdl) then
        is_friend = false
    end

    if players.user() ~= sender and not is_friend then 
        if cc_friend_only then 
            return 
        end
    end

    if cooldown_players[sender] ~= nil then 
        return 
    end

    if text:startswith(command_chat_prefix) then
        local command = text:split(' ')
        if #command ~= 2 then 
            chat.send_message("> Invalid number of arguments", false, true, true)
            return
        end
        command[1] = string.lower(command[1]):gsub(command_chat_prefix, '')
        if not table.contains(valid_chat_commands, command[1]) then 
            chat.send_message("> Not a valid command. Valid commands are " .. table.concat(valid_chat_commands, ', '), false, true, true)
            return 
        end

        switch command[1] do
            case 'setpattern':
                local pattern_tn = tonumber(command[2])
                if pattern_tn == nil or pattern_tn > num_patterns or pattern_tn < 0 then 
                    chat.send_message("> Pattern must be an integer from 0 to " .. num_patterns, false, true, true)
                    return 
                end
            
                chat.send_message("> Pattern set to \"" .. modes[pattern_tn].. "\".", false, true, true)
                menu.set_value(pattern_selector, pattern_tn)
                break 
            case 'setstrength':
                local stren = tonumber(command[2])
                if stren == nil or stren > 255 or stren < 10 then 
                    chat.send_message("> Strength must be an integer from 10 to 255", false, true, true)
                    return 
                end
            
                chat.send_message("> Strength set to " .. stren .. ".", false, true, true)
                menu.set_value(strength_setter, stren)
                break 
            case 'vibrate':
                local duration = tonumber(command[2])
                if duration == nil or duration > cc_max_duration_secs or duration < 1 then 
                    chat.send_message("> Duration must be an integer from 1 to " .. cc_max_duration_secs, false, true, true)
                    return 
                end
                if menu.get_value(vib_toggle) then 
                    chat.send_message("> Vibration is already active.", false, true, true)
                    return 
                else
                    chat.send_message("> Now running vibration for " .. duration .. " seconds.", false, true, true)
                    menu.set_value(vib_toggle, true)
                    util.yield(duration * 1000)
                    menu.set_value(vib_toggle, false)
                end
                break 

        end
        cooldown_players[sender] = true 
        util.yield(cc_cooldown)
        cooldown_players[sender] = nil
    end
end)

util.keep_running()


menu.my_root():divider('')
menu.my_root():hyperlink('Join Discord', 'https://discord.gg/zZ2eEjj88v', '')
