MenuTaskList = {}
MenuTaskList.currentTasks = {}
MenuTaskList._mt = Class(MenuTaskList, TabbedMenuFrameElement)
MenuTaskList.sortingFunction = function(k1, k2) return k1.priority < k2.priority end

function MenuTaskList.new(i18n, messageCenter)
    local self = MenuTaskList:superClass().new(nil, MenuTaskList._mt)
    self.name = "menuTaskList"
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.selectedRow = -1;

    self.dataBindings = {}

    self.btnBack = {
        inputAction = InputAction.MENU_BACK
    }

    self.btnManageGroups = {
        text = self.i18n:getText("ui_manage_groups"),
        inputAction = InputAction.MENU_EXTRA_1,
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

    self:setMenuButtonInfo({
        self.btnBack,
        self.btnManageGroups,
        self.btnCompleteTask,
        self.btnManageTasks
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
end

function MenuTaskList:initialize()
end

function MenuTaskList:onFrameOpen()
    MenuTaskList:superClass().onFrameOpen(self)

    g_messageCenter:subscribe(MessageType.ACTIVE_TASKS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    g_messageCenter:subscribe(MessageType.TASK_GROUPS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    self:updateContent()
    FocusManager:setFocus(self.currentTasksTable)
end

function MenuTaskList:onFrameClose()
    MenuTaskList:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function MenuTaskList:updateContent()
    -- Get the current farm

    -- local currentPeriod = math.floor(g_currentMission.environment.currentPeriod)

    -- local nextMonth = currentPeriod + 1
    -- if nextMonth > 12 then
    --     nextMonth = 1
    -- end
    -- local nextMonthTasks = g_currentMission.taskList:getTasksForPeriodForCurrentFarm(nextMonth)
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

    --     TODO: Possibly populate a 'next month list'

    self.tableContainer:setVisible(true)
    self.noDataContainer:setVisible(false)
    self.currentTasksTable:reloadData()
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
    cell:getAttribute("priority"):setText(task.priority)

    local overdue = task.period ~= math.floor(g_currentMission.environment.currentPeriod)
    if overdue then
        cell:getAttribute("overdue"):setText(g_i18n:getText("ui_overdue_yes"))
    else
        cell:getAttribute("overdue"):setText(g_i18n:getText("ui_overdue_no"))
    end

    local monthString = TaskListUtils.formatPeriodFullMonthName(task.period)
    if not task.shouldRecur then
        cell:getAttribute("due"):setText(monthString)
    elseif task.shouldRecurMode == Task.SHOULD_REPEAT_MODE.DAILY then
        cell:getAttribute("due"):setText(g_i18n:getText("ui_task_due_daily"))
    elseif task.shouldRecurMode == Task.SHOULD_REPEAT_MODE.MONTHLY then
        cell:getAttribute("due"):setText(string.format(g_i18n:getText("ui_task_due_monthly"), monthString))
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
    g_currentMission.taskList:completeTask(task.groupId, task.id)
end

-- Functions opening dialogs
function MenuTaskList:showManageGroups()
    local dialog = g_gui:showDialog("manageGroupsFrame")
end

function MenuTaskList:manageTasks()
    local dialog = g_gui:showDialog("manageTasksFrame")
end
