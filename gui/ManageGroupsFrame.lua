ManageGroupsFrame = {}
ManageGroupsFrame.currentGroups = {}
local ManageGroupsFrame_mt = Class(ManageGroupsFrame, MessageDialog)


function ManageGroupsFrame.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or ManageGroupsFrame_mt)
    self.i18n = g_i18n
    self.selectedGroupIndex = -1;
    return self
end

function ManageGroupsFrame:onCreate()
    ManageGroupsFrame:superClass().onCreate(self)
end

function ManageGroupsFrame:onGuiSetupFinished()
    ManageGroupsFrame:superClass().onGuiSetupFinished(self)
    self.groupsTable:setDataSource(self)
    self.groupsTable:setDelegate(self)
end

function ManageGroupsFrame:onOpen()
    ManageGroupsFrame:superClass().onOpen(self)
    g_messageCenter:subscribe(MessageType.TASK_GROUPS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    self:updateContent()
    FocusManager:setFocus(self.groupsTable)
end

function ManageGroupsFrame:onClose()
    ManageGroupsFrame:superClass().onClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function ManageGroupsFrame:updateContent()
    self.currentGroups = g_currentMission.taskList:getGroupListForCurrentFarm()

    if next(self.currentGroups) == nil then
        self.tableContainer:setVisible(false)
        self.noDataContainer:setVisible(true)
        return
    end

    self.tableContainer:setVisible(true)
    self.noDataContainer:setVisible(false)
    self.groupsTable:reloadData()
end

function ManageGroupsFrame:getNumberOfSections()
    return 1
end

function ManageGroupsFrame:getNumberOfItemsInSection(list, section)
    local count = 0
    for _ in pairs(self.currentGroups) do count = count + 1 end
    return count
end

function ManageGroupsFrame:getTitleForSectionHeader(list, section)
    return ""
end

function ManageGroupsFrame:populateCellForItemInSection(list, section, index, cell)
    local entry = self.currentGroups[index]
    cell:getAttribute("group"):setText(entry.name)
end

function ManageGroupsFrame:onListSelectionChanged(list, section, index)
    self.selectedGroupIndex = index
end

function ManageGroupsFrame:onClickBack(sender)
    self:close()
end

function ManageGroupsFrame:onClickAdd(sender)
    TextInputDialog.show(
        ManageGroupsFrame.onNewGroupNameSet, self,
        "",
        g_i18n:getText("ui_set_group_name"),
        nil, TaskGroup.MAX_NAME_LENGTH, g_i18n:getText("ui_btn_ok"))
end

function ManageGroupsFrame:onClickRename(sender)
    TextInputDialog.show(
        function(self, name, clickOk)
            if clickOk then
                name = string.gsub(name, '^%s*(.-)%s*$', '%1')
                if name == "" then
                    InfoDialog.show(g_i18n:getText("ui_no_name_specified_error"))
                    return
                end

                if g_currentMission.taskList:groupExistsForCurrentFarm(name) then
                    InfoDialog.show(g_i18n:getText("ui_group_exists_error"))
                    return
                end

                g_currentMission.taskList:renameGroup(self.currentGroups[self.selectedGroupIndex].id, name)
                return
            end
        end, self,
        self.currentGroups[self.selectedGroupIndex].name,
        g_i18n:getText("ui_set_group_name"),
        nil, TaskGroup.MAX_NAME_LENGTH, g_i18n:getText("ui_btn_ok"))
end

function ManageGroupsFrame:onClickCopy(sender)
    if self.selectedGroupIndex == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected_error"))
        return
    end

    TextInputDialog.show(
        ManageGroupsFrame.onCopyGroupNameSet, self,
        "",
        g_i18n:getText("ui_set_group_name"),
        nil, TaskGroup.MAX_NAME_LENGTH, g_i18n:getText("ui_btn_ok"))
end

function ManageGroupsFrame:onClickDelete(sender)
    if self.selectedGroupIndex == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected_error"))
        return
    end

    YesNoDialog.show(
        function(self, clickOk)
            if clickOk then
                g_currentMission.taskList:deleteGroup(self.currentGroups[self.selectedGroupIndex].id)
            end
        end, self,
        g_i18n:getText("ui_confirm_deletion"))
end

function ManageGroupsFrame:onNewGroupNameSet(name, clickOk)
    if clickOk then
        name = string.gsub(name, '^%s*(.-)%s*$', '%1')
        if name == "" then
            InfoDialog.show(g_i18n:getText("ui_no_name_specified_error"))
            return
        end

        if g_currentMission.taskList:groupExistsForCurrentFarm(name) then
            InfoDialog.show(g_i18n:getText("ui_group_exists_error"))
            return
        end

        g_currentMission.taskList:addGroupForCurrentFarm(name)
        return
    end
end

function ManageGroupsFrame:onCopyGroupNameSet(name, clickOk)
    if clickOk then
        name = string.gsub(name, '^%s*(.-)%s*$', '%1')
        if name == "" then
            InfoDialog.show(g_i18n:getText("ui_no_name_specified_error"))
            return
        end

        if g_currentMission.taskList:groupExistsForCurrentFarm(name) then
            InfoDialog.show(g_i18n:getText("ui_group_exists_error"))
            return
        end

        g_currentMission.taskList:copyGroupForCurrentFarm(name, self.currentGroups[self.selectedGroupIndex].id)
        return
    end
end
