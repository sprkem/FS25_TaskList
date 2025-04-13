ManageGroupsFrame = {}
ManageGroupsFrame.currentGroups = {}
local ManageGroupsFrame_mt = Class(ManageGroupsFrame, MessageDialog)


function ManageGroupsFrame.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or ManageGroupsFrame_mt)
    self.i18n = g_i18n
    self.selectedGroupIndex = -1;
    self.isEdit = false
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
    local group = self.currentGroups[index]
    local typeString = TaskGroup.GROUP_TYPE_STRINGS[group.type]

    local source = '-'
    if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
        source = g_currentMission.taskList.taskGroups[group.templateGroupId].name
    end

    cell:getAttribute("group"):setText(group.name)
    cell:getAttribute("type"):setText(g_i18n:getText(typeString))
    cell:getAttribute("source"):setText(source)
end

function ManageGroupsFrame:onListSelectionChanged(list, section, index)
    self.selectedGroupIndex = index
end

function ManageGroupsFrame:onClickBack(sender)
    self:close()
end

function ManageGroupsFrame:onClickAdd(sender)
    local newGroup = TaskGroup.new()
    self.isEdit = false
    self:onAddEditGroupRequestName(newGroup)
end

function ManageGroupsFrame:onClickEdit(sender)
    if self.selectedGroupIndex == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected_error"))
        return
    end
    local group = self.currentGroups[self.selectedGroupIndex]
    self.isEdit = true
    self:onAddEditGroupRequestName(group)
end

function ManageGroupsFrame:onAddEditGroupRequestName(group)
    TextInputDialog.show(
        function(self, value, clickOk)
            if clickOk then
                local name = string.gsub(value, '^%s*(.-)%s*$', '%1')
                if name == "" then
                    InfoDialog.show(g_i18n:getText("ui_no_name_specified_error"))
                    return
                end

                if self.isEdit == false and g_currentMission.taskList:groupExistsForCurrentFarm(name) then
                    InfoDialog.show(g_i18n:getText("ui_group_exists_error"))
                    return
                end
                group.name = name
                self:onAddEditRequestType(group)
            end
        end, self,
        group.name,
        g_i18n:getText("ui_set_group_name"),
        nil, TaskGroup.MAX_NAME_LENGTH, g_i18n:getText("ui_btn_ok"))
end

function ManageGroupsFrame:onAddEditRequestType(group)
    local allowedValues = {}
    table.insert(allowedValues, g_i18n:getText("ui_type_standard"))
    table.insert(allowedValues, g_i18n:getText("ui_type_template"))

    for _, group in pairs(g_currentMission.taskList.taskGroups) do
        if group.type == TaskGroup.GROUP_TYPE.Template then
            table.insert(allowedValues, g_i18n:getText("ui_type_template_instance"))
            break
        end
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_group_request_type_description"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = group.type,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                group.type = index

                if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
                    self:onAddEditRequestTemplateGroup(group)
                else
                    group.templateGroupId = ""
                    group.effortMultiplier = 1
                    self:onAddEditJourneyComplete(group)
                end
            else
                -- Go back
                self:onAddEditGroupRequestName(group)
            end
        end
    })
end

function ManageGroupsFrame:onAddEditRequestTemplateGroup(group)
    local allowedValues = {}
    local allowedValuesGroupLookup = {}
    local default = 1
    for _, group in pairs(g_currentMission.taskList.taskGroups) do
        if group.type == TaskGroup.GROUP_TYPE.Template then
            table.insert(allowedValues, group.name)
            table.insert(allowedValuesGroupLookup, group.id)
            if group.id == group.templateGroupId then
                default = #allowedValues
            end
        end
    end

    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_group_request_source_group"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = default,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                group.templateGroupId = allowedValuesGroupLookup[index]
                self:onAddEditRequestEffortMultiplier(group)
            else
                -- Go back
                self:onAddEditRequestType(group)
            end
        end
    })
end

function ManageGroupsFrame:onAddEditRequestEffortMultiplier(group)
    local allowedValues = { "1", "2", "3", "4", "5" }
    TaskListUtils.showOptionDialog({
        text = g_i18n:getText("ui_set_task_effort_multiplier"),
        title = "",
        defaultText = "",
        options = allowedValues,
        defaultOption = group.effortMultiplier,
        target = self,
        args = {},
        callback = function(_, index)
            if index > 0 then
                local value = allowedValues[index]
                group.effortMultiplier = tonumber(value)
                self:onAddEditJourneyComplete(group)
            else
                -- Go back
                self:onAddEditRequestTemplateGroup(group)
            end
        end
    })
end

function ManageGroupsFrame:onAddEditJourneyComplete(group)
    if self.isEdit then
        g_currentMission.taskList:editGroupForCurrentFarm(group)
    else
        g_currentMission.taskList:addGroupForCurrentFarm(group)
    end
    self.isEdit = false
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

    local dialogText = g_i18n:getText("ui_confirm_deletion")
    if self.currentGroups[self.selectedGroupIndex].type == TaskGroup.GROUP_TYPE.Template then
        dialogText = g_i18n:getText("ui_confirm_deletion_template")
    end

    YesNoDialog.show(
        function(self, clickOk)
            if clickOk then
                g_currentMission.taskList:deleteGroup(self.currentGroups[self.selectedGroupIndex].id)
            end
        end, self,
        g_i18n:getText("ui_confirm_deletion"))
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
