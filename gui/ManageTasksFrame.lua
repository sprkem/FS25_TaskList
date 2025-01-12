ManageTasksFrame = {}
ManageTasksFrame.availableGroups = {}
local ManageTasksFrame_mt = Class(ManageTasksFrame, MessageDialog)


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
    -- self.groupsTable:setDataSource(self)
	-- self.groupsTable:setDelegate(self)
end

function ManageTasksFrame:onOpen()
	ManageTasksFrame:superClass().onOpen(self)

    -- On open, try find the first group
    -- local groups = g_currentMission.todoList:getGroupListForCurrentFarm()
    -- self.currentGroup = next(groups)
    -- if self.currentGroup ~= nil then
    --     -- self.tableContainer:setVisible(false)
    --     -- self.noDataContainer:setVisible(true)
    --     -- return
    --     self.currentGroupId = self.currentGroup.id
    -- end


    -- g_messageCenter:subscribe(MessageType.GROUPS_UPDATED, function (menu)
    --     self:updateContent()
    -- end, self)
    self:updateContent()
	-- FocusManager:setFocus(self.groupsTable)
end

function ManageTasksFrame:onClose()
	ManageTasksFrame:superClass().onClose(self)
    -- g_messageCenter:unsubscribeAll(self)
end

function ManageTasksFrame:updateContent()
    self.availableGroups = g_currentMission.todoList:getGroupListForCurrentFarm()

    -- local texts = {}
    -- for _, group in pairs(self.availableGroups) do
    --     table.insert(texts, group.name)
    -- end
    -- self.groupSelector:setTexts(texts)

    -- Check there are any groups
    if next(self.availableGroups) == nil then
        self.tableContainer:setVisible(false)
        self.noDataContainer:setVisible(true)
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
        self.tableContainer:setVisible(false)
        self.noDataContainer:setVisible(true)
        return
    end

    self.tableContainer:setVisible(true)
    self.noDataContainer:setVisible(false)

    -- self:setCurrentGroupLabel()

    -- if next(self.currentGroups) == nil then
    --     self.tableContainer:setVisible(false)
    --     self.noDataContainer:setVisible(true)
    --     return
    -- end

    -- self.tableContainer:setVisible(true)
    -- self.noDataContainer:setVisible(false)
    -- self.groupsTable:reloadData()
end

function ManageTasksFrame:getNumberOfSections()
	return 1
end

function ManageTasksFrame:getNumberOfItemsInSection(list, section)
    -- local count = 0
    -- for _ in pairs(self.currentGroups) do count = count + 1 end
    -- return count
end

function ManageTasksFrame:getTitleForSectionHeader(list, section)
    return ""
end

function ManageTasksFrame:populateCellForItemInSection(list, section, index, cell)
    -- local entry = self.currentGroups[index]
    -- cell:getAttribute("group"):setText(entry.name)
end

function ManageTasksFrame:onListSelectionChanged(list, section, index)
    -- self.selectedTaskIndex = index
end

function ManageTasksFrame:setCurrentGroupLabel()
    self.currentGroupLabel.setText(string.format(g_i18n:getText("ui_header_current_group"), self.currentGroup.name))
end

function ManageGroupsFrame:onClickBack(sender)
	self:close()
end

function ManageGroupsFrame:onClickAdd(sender)
    print("Got Add button call")

end

function ManageGroupsFrame:onClickCopy(sender)
    print("Got copy button call")
    -- if self.selectedGroupIndex == -1 then
    --     InfoDialog.show(g_i18n:getText("ui_no_group_selected_error"))
    --     return
    -- end
end

function ManageGroupsFrame:onClickChooseGroup(sender)
    -- if self.currentGroup == nil then
    --     -- TODO show info and return
    -- end
    local texts = {
        "A", "B", "getTextsForValues"
    }
    OptionDialog.show(
			function (item)
                print("In callback")
				print(item)
			end,
			"a string",
			"a different string", texts)
end

function ManageGroupsFrame:onClickDelete(sender)
    -- if self.selectedGroupIndex == -1 then
    --     InfoDialog.show(g_i18n:getText("ui_no_group_selected_error"))
    --     return
    -- end
    -- YesNoDialog.show(
    --     ManageGroupsFrame.onRespondToDeletePrompt, self,
    --     g_i18n:getText("ui_confirm_deletion"),
    --     nil, nil, nil, nil, nil, nil)
end

function ManageGroupsFrame:onRespondToDeletePrompt(clickOk)
    if clickOk then
        -- g_currentMission.todoList:deleteGroup(self.currentGroups[self.selectedGroupIndex].id)
    end
end

