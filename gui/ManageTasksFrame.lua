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
    self.availableGroups = g_currentMission.taskList:getGroupListForCurrentFarm()
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

    cell:getAttribute("detail"):setText(task.detail)
    cell:getAttribute("priority"):setText(task.priority)

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

function ManageTasksFrame:onListSelectionChanged(list, section, index)
    self.selectedTaskIndex = index
end

function ManageTasksFrame:onClickBack(sender)
    self:close()
end

-- New Task Step
function ManageTasksFrame:onClickAdd(sender)
    local newTask = Task.new()
    self.isEdit = false
    self:onAddEditTaskRequestDetail(newTask)
end

function ManageTasksFrame:onClickEdit(sender)
    if self.selectedTaskIndex == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_task_selected"))
        return
    end
    local task = self.currentGroup.tasks[self.selectedTaskIndex]
    self.isEdit = true
    self:onAddEditTaskRequestDetail(task)
end

function ManageTasksFrame:onAddEditTaskRequestDetail(newTask)
    TextInputDialog.show(
        function(self, value, clickOk)
            if clickOk then
                local detail = string.gsub(value, '^%s*(.-)%s*$', '%1')
                if detail == "" then
                    InfoDialog.show(g_i18n:getText("ui_no_detail_specified_error"))
                    return
                end

                newTask.detail = detail
                self:onAddEditTaskRequestPriority(newTask)
            end
        end, self,
        newTask.detail,
        g_i18n:getText("ui_set_task_detail"),
        "xzz", Task.MAX_DETAIL_LENGTH, g_i18n:getText("ui_btn_ok"))
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestPriority(newTask)
    local allowedValues = { "1", "2", "3", "4", "5" }
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_priority"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = newTask.priority,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local value = allowedValues[index]
                newTask.priority = tonumber(value)
                self:onAddEditTaskRequestShouldRecur(newTask)
            else
                -- Go back
                self:onAddEditTaskRequestDetail(newTask)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestShouldRecur(newTask)
    local allowedValues = { g_i18n:getText("ui_yes"), g_i18n:getText("ui_no") }
    local default = 1
    if newTask.shouldRecur == false then
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
                newTask.shouldRecur = index == 1
                if newTask.shouldRecur then
                    self:onAddEditTaskRequestRecurMode(newTask)
                else
                    self:onAddEditTaskRequestPeriod(newTask)
                end
            else
                -- Go back
                self:onAddEditTaskRequestPriority(newTask)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestRecurMode(newTask)
    local allowedValues = {
        g_i18n:getText("ui_set_task_recur_mode_monthly"),
        g_i18n:getText("ui_task_due_daily"),
        g_i18n:getText("ui_set_task_recur_mode_n_months"),
        g_i18n:getText("ui_set_task_recur_mode_n_days")
    }

    local default = 1
    if newTask.recurMode ~= Task.RECUR_MODE.NONE then
        default = newTask.recurMode
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
                newTask.recurMode = index

                if newTask.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS or newTask.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
                    self:onAddEditTaskRequestN(newTask)
                    return
                end

                newTask.n = 0
                newTask.nextN = 0
                if newTask.recurMode == Task.RECUR_MODE.MONTHLY then
                    self:onAddEditTaskRequestPeriod(newTask)
                elseif newTask.recurMode == Task.RECUR_MODE.DAILY then
                    self:onAddEditTaskJourneyComplete(newTask)
                end
            else
                -- Go back
                self:onAddEditTaskRequestShouldRecur(newTask)
            end
        end
    })
end

function ManageTasksFrame:onAddEditTaskRequestN(newTask)
    local allowedValues = { "1", "2", "3", "4", "5" }
    local default = 1
    if newTask.n ~= 0 then
        default = newTask.n
    end

    local text = ""
    if newTask.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
        text = g_i18n:getText("ui_set_task_n_months")
    elseif newTask.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
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
                newTask.n = increment
                if newTask.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
                    newTask.nextN = g_currentMission.environment.currentPeriod
                elseif newTask.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
                    newTask.nextN = g_currentMission.environment.currentDay
                end
                self:onAddEditTaskJourneyComplete(newTask)
            else
                self:onAddEditTaskRequestRecurMode(newTask)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onAddEditTaskRequestPeriod(newTask)
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
    if newTask.period ~= 1 then
        default = TaskListUtils.convertPeriodToMonthNumber(newTask.period)
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
                newTask.period = TaskListUtils.convertMonthNumberToPeriod(index)
                self:onAddEditTaskJourneyComplete(newTask)
            else
                if newTask.shouldRecur then
                    self:onAddEditTaskRequestRecurMode(newTask)
                else
                    self:onAddEditTaskRequestShouldRecur(newTask)
                end
            end
        end
    })
end

-- New Task Final Step
function ManageTasksFrame:onAddEditTaskJourneyComplete(newTask)
    g_currentMission.taskList:addTask(self.currentGroup.id, newTask, self.isEdit)
    self.isEdit = false
end

function ManageTasksFrame:onClickDelete(sender)
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
