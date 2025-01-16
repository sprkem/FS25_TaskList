ManageTasksFrame = {}
ManageTasksFrame.availableGroups = {}
local ManageTasksFrame_mt = Class(ManageTasksFrame, MessageDialog)
ManageTasksFrame.sortingFunction = function(k1, k2) return k1.name < k2.name end


function ManageTasksFrame.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or ManageTasksFrame_mt)
    self.i18n = g_i18n
    self.selectedTaskIndex = -1
    self.currentGroupId = -1
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
    table.sort(self.availableGroups, ManageTasksFrame.sortingFunction)

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
    elseif task.shouldRecurMode == Task.SHOULD_REPEAT_MODE.DAILY then
        cell:getAttribute("due"):setText(g_i18n:getText("ui_task_due_daily"))
    elseif task.shouldRecurMode == Task.SHOULD_REPEAT_MODE.MONTHLY then
        cell:getAttribute("due"):setText(string.format(g_i18n:getText("ui_task_due_monthly"), monthString))
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
    TextInputDialog.show(
        function(self, value, clickOk)
            if clickOk then
                local detail = string.gsub(value, '^%s*(.-)%s*$', '%1')
                if detail == "" then
                    InfoDialog.show(g_i18n:getText("ui_no_detail_specified_error"))
                    return
                end

                newTask.detail = detail
                self:onNewTaskRequestPriority(newTask)
            end
        end, self,
        "",
        g_i18n:getText("ui_set_task_detail"),
        "", Task.MAX_DETAIL_LENGTH, g_i18n:getText("ui_btn_ok"))
end

-- New Task Step
function ManageTasksFrame:onNewTaskRequestPriority(newTask)
    local allowedValues = { "1", "2", "3", "4", "5" }
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_priority"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = 1,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local value = allowedValues[index]
                newTask.priority = tonumber(value)
                self:onNewTaskRequestShouldRecur(newTask)
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onNewTaskRequestShouldRecur(newTask)
    YesNoDialog.show(
        function(self, clickYes)
            newTask.shouldRecur = clickYes
            if newTask.shouldRecur == true then
                self:onNewTaskRequestRecurMode(newTask)
            else
                self:onNewTaskRequestPeriod(newTask)
            end
        end, self, g_i18n:getText("ui_set_task_should_recur"))
end

-- New Task Step
function ManageTasksFrame:onNewTaskRequestRecurMode(newTask)
    local allowedValues = {
        g_i18n:getText("ui_set_task_recur_mode_monthly"),
        g_i18n:getText("ui_task_due_daily")
    }

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_recur_mode"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = 1,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                newTask.shouldRecurMode = index

                if newTask.shouldRecurMode == Task.SHOULD_REPEAT_MODE.MONTHLY then
                    self:onNewTaskRequestPeriod(newTask)
                elseif newTask.shouldRecurMode == Task.SHOULD_REPEAT_MODE.DAILY then
                    self:onNewTaskJourneyComplete(newTask)
                end
            end
        end
    })
end

-- New Task Step
function ManageTasksFrame:onNewTaskRequestPeriod(newTask)
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
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_period"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = 1,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                newTask.period = TaskListUtils.convertMonthNumberToPeriod(index)
                self:onNewTaskJourneyComplete(newTask)
            end
        end
    })
end

-- New Task Final Step
function ManageTasksFrame:onNewTaskJourneyComplete(newTask)
    g_currentMission.taskList:addTask(self.currentGroup.id, newTask)
end

-- Unsure if copy makes sense. Awaiting feedback
-- function ManageTasksFrame:onClickCopy(sender)
--     print("Got copy button call")
-- end

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
