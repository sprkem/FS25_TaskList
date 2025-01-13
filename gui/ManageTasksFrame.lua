ManageTasksFrame = {}
ManageTasksFrame.availableGroups = {}
local ManageTasksFrame_mt = Class(ManageTasksFrame, MessageDialog)
ManageTasksFrame.sortingFunction = function (k1, k2) return k1.name < k2.name end


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

    g_messageCenter:subscribe(MessageType.TASK_GROUPS_UPDATED, function (menu)
        self:updateContent()
    end, self)
    self:updateContent()
	-- FocusManager:setFocus(self.tasksTable)
	FocusManager:setFocus(self.groupSelector)
end

function ManageTasksFrame:onClose()
	ManageTasksFrame:superClass().onClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function ManageTasksFrame:updateContent()
    self.availableGroups = g_currentMission.todoList:getGroupListForCurrentFarm()
    table.sort(self.availableGroups, ManageTasksFrame.sortingFunction)

    local texts = {}
    for _, group in pairs(self.availableGroups) do
        table.insert(texts, group.name)
    end
    self.groupSelector:setTexts(texts)

    -- Check there are any groups
    if next(self.availableGroups) == nil then
        self.tasksContainer:setVisible(false)
        self.noTasksContainer:setVisible(true)
        return
    end

    -- If there are groups but the currentGroupId is not there, find one to show
    self.currentGroup = g_currentMission.todoList:getGroupById(self.currentGroupId, false)
    if self.currentGroup == nil then
        for _, group in pairs(self.availableGroups) do
            self.currentGroup = g_currentMission.todoList:getGroupById(group.id, false)
            self.currentGroupId = group.id
            break
        end

    end

    -- Check if any tasks on the current Group. If not hide the table and return
    if next(self.currentGroup.tasks) == nil then
        print("No tasks so hiding visuals")
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
end

function ManageTasksFrame:onListSelectionChanged(list, section, index)
    self.selectedTaskIndex = index
end

function ManageTasksFrame:onClickBack(sender)
	self:close()
end

function ManageTasksFrame:onClickAdd(sender)
    print("Got Add button call")

end

function ManageTasksFrame:onClickCopy(sender)
    print("Got copy button call")
    -- if self.selectedGroupIndex == -1 then
    --     InfoDialog.show(g_i18n:getText("ui_no_group_selected_error"))
    --     return
    -- end
end

function ManageTasksFrame:onClickDelete(sender)
    -- if self.selectedGroupIndex == -1 then
    --     InfoDialog.show(g_i18n:getText("ui_no_group_selected_error"))
    --     return
    -- end
    -- YesNoDialog.show(
    --     ManageGroupsFrame.onRespondToDeletePrompt, self,
    --     g_i18n:getText("ui_confirm_deletion"),
    --     nil, nil, nil, nil, nil, nil)
end

function ManageTasksFrame:OnGroupSelectChange(index)
    self.currentGroupId = self.availableGroups[index].id
    self:updateContent()
end

function ManageTasksFrame:onRespondToDeletePrompt(clickOk)
    if clickOk then
        -- g_currentMission.todoList:deleteGroup(self.currentGroups[self.selectedGroupIndex].id)
    end
end

