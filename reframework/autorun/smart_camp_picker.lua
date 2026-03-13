local MOD_NAME = "Smart Camp Picker"
local CONFIG_PATH = "SmartCampPicker/config.json"

local config = { enabled = true }

local function load_config()
    local ok, data = pcall(json.load_file, CONFIG_PATH)
    if ok and data and type(data.enabled) == "boolean" then
        config.enabled = data.enabled
    end
end

local function save_config()
    pcall(json.dump_file, CONFIG_PATH, config)
end

local function find_method(type_name, method_name)
    local td = sdk.find_type_definition(type_name)
    if not td then error("Type not found: " .. type_name) end
    local m = td:get_method(method_name)
    if not m then error("Method not found: " .. type_name .. "::" .. method_name) end
    return m
end

local function safe_hook(method, pre, post)
    local wrapped_pre = pre and function(args)
        local ok, result = pcall(pre, args)
        if not ok then return sdk.PreHookResult.CALL_ORIGINAL end
        return result
    end

    local wrapped_post = post and function(retval)
        local ok, result = pcall(post, retval)
        if not ok then return retval end
        return result
    end

    sdk.hook(method, wrapped_pre, wrapped_post)
end

local navmesh_data = {}
for stage = 0, 4 do
    local data = json.load_file("SmartCampPicker/navmesh_distances/stage_" .. stage .. ".json")
    if data and data.areas then
        navmesh_data[stage] = {}
        for area_key, area_data in pairs(data.areas) do
            navmesh_data[stage][area_key] = area_data.distances
        end
    end
end

local function lookup_distance(target_stage, target_area, camp_id)
    local stage_data = navmesh_data[target_stage]
    if not stage_data then return nil end
    local area_distances = stage_data[tostring(target_area)]
    if not area_distances then return nil end
    return area_distances[tostring(camp_id)]
end

load_config()

local ok, err = pcall(function()
    local initStartPoint = find_method("app.GUI050001", "initStartPoint()")
    local initStartPointList = find_method("app.GUI050001_StartPointList", "initStartPointList()")
    local onClose = find_method("app.GUI050001", "onClose()")
    local onVisibleUpdate = find_method("app.GUI050001_AcceptList", "onVisibleUpdate()")

    local hook_storage = {
        quest_accept_ui = nil,
        start_point_list = nil,
        accept_list = nil,
        target_camp_index = nil,
        need_apply = false,
    }

    local function reset_hook_storage()
        hook_storage.quest_accept_ui = nil
        hook_storage.start_point_list = nil
        hook_storage.accept_list = nil
        hook_storage.target_camp_index = nil
        hook_storage.need_apply = false
    end

    local function get_target_info(quest_accept_ui)
        local quest_view_data = quest_accept_ui:get_QuestOrderParam().QuestViewData
        local target_em_start_areas = quest_view_data:get_TargetEmStartArea()
        local areas = {}
        for _, start_area in pairs(target_em_start_areas) do
            if start_area and start_area.m_value ~= nil then
                table.insert(areas, start_area.m_value)
            end
        end
        if #areas == 0 then return nil, nil end

        local stage = quest_view_data:get_Stage()
        return stage, areas
    end

    local function find_nearest_camp_index()
        if not hook_storage.quest_accept_ui then return nil end

        local stage, target_areas = get_target_info(hook_storage.quest_accept_ui)
        if not stage or not target_areas then return nil end

        local sp_list = hook_storage.quest_accept_ui:get_CurrentStartPointList()
        if not sp_list or sp_list._size < 2 then return nil end

        local has_typed_camp = {}
        for idx = 0, sp_list._size - 1 do
            local sp = sp_list._items[idx]
            if not sp then goto scan end
            local ok_t, t = pcall(function() return sp:get_Type() end)
            if ok_t and t and t ~= 0 then
                has_typed_camp[sp.CampID] = true
            end
            ::scan::
        end

        local best_visible_idx = nil
        local best_dist = math.huge
        local visible_idx = 0

        for idx = 0, sp_list._size - 1 do
            local sp = sp_list._items[idx]
            if not sp then goto continue end

            local ok_t, sp_type = pcall(function() return sp:get_Type() end)
            if ok_t and sp_type == 0 and has_typed_camp[sp.CampID] then
                goto continue
            end

            local min_dist = nil
            for _, area in ipairs(target_areas) do
                local d = lookup_distance(stage, area, sp.CampID)
                if d and (not min_dist or d < min_dist) then
                    min_dist = d
                end
            end

            if min_dist and min_dist < best_dist then
                best_dist = min_dist
                best_visible_idx = visible_idx
            end

            visible_idx = visible_idx + 1

            ::continue::
        end

        return best_visible_idx
    end

    local function calculate_target()
        local target_index = find_nearest_camp_index()
        if target_index ~= nil then
            hook_storage.target_camp_index = target_index
            hook_storage.need_apply = true
        end
    end

    safe_hook(initStartPointList, function(args)
        hook_storage.start_point_list = sdk.to_managed_object(args[2])
        return sdk.PreHookResult.CALL_ORIGINAL
    end, function(retval)
        if not config.enabled then return retval end
        calculate_target()
        return retval
    end)

    safe_hook(initStartPoint, function(args)
        reset_hook_storage()
        hook_storage.quest_accept_ui = sdk.to_managed_object(args[2])
        return sdk.PreHookResult.CALL_ORIGINAL
    end, function(retval)
        if not config.enabled or not hook_storage.quest_accept_ui then return retval end

        pcall(function()
            hook_storage.start_point_list = hook_storage.quest_accept_ui._StartPointList
        end)

        calculate_target()

        return retval
    end)

    safe_hook(onVisibleUpdate, function(args)
        if hook_storage.need_apply then
            hook_storage.accept_list = sdk.to_managed_object(args[2])
        end
        return sdk.PreHookResult.CALL_ORIGINAL
    end, function(retval)
        if not hook_storage.need_apply or not hook_storage.quest_accept_ui then return retval end

        local current = 0
        pcall(function()
            current = hook_storage.quest_accept_ui.CurrentSelectStartPointIndex
        end)

        if current == hook_storage.target_camp_index then
            hook_storage.need_apply = false
            return retval
        end

        local set_ok = pcall(function()
            hook_storage.quest_accept_ui:call("setCurrentSelectStartPointIndex(System.Int32)", hook_storage.target_camp_index)
        end)

        if set_ok and hook_storage.accept_list then
            pcall(function()
                hook_storage.accept_list:call("updateStartPointText()")
            end)
        end

        hook_storage.need_apply = false
        return retval
    end)

    safe_hook(onClose, nil, function(retval)
        if hook_storage.quest_accept_ui then
            reset_hook_storage()
        end
        return retval
    end)
end)

if not ok then
    re.on_draw_ui(function()
        if imgui.tree_node(MOD_NAME) then
            imgui.text_colored("Init failed: " .. tostring(err), 0xFF4040FF)
            imgui.tree_pop()
        end
    end)
    return
end

re.on_draw_ui(function()
    if imgui.tree_node(MOD_NAME) then
        local chk, val = imgui.checkbox("Enabled", config.enabled)
        if chk then
            config.enabled = val
            save_config()
        end
        imgui.tree_pop()
    end
end)

re.on_config_save(save_config)
