ManageTasksFrame = {}
ManageTasksFrame.availableGroups = {}
local ManageTasksFrame_mt = Class(ManageTasksFrame, MessageDialog)
ManageTasksFrame.groupSortingFunction = function(k1, k2) return k1.name < k2.name end

function ManageTasksFrame.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or ManageTasksFrame_mt)
    self.i18n = g_i18n
    self.selectedTaskIndex = -1
    self.currentGroupId = -1
    self.isEdit = false
    return self
end

function ManageTasksFrame:onCreate()
    ManageTasksFrame:superClass().onCreate(self)
end

function ManageTasksFrame:onGuiSetupFinished()
    ManageTasksFrame:superClass().onGuiSetupFinished(self)
    self.tasksTable:setDataSource(self)
    self.tasksTable:setDelegate(self)
end

function ManageTasksFrame:onOpen()
    ManageTasksFrame:superClass().onOpen(self)
    self.currentGroupId = -1
    self.selectedTaskIndex = -1

    g_messageCenter:subscribe(MessageType.TASK_GROUPS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    self:updateContent()
    FocusManager:setFocus(self.groupSelector)
end

function ManageTasksFrame:onClose()
    ManageTasksFrame:superClass().onClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function ManageTasksFrame:updateContent()
    local farmGroups = g_currentMission.taskList:getGroupListForCurrentFarm()
    -- Limit shown groups to templates or standard groups
    self.availableGroups = {}
    for _, group in pairs(farmGroups) do
        if group.type ~= TaskGroup.GROUP_TYPE.TemplateInstance then
            table.insert(self.availableGroups, group)
        end
    end

    table.sort(self.availableGroups, ManageTasksFrame.groupSortingFunction)

    local texts = {}
    for _, group in pairs(self.availableGroups) do
        table.insert(texts, group.name)
    end
    self.groupSelector:setTexts(texts)

    -- Check there are any groups
    if next(self.availableGroups) == nil then
        self.tasksContainer:setVisible(false)
        self.noTasksContainer:setVisible(false)
        self.noGroupsContainer:setVisible(true)
        return
    end

    self.noGroupsContainer:setVisible(false)

    -- If there are groups but the currentGroupId is not there, find one to show
    self.currentGroup = g_currentMission.taskList:getGroupById(self.currentGroupId, false)
    if self.currentGroup == nil then
        for i, group in pairs(self.availableGroups) do
            self.currentGroup = g_currentMission.taskList:getGroupById(group.id, false)
            self.currentGroupId = group.id
            self.groupSelector:setState(i, false)
            break
        end
    end

    -- Check if any tasks on the current Group. If not hide the table and return
    if next(self.currentGroup.tasks) == nil then
        self.tasksContainer:setVisible(false)
        self.noTasksContainer:setVisible(true)
        return
    end
    table.sort(self.currentGroup.tasks, TaskListUtils.taskSortingFunction)

    self.tasksContainer:setVisible(true)
    self.noTasksContainer:setVisible(false)

    self.tasksTable:reloadData()
end

function ManageTasksFrame:getNumberOfSections()
    return 1
end

function ManageTasksFrame:getNumberOfItemsInSection(list, section)
    local count = 0
    for _ in pairs(self.currentGroup.tasks) do count = count + 1 end
    return count
end

function ManageTasksFrame:getTitleForSectionHeader(list, section)
    return ""
end

function ManageTasksFrame:populateCellForItemInSection(list, section, index, cell)
    local task = self.currentGroup.tasks[index]

    cell:getAttribute("detail"):setText(task:getTaskDescription())
    cell:getAttribute("effort"):setText(task:getEffortDescription(self.currentGroup.effortMultiplier))
    cell:getAttribute("priority"):setText(task.priority)
    cell:getAttribute("due"):setText(task:getDueDescription())
end

function ManageTasksFrame:onListSelectionChanged(list, section, index)
    self.selectedTaskIndex = index
end

function ManageTasksFrame:onClickBack(sender)
    self:close()
end

-- New Task Step
function ManageTasksFrame:onClickAdd(sender)
    if self.currentGroupId == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected"))
        return
    end

    local newTask = Task.new()
    self.isEdit = false
    self:onAddEditTaskRequestType(newTask, false)
end

function ManageTasksFrame:onClickEdit(sender)
    if self.currentGroupId == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected"))
        return
    end

    local task = self.currentGroup.tasks[self.selectedTaskIndex]
    if task == nil then
        InfoDialog.show(g_i18n:getText("ui_no_task_selected"))
        return
    end
    self.isEdit = true
    self:onAddEditTaskRequestType(task, false)
end

function ManageTasksFrame:onAddEditTaskRequestType(task, isGoingBack)
    local husbandryCount = 0
    for _ in pairs(g_currentMission.taskList:getHusbandries()) do husbandryCount = husbandryCount + 1 end
    local productionCount = 0
    for _ in pairs(g_currentMission.taskList:getProductions()) do productionCount = productionCount + 1 end
    local totalCount = husbandryCount + productionCount

    if self.currentGroup.type == TaskGroup.GROUP_TYPE.Template or totalCount == 0 then
        -- If we're here after going back, the sequence should end
        if isGoingBack == false then
            self:onAddEditTaskRequestDetail(task)
        end
    else
        local allowedValues = {}
        local lookup = {}
        table.insert(allowedValues, g_i18n:getText("ui_type_standard"))
        lookup[g_i18n:getText("ui_type_standard")] = Task.TASK_TYPE.Standard

        if husbandryCount > 0 then
            table.insert(allowedValues, g_i18n:getText("ui_type_husbandry_food"))
            lookup[g_i18n:getText("ui_type_husbandry_food")] = Task.TASK_TYPE.HusbandryFood
            table.insert(allowedValues, g_i18n:getText("ui_type_husbandry_conditions"))
            lookup[g_i18n:getText("ui_type_husbandry_conditions")] = Task.TASK_TYPE.HusbandryConditions
        end

        if productionCount > 0 then
            table.insert(allowedValues, g_i18n:getText("ui_type_production"))
            lookup[g_i18n:getText("ui_type_production")] = Task.TASK_TYPE.Production
        end

        TaskListUtils.showOptionDialog({
            text = g_i18n:getText("ui_task_request_type_description"),
            title = "",
            defaultText = "",
            options = allowedValues,
            defaultOption = task.type,
            target = self,
            args = {},
            callback = function(_, index)
                if index > 0 then
                    local value = allowedValues[index]
                    task.type = lookup[value]

                    if task.type == Task.TASK_TYPE.Standard then
                        self:onAddEditTaskRequestDetail(task)
                    elseif task.type == Task.TASK_TYPE.HusbandryFood or task.type == Task.TASK_TYPE.HusbandryConditions then
                        self:onAddEditRequestHusbandry(task)
                    elseif task.type == Task.TASK_TYPE.Production then
                        self:onAddEditRequestProduction(task)
                    end
                end
            end
        })
    end
end

function ManageTasksFrame:onAddEditRequestProduction(task)
    local allowedValues = {}
    local lookup = {}
    local default = 1

    for _, production in pairs(g_currentMission.taskList:getProductions()) do
        table.insert(allowedValues, production.name)
        lookup[production.name] = production
        if task:getObjectId() == production.id then
            default = #allowedValues
        end
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_production"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local value = allowedValues[index]
                local production = lookup[value]
                task.objectId = production.id
                self:onAddEditRequestProductionType(task)
            else
                -- Go back
                self:onAddEditTaskRequestType(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestProductionType(task)
    local allowedValues = {
        g_i18n:getText("ui_task_production_input"),
        g_i18n:getText("ui_task_production_output")
    }

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_production_type"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = task.productionType,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.productionType = index
                self:onAddEditRequestProductionFillType(task)
            else
                -- Go back
                self:onAddEditRequestProduction(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestProductionFillType(task)
    local production = g_currentMission.taskList:getProductions()[task:getObjectId()]
    local allowedValues = {}
    local lookup = {}
    local default = 1

    local fillTypes = production.inputs
    if task.productionType == Task.PRODUCTION_TYPE.OUTPUT then
        fillTypes = production.outputs
    end

    for _, fillInfo in pairs(fillTypes) do
        table.insert(allowedValues, fillInfo.title)
        lookup[fillInfo.title] = fillInfo.key
        if task.productionFillType == fillInfo.key then
            default = #allowedValues
        end
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_production_fill_type"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.productionFillType = lookup[allowedValues[index]]
                self:onAddEditRequestConditionEvaluator(task)
            else
                -- Go back
                self:onAddEditRequestProductionType(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestProductionLevel(task)
    local production = g_currentMission.taskList:getProductions()[task:getObjectId()]
    local fillInfo = nil
    if task.productionType == Task.PRODUCTION_TYPE.INPUT then
        fillInfo = production.inputs[task.productionFillType]
    else
        fillInfo = production.outputs[task.productionFillType]
    end

    local allowedValues = {
        g_i18n:getText("ui_task_level_empty"),
        string.format("10%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.10, 0)),
        string.format("20%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.20, 0)),
        string.format("30%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.30, 0)),
        string.format("40%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.40, 0)),
        string.format("50%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.50, 0)),
        string.format("60%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.60, 0)),
        string.format("70%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.70, 0)),
        string.format("80%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.80, 0)),
        string.format("90%% (%s)", g_i18n:formatVolume(fillInfo.capacity * 0.90, 0))
    }
    local default = 1
    if task.productionLevel ~= 0 then
        default = math.floor((task.productionLevel / fillInfo.capacity) * 10) + 1
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_production_level"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local capacity = (index - 1) * 0.10
                task.productionLevel = capacity * fillInfo.capacity
                self:onAddEditTaskJourneyComplete(task)
            else
                -- Go back
                self:onAddEditRequestConditionEvaluator(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestHusbandry(task)
    local allowedValues = {}
    local lookup = {}
    local default = 1

    for _, husbandry in pairs(g_currentMission.taskList:getHusbandries()) do
        local conditionCount = 0
        for _ in pairs(husbandry.conditionInfos) do conditionCount = conditionCount + 1 end
        if task.type == Task.TASK_TYPE.HusbandryConditions and conditionCount == 0 then
            continue
        end

        table.insert(allowedValues, husbandry.name)
        lookup[husbandry.name] = husbandry
        if task:getObjectId() == husbandry.id then
            default = #allowedValues
        end
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_husbandry"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local value = allowedValues[index]
                local husbandry = lookup[value]
                task.objectId = husbandry.id
                if task.type == Task.TASK_TYPE.HusbandryFood then
                    self:onAddEditRequestFoodType(task)
                elseif task.type == Task.TASK_TYPE.HusbandryConditions then
                    self:OnAddEditRequestConditionType(task)
                end
            else
                -- Go back
                self:onAddEditTaskRequestType(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestFoodType(task)
    local husbandry = g_currentMission.taskList:getHusbandries()[task:getObjectId()]
    local allowedValues = { g_i18n:getText("ui_husbandry_food_total") }
    local lookup = {}
    local default = 1
    local defaultMatch = 2
    for _, foodInfo in pairs(husbandry.keys) do
        table.insert(allowedValues, foodInfo.title)
        lookup[foodInfo.title] = foodInfo.key
        if task.husbandryFood == foodInfo.key then
            default = defaultMatch
        end
        defaultMatch = defaultMatch + 1
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_food_type"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                if index == 1 then
                    task.husbandryFood = Task.TOTAL_FOOD_KEY
                else
                    task.husbandryFood = lookup[allowedValues[index]]
                end
                self:onAddEditRequestFoodLevel(task)
            else
                -- Go back
                self:onAddEditRequestHusbandry(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestFoodLevel(task)
    local husbandry = g_currentMission.taskList:getHusbandries()[task:getObjectId()]
    local allowedValues = {
        g_i18n:getText("ui_task_level_empty"),
        string.format("10%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.10, 0)),
        string.format("20%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.20, 0)),
        string.format("30%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.30, 0)),
        string.format("40%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.40, 0)),
        string.format("50%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.50, 0)),
        string.format("60%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.60, 0)),
        string.format("70%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.70, 0)),
        string.format("80%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.80, 0)),
        string.format("90%% (%s)", g_i18n:formatVolume(husbandry.foodCapacity * 0.90, 0))
    }
    local default = 1
    if task.husbandryLevel ~= 0 then
        default = math.floor((task.husbandryLevel / husbandry.foodCapacity) * 10) + 1
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_food_level"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local capacity = (index - 1) * 0.10
                task.husbandryLevel = capacity * husbandry.foodCapacity
                self:onAddEditTaskJourneyComplete(task)
            else
                -- Go back
                self:onAddEditRequestFoodType(task)
            end
        end
    })
end

function ManageTasksFrame:OnAddEditRequestConditionType(task)
    local husbandry = g_currentMission.taskList:getHusbandries()[task:getObjectId()]
    local allowedValues = {}
    local lookup = {}
    local default = 1
    for _, conditionInfo in pairs(husbandry.conditionInfos) do
        table.insert(allowedValues, conditionInfo.title)
        lookup[conditionInfo.title] = conditionInfo.key
        if task.husbandryCondition == conditionInfo.key then
            default = #allowedValues
        end
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_condition_type"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.husbandryCondition = lookup[allowedValues[index]]
                self:onAddEditRequestConditionEvaluator(task)
            else
                -- Go back
                self:onAddEditRequestHusbandry(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestConditionEvaluator(task)
    local allowedValues = {
        g_i18n:getText("ui_task_condition_evaluator_less_than"),
        g_i18n:getText("ui_task_condition_evaluator_greater_than")
    }

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_condition_evaluator"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = task.evaluator,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.evaluator = index
                if task.type == Task.TASK_TYPE.HusbandryConditions then
                    self:onAddEditRequestConditionLevel(task)
                elseif task.type == Task.TASK_TYPE.Production then
                    self:onAddEditRequestProductionLevel(task)
                end
            else
                -- Go back
                if task.type == Task.TASK_TYPE.HusbandryConditions then
                    self:OnAddEditRequestConditionType(task)
                elseif task.type == Task.TASK_TYPE.Production then
                    self:onAddEditRequestProductionFillType(task)
                end
            end
        end
    })
end

function ManageTasksFrame:onAddEditRequestConditionLevel(task)
    local husbandry = g_currentMission.taskList:getHusbandries()[task:getObjectId()]
    local conditionInfo = husbandry.conditionInfos[task.husbandryCondition]
    local allowedValues = {
        g_i18n:getText("ui_task_level_empty"),
        string.format("10%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.10, 0)),
        string.format("20%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.20, 0)),
        string.format("30%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.30, 0)),
        string.format("40%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.40, 0)),
        string.format("50%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.50, 0)),
        string.format("60%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.60, 0)),
        string.format("70%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.70, 0)),
        string.format("80%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.80, 0)),
        string.format("90%% (%s)", g_i18n:formatVolume(conditionInfo.capacity * 0.90, 0))
    }
    local default = 1
    if task.husbandryLevel ~= 0 then
        default = math.floor((task.husbandryLevel / conditionInfo.capacity) * 10) + 1
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_task_request_condition_level"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local capacity = (index - 1) * 0.10
                task.husbandryLevel = capacity * conditionInfo.capacity
                self:onAddEditTaskJourneyComplete(task)
            else
                -- Go back
                self:onAddEditRequestConditionEvaluator(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditTaskRequestDetail(task)
    TextInputDialog.show(
        function(self, value, clickOk)
            if clickOk then
                local detail = string.gsub(value, '^%s*(.-)%s*$', '%1')
                if detail == "" then
                    InfoDialog.show(g_i18n:getText("ui_no_detail_specified_error"))
                    return
                end

                task.detail = detail
                self:onAddEditTaskEffort(task)
            else
                -- Go back
                self:onAddEditTaskRequestType(task, true)
            end
        end, self,
        task.detail,
        g_i18n:getText("ui_set_task_detail"),
        nil, Task.MAX_DETAIL_LENGTH, g_i18n:getText("ui_btn_ok"), nil, nil, false)
end

function ManageTasksFrame:onAddEditTaskEffort(task)
    local allowedValues = { "1", "2", "3", "4", "5" }
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_effort"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = task.effort,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local value = allowedValues[index]
                task.effort = tonumber(value)
                self:onAddEditTaskRequestPriority(task)
            else
                -- Go back
                self:onAddEditTaskRequestDetail(task)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestPriority(task)
    local allowedValues = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_priority"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = task.priority,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local value = allowedValues[index]
                task.priority = tonumber(value)
                self:onAddEditTaskRequestShouldRecur(task)
            else
                -- Go back
                self:onAddEditTaskEffort(task)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestShouldRecur(task)
    local allowedValues = { g_i18n:getText("ui_yes"), g_i18n:getText("ui_no") }
    local default = 1
    if task.shouldRecur == false then
        default = 2
    end
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_should_recur"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.shouldRecur = index == 1
                if task.shouldRecur then
                    self:onAddEditTaskRequestRecurMode(task)
                else
                    self:onAddEditTaskRequestPeriod(task)
                end
            else
                -- Go back
                self:onAddEditTaskRequestPriority(task)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestRecurMode(task)
    local allowedValues = {
        g_i18n:getText("ui_set_task_recur_mode_monthly"),
        g_i18n:getText("ui_task_due_daily"),
        g_i18n:getText("ui_set_task_recur_mode_n_months"),
        g_i18n:getText("ui_set_task_recur_mode_n_days")
    }

    local default = 1
    if task.recurMode ~= Task.RECUR_MODE.NONE then
        default = task.recurMode
    end
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_recur_mode"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.recurMode = index

                if task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS or task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
                    self:onAddEditTaskRequestN(task)
                    return
                end

                task.n = 0
                task.nextN = 0
                if task.recurMode == Task.RECUR_MODE.MONTHLY then
                    self:onAddEditTaskRequestPeriod(task)
                elseif task.recurMode == Task.RECUR_MODE.DAILY then
                    self:onAddEditTaskJourneyComplete(task)
                end
            else
                -- Go back
                self:onAddEditTaskRequestShouldRecur(task)
            end
        end
    })
end

function ManageTasksFrame:onAddEditTaskRequestN(task)
    local allowedValues = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}
    local default = 1
    if task.n ~= 0 then
        default = task.n
    end

    local text = ""
    if task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
        text = g_i18n:getText("ui_set_task_n_months")
        table.insert(allowedValues, "24")
        table.insert(allowedValues, "36")
    elseif task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
        text = g_i18n:getText("ui_set_task_n_days")
    end

    TaskListUtils.showOptionDialog({
        text = text,
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local increment = tonumber(allowedValues[index])
                task.n = increment
                if task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
                    self:onAddEditTaskRequestStartPeriod(task)
                elseif task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
                    task.nextN = g_currentMission.environment.currentDay
                    self:onAddEditTaskJourneyComplete(task)
                end
            else
                self:onAddEditTaskRequestRecurMode(task)
            end
        end
    })
end

-- New Task Step for Start Period
function ManageTasksFrame:onAddEditTaskRequestStartPeriod(task)
    local allowedValues = {
        g_i18n:getText("ui_month1"),
        g_i18n:getText("ui_month2"),
        g_i18n:getText("ui_month3"),
        g_i18n:getText("ui_month4"),
        g_i18n:getText("ui_month5"),
        g_i18n:getText("ui_month6"),
        g_i18n:getText("ui_month7"),
        g_i18n:getText("ui_month8"),
        g_i18n:getText("ui_month9"),
        g_i18n:getText("ui_month10"),
        g_i18n:getText("ui_month11"),
        g_i18n:getText("ui_month12")
    }
    local default = TaskListUtils.convertPeriodToMonthNumber(g_currentMission.environment.currentPeriod)
    if task.nextN ~= 0 then
        default = TaskListUtils.convertPeriodToMonthNumber(task.nextN)
    end
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_start_period"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.nextN = TaskListUtils.convertMonthNumberToPeriod(index)
                self:onAddEditTaskJourneyComplete(task)
            else
                -- Go back
                self:onAddEditTaskRequestN(task)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestPeriod(task)
    local allowedValues = {
        g_i18n:getText("ui_month1"),
        g_i18n:getText("ui_month2"),
        g_i18n:getText("ui_month3"),
        g_i18n:getText("ui_month4"),
        g_i18n:getText("ui_month5"),
        g_i18n:getText("ui_month6"),
        g_i18n:getText("ui_month7"),
        g_i18n:getText("ui_month8"),
        g_i18n:getText("ui_month9"),
        g_i18n:getText("ui_month10"),
        g_i18n:getText("ui_month11"),
        g_i18n:getText("ui_month12")
    }
    local default = TaskListUtils.convertPeriodToMonthNumber(g_currentMission.environment.currentPeriod)
    if task.period ~= 1 then
        default = TaskListUtils.convertPeriodToMonthNumber(task.period)
    end
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_period"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                task.period = TaskListUtils.convertMonthNumberToPeriod(index)
                self:onAddEditTaskJourneyComplete(task)
            else
                if task.shouldRecur then
                    self:onAddEditTaskRequestRecurMode(task)
                else
                    self:onAddEditTaskRequestShouldRecur(task)
                end
            end
        end
    })
end

-- New Task Final Step
function ManageTasksFrame:onAddEditTaskJourneyComplete(task)
    g_currentMission.taskList:addTask(self.currentGroup.id, task, self.isEdit)
    self.isEdit = false
end

function ManageTasksFrame:onClickDelete(sender)
    if self.currentGroupId == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected"))
        return
    end
    if self.selectedTaskIndex == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_task_selected"))
        return
    end
    YesNoDialog.show(
        ManageTasksFrame.onRespondToDeletePrompt, self,
        g_i18n:getText("ui_confirm_deletion"))
end

function ManageTasksFrame:onRespondToDeletePrompt(clickOk)
    if clickOk then
        g_currentMission.taskList:deleteTask(self.currentGroup.id, self.currentGroup.tasks[self.selectedTaskIndex].id)
    end
end

function ManageTasksFrame:OnGroupSelectChange(index)
    self.currentGroupId = self.availableGroups[index].id
    self:updateContent()
end
