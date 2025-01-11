--
-- FS25 - TodoList
--
-- @Author: Ozz
-- @Date: 24.11.2024
-- @Version: 1.0.0.0
--
-- Changelog:
--  v1.0.0.0 (26.02.2022):
--  - Initial Release
--
math.randomseed(g_time or os.clock())

TodoList = {}
TodoList.dir = g_currentModDirectory
TodoList.modName = g_currentModName

source(TodoList.dir .. "gui/InGameMenuTodoList.lua")
source(TodoList.dir .. "gui/ManageGroupsFrame.lua")

function TodoList:loadMap()

    MessageType.ACTIVE_TASKS_UPDATED = nextMessageTypeId()
    MessageType.GROUPS_UPDATED = nextMessageTypeId()

    g_gui:loadProfiles(TodoList.dir .. "gui/guiProfiles.xml")

    local guiTodoList = InGameMenuTodoList.new(g_i18n)
    g_gui:loadGui(TodoList.dir .. "gui/InGameMenuTodoList.xml", "inGameMenuTodoList", guiTodoList, true)

    local manageGroupsFrame = ManageGroupsFrame.new(g_i18n)
	g_gui:loadGui(TodoList.dir .. "gui/ManageGroupsFrame.xml", "manageGroupsFrame", manageGroupsFrame)	

    TodoList.fixInGameMenu(guiTodoList,"inGameMenuTodoList", {0,0,1024,1024}, 2, TodoList:makeIsTodoListCheckEnabledPredicate())

    g_currentMission.todoList = self
	self.groups = {}
    self.activeTasks = {}
    -- self.currentMonth = math.floor(g_currentMission.environment.currentPeriod)
    self.currentMonth = 5 -- TODO = replace

    -- TODO - remove below synthetic data
    local group1Id = g_currentMission.todoList:generateId()
    self.groups[group1Id] = {
        id = group1Id,
        farmId = 1,
        name = "field 1",
        tasks = {}
    }

    local task1Id = g_currentMission.todoList:generateId()
    local task2Id = g_currentMission.todoList:generateId()
    self.groups[group1Id].tasks[task1Id] = {
        id = task1Id,
        detail = "harvest",
        priority = 1,
        month = 6,
        completed = false,
        overdue = false
    }
    self.groups[group1Id].tasks[task2Id] = {
        id = task2Id,
        detail = "mulch",
        priority = 2,
        month = 6,
        completed = false,
        overdue = false
    }

    local group2Id = g_currentMission.todoList:generateId()
    self.groups[group2Id] = {
        id = group2Id,
        farmId = 1,
        name = "field 2",
        tasks = {}
    }
    local task3Id = g_currentMission.todoList:generateId()
    local task4Id = g_currentMission.todoList:generateId()
    self.groups[group2Id].tasks[task3Id] = {
        id = task3Id,
        detail = "harvest",
        priority = 1,
        month = 6,
        completed = false,
        overdue = false
    }
    self.groups[group2Id].tasks[task4Id] = {
        id = task4Id,
        detail = "mulch",
        priority = 2,
        month = 6,
        completed = false,
        overdue = false
    }

    guiTodoList:initialize()
end


function TodoList:makeIsTodoListCheckEnabledPredicate()
    return function () return true end
end

-- from Courseplay
function TodoList.fixInGameMenu(frame,pageName,uvs,position,predicateFunc)
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local targetPosition = 0

    -- remove all to avoid warnings
    for k, v in pairs({pageName}) do
        inGameMenu.controlIDs[v] = nil
    end

    for i = 1, #inGameMenu.pagingElement.elements do
		local child = inGameMenu.pagingElement.elements[i]
		if child == inGameMenu["pageSettings"] then
			targetPosition = i;
			break
		end
	end

	if targetPosition == 0 then
		targetPosition = position
	end

    inGameMenu[pageName] = frame
    inGameMenu.pagingElement:addElement(inGameMenu[pageName])

    inGameMenu:exposeControlsAsFields(pageName)

    for i = 1, #inGameMenu.pagingElement.elements do
        local child = inGameMenu.pagingElement.elements[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.elements, i)
            table.insert(inGameMenu.pagingElement.elements, targetPosition, child)
            break
        end
    end

    for i = 1, #inGameMenu.pagingElement.pages do
        local child = inGameMenu.pagingElement.pages[i]
        if child.element == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.pages, i)
            table.insert(inGameMenu.pagingElement.pages, targetPosition, child)
            break
        end
    end

    inGameMenu.pagingElement:updateAbsolutePosition()
    inGameMenu.pagingElement:updatePageMapping()

    inGameMenu:registerPage(inGameMenu[pageName], position, predicateFunc)
    local iconFileName = Utils.getFilename('images/menuIcon.dds', TodoList.dir)
    inGameMenu:addPageTab(inGameMenu[pageName],iconFileName, GuiUtils.getUVs(uvs))

    for i = 1, #inGameMenu.pageFrames do
        local child = inGameMenu.pageFrames[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pageFrames, i)
            table.insert(inGameMenu.pageFrames, targetPosition, child)
            break
        end
    end

    inGameMenu:rebuildTabList()
end

function TodoList:hourChanged()
    print("Hour changed received")
    local month = math.floor(g_currentMission.environment.currentPeriod)
    if month ~= g_currentMission.todoList.currentMonth then
        g_currentMission.todoList:onMonthChanged()
    end
end

function TodoList:onMonthChanged()
    print("Month changed, updating tasks")
    for _, task in pairs(self.activeTasks) do
        task.overdue = true
    end

    for _, group in pairs(self.groups) do
        self:addGroupTasksForCurrentMonth(group)
    end
    g_currentMission.todoList.currentMonth = math.floor(g_currentMission.environment.currentPeriod)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end

function TodoList:addGroupTasksForCurrentMonth(group)
    local currentMonth = math.floor(g_currentMission.environment.currentPeriod)
    for _, task in pairs(group.tasks) do
        if task.month == currentMonth then
            local taskCopy = deepcopy(task)
            taskCopy.groupName = group.name
            -- table.insert(self.activeTasks, taskCopy)
            self.activeTasks[task.id] = taskCopy
        end
    end
end

function TodoList:getActiveTasksForCurrentFarm()
    local result = {}
    for _, task in pairs(self.activeTasks) do
        if task.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            local taskCopy = deepcopy(task)
            table.insert(result, taskCopy)
        end
    end
    return result
end

function TodoList:getTasksForMonthForCurrentFarm(month)
    local result = {}
    for _, group in pairs(self.groups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            for _, task in pairs(group.tasks) do
                if task.month == month then
                    local taskCopy = deepcopy(task)
                    taskCopy.groupName = group.name
                    table.insert(result, taskCopy)
                end
            end
        end
    end
	return result
end

function TodoList:completeTask(taskId)
    local task = self.activeTasks[taskId]
    if task == nil then
        InfoDialog.show(g_i18n:getText("ui_task_not_found_error"))
        return
    end

    self.activeTasks[taskId] = nil
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end

function TodoList:deleteGroup(groupId)
    local group = self.groups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    -- Remove any active tasks for the group
    for _, task in pairs(group.tasks) do
        self.activeTasks[task.id] = nil
    end

    -- Remove the group
    self.groups[groupId] = nil

    -- Notify changes
    g_messageCenter:publish(MessageType.GROUPS_UPDATED)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end

function TodoList:getGroupListForCurrentFarm()
    local currentFarmId = self:getCurrentFarmId()
    local result = {}
    for k, group in pairs(self.groups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            table.insert(result, {
                id = group.id,
                name = group.name
            })
        end
    end
    return result
end


function TodoList:groupExistsForCurrentFarm(name)
    local currentFarmId = self:getCurrentFarmId()
    for _, group in pairs(self.groups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            if group.name == name then
                return true
            end
        end
    end
    return false
end

function TodoList:addGroupForCurrentFarm(name)
    local currentFarmId = self:getCurrentFarmId()
    local nextId = g_currentMission.todoList:generateId()
    self.groups[nextId] = {
        id = nextId,
        farmId = currentFarmId,
        name = name,
        tasks = {}
    }
    g_messageCenter:publish(MessageType.GROUPS_UPDATED)
end

function TodoList:copyGroupForCurrentFarm(newName, groupToCopyId)
    local currentFarmId = self:getCurrentFarmId()

    -- Sanity check the group exists
    local sourceGroup = self.groups[groupToCopyId]
    if sourceGroup == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    -- Create a new group table
    local nextId = g_currentMission.todoList:generateId()
    local newGroup = {
        id = nextId,
        farmId = currentFarmId,
        name = newName,
        tasks = {}
    }

    -- Copy tasks with new ids and add to the group
    for _, task in pairs(sourceGroup.tasks) do
        local nextTaskId = g_currentMission.todoList:generateId()
        local taskCopy = deepcopy(task)
        taskCopy.id = nextTaskId
        newGroup.tasks[nextTaskId] = taskCopy
    end

    self.groups[nextId] = newGroup

    -- Add any tasks for the current month to activeTasks
    self:addGroupTasksForCurrentMonth(newGroup)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    g_messageCenter:publish(MessageType.GROUPS_UPDATED)

    -- for _, group in pairs(self.groups) do
    --     if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
    --         if group.name == toCopy then
    --             local newGroup = {
    --                 farmId = currentFarmId,
    --                 name = newName,
    --                 tasks = deepcopy(group.tasks)
    --             }
    --             table.insert(self.groups, newGroup)
    --             self:addGroupTasksForCurrentMonth(newGroup)
    --             g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    --             g_messageCenter:publish(MessageType.GROUPS_UPDATED)
    --             return
    --         end
    --     end
    -- end
    -- InfoDialog.show(g_i18n:getText("ui_copy_group_failed_error"))
end

function TodoList:getCurrentFarmId()
    local currentFarmId = -1
    local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if farm ~= nil then
        return farm.farmId
    end
    return currentFarmId -- Not sure can happen!
end

function TodoList:generateId()
    local template ='xxxxxxxx-xxxx-xxxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end




g_messageCenter:subscribe(MessageType.HOUR_CHANGED, TodoList.hourChanged)
addModEventListener(TodoList)