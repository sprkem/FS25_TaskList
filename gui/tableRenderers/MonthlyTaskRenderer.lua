MonthlyTaskRenderer = {}
MonthlyTaskRenderer_mt = Class(MonthlyTaskRenderer)

function MonthlyTaskRenderer:new(parent)
    local self = {}
    setmetatable(self, MonthlyTaskRenderer_mt)
    self.parent = parent
    self.data = nil
    self.selectedRow = -1;

    return self
end

function MonthlyTaskRenderer:setData(data)
    self.data = data
end

function MonthlyTaskRenderer:getNumberOfSections()
    return 1
end

function MonthlyTaskRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function MonthlyTaskRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function MonthlyTaskRenderer:populateCellForItemInSection(list, section, index, cell)
    local meta = self.data[index]
    local group = g_currentMission.taskList.taskGroups[meta.groupId]
    local task = group.tasks[meta.taskId]

    cell:getAttribute("group"):setText(group.name)
    cell:getAttribute("detail"):setText(task.detail)
    cell:getAttribute("priority"):setText(task.priority)
    cell:getAttribute("effort"):setText(task.effort)
end

function MonthlyTaskRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
end
