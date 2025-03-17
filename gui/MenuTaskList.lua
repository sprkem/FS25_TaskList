MenuTaskList = {}
MenuTaskList.currentTasks = {}
MenuTaskList._mt = Class(MenuTaskList, TabbedMenuFrameElement)
MenuTaskList.sortingFunction = function(k1, k2) return k1.priority < k2.priority end

MenuTaskList.VIEW_MODE = {
    CURRENTLY_DUE = 0,
    WORKLOAD = 1
}

function MenuTaskList.new(i18n, messageCenter)
    local self = MenuTaskList:superClass().new(nil, MenuTaskList._mt)
    self.name = "menuTaskList"
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.selectedCurrentTaskRow = -1
    self.selectedMonthlyTasksMonth = 1
    self.viewMode = MenuTaskList.VIEW_MODE.CURRENTLY_DUE
    self.clonedPricesElements = {}
    self.monthTexts = {}
    self.fluctuationPoints = {}
    self.monthlyTaskRenderer = MonthlyTaskRenderer:new(self)

    self.btnBack = {
        inputAction = InputAction.MENU_BACK
    }

    self.btnManageGroups = {
        text = self.i18n:getText("ui_manage_groups"),
        inputAction = InputAction.MENU_EXTRA_2,
        callback = function()
            self:showManageGroups()
        end
    }

    self.btnCompleteTask = {
        text = self.i18n:getText("ui_btn_complete_task"),
        inputAction = InputAction.MENU_ACCEPT,
        callback = function()
            self:completeTask()
        end
    }

    self.btnManageTasks = {
        text = self.i18n:getText("ui_manage_tasks"),
        inputAction = InputAction.MENU_ACTIVATE,
        callback = function()
            self:manageTasks()
        end
    }

    self.btnToggleView = {
        text = g_i18n:getText("ui_switchMode"),
        inputAction = InputAction.MENU_EXTRA_1,
        callback = function()
            self:toggleView()
        end
    }

    self:setMenuButtonInfo({
        self.btnBack,
        self.btnManageGroups,
        self.btnCompleteTask,
        self.btnManageTasks,
        self.btnToggleView
    })

    return self
end

function MenuTaskList:delete()
    MenuTaskList:superClass().delete(self)
end

function MenuTaskList:copyAttributes(src)
    MenuTaskList:superClass().copyAttributes(self, src)
    self.i18n = src.i18n
end

function MenuTaskList:onGuiSetupFinished()
    MenuTaskList:superClass().onGuiSetupFinished(self)
    self.currentTasksTable:setDataSource(self)
    self.currentTasksTable:setDelegate(self)

    self.monthlyTasksTable:setDataSource(self.monthlyTaskRenderer)
    self.monthlyTasksTable:setDelegate(self.monthlyTaskRenderer)
end

function MenuTaskList:initialize()
    self.monthTextTemplate:unlinkElement()
    self.separatorTemplate:unlinkElement()
    for i = 1, 12 do
        local period = TaskListUtils.convertMonthNumberToPeriod(i)
        local clone = self.monthTextTemplate:clone(self.fluctuationsLayoutBg)
        clone:setText(g_i18n:formatPeriod(period, true))
        table.insert(self.clonedPricesElements, clone)
        table.insert(self.monthTexts, clone)
        local separatorClone = self.separatorTemplate:clone(self.fluctuationsLayoutBg)
        table.insert(self.clonedPricesElements, separatorClone)
    end
    self.fluctuationsLayoutBg:invalidateLayout()

    local texts = {}
    for i = 1, 12 do
        local value = TaskListUtils.convertMonthNumberToPeriod(i)
        table.insert(texts, TaskListUtils.formatPeriodFullMonthName(value))
    end
    self.monthSelector:setTexts(texts)
end

function MenuTaskList:onFrameOpen()
    MenuTaskList:superClass().onFrameOpen(self)

    g_messageCenter:subscribe(MessageType.ACTIVE_TASKS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    g_messageCenter:subscribe(MessageType.TASK_GROUPS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)

    -- Force the view to next month tasks
    local nextPeriod = g_currentMission.environment.currentPeriod + 1
    if nextPeriod > 12 then
        nextPeriod = nextPeriod - 12
    end
    self.selectedMonthlyTasksMonth = TaskListUtils.convertPeriodToMonthNumber(nextPeriod)
    self.monthSelector:setState(self.selectedMonthlyTasksMonth, false)

    self:updateContent()
end

function MenuTaskList:onFrameClose()
    MenuTaskList:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function MenuTaskList:OnMonthSelectorChange(index)
    self.selectedMonthlyTasksMonth = index
    self:updateContent()
end

function MenuTaskList:toggleView()
    if self.viewMode == MenuTaskList.VIEW_MODE.CURRENTLY_DUE then
        self.viewMode = MenuTaskList.VIEW_MODE.WORKLOAD
    else
        self.viewMode = MenuTaskList.VIEW_MODE.CURRENTLY_DUE
    end
    self:updateContent()
end

function MenuTaskList:updateContent()
    if self.viewMode == MenuTaskList.VIEW_MODE.CURRENTLY_DUE then
        self:updateCurrentlyDue()
    elseif self.viewMode == MenuTaskList.VIEW_MODE.WORKLOAD then
        self:updateWorkload()
    end
end

function MenuTaskList:updateCurrentlyDue()
    FocusManager:setFocus(self.currentTasksTable)
    self.currentlyDueView:setVisible(true)
    self.workloadView:setVisible(false)
    if next(g_currentMission.taskList.taskGroups) == nil then
        self.tableContainer:setVisible(false)
        self.noDataContainer:setVisible(false)
        self.noGroupsContainer:setVisible(true)
        self.btnManageTasks.disabled = true
        self:setMenuButtonInfoDirty()
        return
    end
    self.btnManageTasks.disabled = false
    self.noGroupsContainer:setVisible(false)
    self:setMenuButtonInfoDirty()

    self.currentTasks = g_currentMission.taskList:getActiveTasksForCurrentFarm()
    table.sort(self.currentTasks, MenuTaskList.sortingFunction)

    if next(self.currentTasks) == nil then
        self.tableContainer:setVisible(false)
        self.noDataContainer:setVisible(true)
        return
    end

    self.tableContainer:setVisible(true)
    self.noDataContainer:setVisible(false)
    self.currentTasksTable:reloadData()
end

function MenuTaskList:draw()
    MenuTaskList:superClass().draw(self)

    if self.viewMode == MenuTaskList.VIEW_MODE.WORKLOAD then
        for k, v in pairs(self.fluctuationPoints) do
            local next = self.fluctuationPoints[k + 1]
            if next ~= nil then
                local startX = self.monthTexts[k].absPosition[1] + self.monthTexts[k].absSize[1] * 0.5
                local endX = self.monthTexts[k + 1].absPosition[1] + self.monthTexts[k + 1].absSize[1] * 0.5
                drawLine2D(startX, v + self.fluctuationsContainer.absPosition[2], endX,
                    next + self.fluctuationsContainer.absPosition[2], g_pixelSizeX * 4, 1, 1, 1, 1)
            end
        end
    end
end

function MenuTaskList:updateWorkload()
    self.currentlyDueView:setVisible(false)
    self.workloadView:setVisible(true)
    local tasks = g_currentMission.taskList:getTasksForNextYear()
    local selectedMonthTasks = tasks[self.selectedMonthlyTasksMonth]

    if #selectedMonthTasks == 0 then
        self.monthlyTasksContainer:setVisible(false)
        self.noMonthlyTasksContainer:setVisible(true)
        return
    end

    self.monthlyTasksContainer:setVisible(true)
    self.noMonthlyTasksContainer:setVisible(false)

    self.monthlyTaskRenderer:setData(selectedMonthTasks)
    self.monthlyTasksTable:reloadData()

    local min = math.huge
    local max = 0
    local effortMap = {}
    for i = 1, 12 do
        local totalEffort = 0
        for _, task in pairs(tasks[i]) do
            totalEffort = totalEffort + task.effort
        end
        effortMap[i] = totalEffort
        min = math.min(min, totalEffort)
        max = math.max(max, totalEffort)
    end

    self.fluctuationPoints = {}
    local high = 0
    local low = math.huge
    for i = 1, 12 do
        local effort = effortMap[i]
        local normalized = (effort - min) / (max - min) * 0.6 + 0.2

        self.fluctuationPoints[i] = normalized * self.fluctuationsContainer.absSize[2]
        if effort < low then
            local p = self.monthTexts[i].absPosition[1] + self.monthTexts[i].absSize[1] * 0.5 -
                self.fluctuationLow.absSize[1] * 0.5
            self.fluctuationLow:setAbsolutePosition(p, nil)
            low = effort
        end
        if high < effort then
            local p = self.monthTexts[i].absPosition[1] + self.monthTexts[i].absSize[1] * 0.5 -
                self.fluctuationHigh.absSize[1] * 0.5
            self.fluctuationHigh:setAbsolutePosition(p, nil)
            high = effort
        end
    end
    self.fluctuationHigh:setText(high)
    self.fluctuationLow:setText(low)

    FocusManager:setFocus(self.monthSelector)
end

function MenuTaskList:getNumberOfSections()
    return 1
end

function MenuTaskList:getNumberOfItemsInSection(list, section)
    local count = 0
    for _ in pairs(self.currentTasks) do count = count + 1 end
    return count
end

function MenuTaskList:getTitleForSectionHeader(list, section)
    return ""
end

function MenuTaskList:populateCellForItemInSection(list, section, index, cell)
    local task = self.currentTasks[index]
    cell:getAttribute("group"):setText(task.groupName)
    cell:getAttribute("detail"):setText(task.detail)
    cell:getAttribute("effort"):setText(task.effort)
    cell:getAttribute("priority"):setText(task.priority)

    local currentPeriod = g_currentMission.environment.currentPeriod
    local currentDay = g_currentMission.environment.currentDay
    local overdue = task.period ~= currentPeriod
    if task.recurMode == Task.RECUR_MODE.DAILY then
        overdue = false
    elseif task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
        overdue = currentDay ~= task.createdMarker
    elseif task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
        overdue = currentPeriod ~= task.createdMarker
    end

    if overdue then
        cell:getAttribute("overdue"):setText(g_i18n:getText("ui_yes"))
    else
        cell:getAttribute("overdue"):setText(g_i18n:getText("ui_no"))
    end

    local monthString = TaskListUtils.formatPeriodFullMonthName(task.period)
    if not task.shouldRecur then
        cell:getAttribute("due"):setText(monthString)
    elseif task.recurMode == Task.RECUR_MODE.DAILY then
        cell:getAttribute("due"):setText(g_i18n:getText("ui_task_due_daily"))
    elseif task.recurMode == Task.RECUR_MODE.MONTHLY then
        cell:getAttribute("due"):setText(string.format(g_i18n:getText("ui_task_due_monthly"), monthString))
    elseif task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
        cell:getAttribute("due"):setText(string.format(g_i18n:getText("ui_task_due_n_days"), task.n))
    elseif task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
        cell:getAttribute("due"):setText(string.format(g_i18n:getText("ui_task_due_n_months"), task.n))
    end
end

function MenuTaskList:onListSelectionChanged(list, section, index)
    self.selectedRow = index
end

function MenuTaskList:completeTask()
    if self.selectedRow == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_task_selected"))
        return
    end
    local task = self.currentTasks[self.selectedRow]

    YesNoDialog.show(
        function(self, clickOk)
            if clickOk then
                g_currentMission.taskList:completeTask(task.groupId, task.id)
            end
        end, self,
        string.format(g_i18n:getText("ui_confirm_complete_task"), task.detail))
end

-- Functions opening dialogs
function MenuTaskList:showManageGroups()
    local dialog = g_gui:showDialog("manageGroupsFrame")
end

function MenuTaskList:manageTasks()
    local dialog = g_gui:showDialog("manageTasksFrame")
end
