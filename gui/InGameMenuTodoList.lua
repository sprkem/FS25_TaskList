InGameMenuTodoList = {}
-- InGameMenuTodoList.currentTasks = {}
InGameMenuTodoList.activeTasks = {}
InGameMenuTodoList._mt = Class(InGameMenuTodoList, TabbedMenuFrameElement)
InGameMenuTodoList.sortingFunction = function(k1, k2) return k1.priority < k2.priority end

function InGameMenuTodoList.new(i18n, messageCenter)
    local self = InGameMenuTodoList:superClass().new(nil, InGameMenuTodoList._mt)
    self.name = "InGameMenuTodoList"
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.selectedRow = -1;

    self.dataBindings = {} -- TODO check if removable

    self.btnBack = {
        inputAction = InputAction.MENU_BACK
    }

    self.btnManageGroups = {
        text = self.i18n:getText("ui_btn_manage_groups"),
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
        text = self.i18n:getText("ui_btn_manage_tasks"),
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

function InGameMenuTodoList:delete()
    InGameMenuTodoList:superClass().delete(self)
end

function InGameMenuTodoList:copyAttributes(src)
    InGameMenuTodoList:superClass().copyAttributes(self, src)
    self.i18n = src.i18n
end

function InGameMenuTodoList:onGuiSetupFinished()
    InGameMenuTodoList:superClass().onGuiSetupFinished(self)
    self.currentTasksTable:setDataSource(self)
    self.currentTasksTable:setDelegate(self)
end

function InGameMenuTodoList:initialize()
end

function InGameMenuTodoList:onFrameOpen()
    InGameMenuTodoList:superClass().onFrameOpen(self)

    g_messageCenter:subscribe(MessageType.ACTIVE_TASKS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    self:updateContent()
    FocusManager:setFocus(self.currentTasksTable)
end

function InGameMenuTodoList:onFrameClose()
    InGameMenuTodoList:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function InGameMenuTodoList:updateContent()
    -- Get the current farm
    print("Fetching groups/tasks for farm")

    -- local currentPeriod = math.floor(g_currentMission.environment.currentPeriod)
    -- print("Fetching tasks for next month: " .. currentPeriod)

    -- local nextMonth = currentPeriod + 1
    -- if nextMonth > 12 then
    --     nextMonth = 1
    -- end
    -- local nextMonthTasks = g_currentMission.todoList:getTasksForPeriodForCurrentFarm(nextMonth)

    self.activeTasks = g_currentMission.todoList:getActiveTasksForCurrentFarm()
    table.sort(self.activeTasks, InGameMenuTodoList.sortingFunction)
    -- DebugUtil.printTableRecursively(self.activeTasks,".",0,5)

    if next(self.activeTasks) == nil then
        self.tableContainer:setVisible(false)
        self.noDataContainer:setVisible(true)
        return
    end

    --     TODO: Possibly populate a 'next month list'

    self.tableContainer:setVisible(true)
    self.noDataContainer:setVisible(false)
    self.currentTasksTable:reloadData()
end

function InGameMenuTodoList:getNumberOfSections()
    print("InGameMenuTodoList:getNumberOfSections")
    return 1
end

function InGameMenuTodoList:getNumberOfItemsInSection(list, section)
    print("InGameMenuTodoList:getNumberOfItemsInSection")
    local count = 0
    for _ in pairs(self.activeTasks) do count = count + 1 end
    return count
end

function InGameMenuTodoList:getTitleForSectionHeader(list, section)
    print("InGameMenuTodoList:getTitleForSectionHeader: " .. section)
    return ""
end

function InGameMenuTodoList:populateCellForItemInSection(list, section, index, cell)
    print("InGameMenuTodoList:populateCellForItemInSection" .. section)
    local task = self.activeTasks[index]
    cell:getAttribute("group"):setText(task.groupName)
    cell:getAttribute("detail"):setText(task.detail)
    cell:getAttribute("priority"):setText(task.priority)

    local overdue = task.period ~= math.floor(g_currentMission.environment.currentPeriod)
    if overdue then
        cell:getAttribute("overdue"):setText("YES")
    else
        cell:getAttribute("overdue"):setText("NO")
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

function InGameMenuTodoList:onListSelectionChanged(list, section, index)
    self.selectedRow = index
end

function InGameMenuTodoList:completeTask()
    if self.selectedRow == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_task_selected"))
        return
    end
    g_currentMission.todoList:completeTask(self.activeTasks[self.selectedRow].id)
end

-- Functions opening dialogs
function InGameMenuTodoList:showManageGroups()
    print("InGameMenuTodoList:showManageGroups")
    local dialog = g_gui:showDialog("manageGroupsFrame")
end

function InGameMenuTodoList:manageTasks()
    print("InGameMenuTodoList:manageTasks")
    local dialog = g_gui:showDialog("manageTasksFrame")
end
