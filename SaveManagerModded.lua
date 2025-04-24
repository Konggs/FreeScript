-- SaveManagerModded.lua
-- Single-file config ("Config.json" by default) saved directly under the specified folder

local HttpService = game:GetService("HttpService")

local SaveManager = {} do
    -- Default config file name (without ".json")
    SaveManager.ConfigName = "Config"
    -- Default save folder (override with :SetFolder)
    SaveManager.Folder = "FluentSettings"
    -- Keys to ignore when saving
    SaveManager.Ignore = {}

    -- Parsers for each UI element type
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = "Toggle", idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = "Slider", idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = "Dropdown", idx = idx, value = object.Value, multi = object.Multi }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },
        Colorpicker = {
            Save = function(idx, object)
                return {
                    type = "Colorpicker",
                    idx = idx,
                    value = object.Value:ToHex(),
                    transparency = object.Transparency
                }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValueRGB(
                        Color3.fromHex(data.value),
                        data.transparency
                    )
                end
            end,
        },
        Keybind = {
            Save = function(idx, object)
                return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.key, data.mode)
                end
            end,
        },
        Input = {
            Save = function(idx, object)
                return { type = "Input", idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] and type(data.text) == "string" then
                    SaveManager.Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    -- Override the config file name
    function SaveManager:SetConfigName(name)
        assert(type(name) == "string" and #name > 0, "ConfigName must be a non-empty string")
        self.ConfigName = name
    end

    -- Mark certain option keys to ignore when saving
    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    -- Override the base folder where the .json will be saved
    function SaveManager:SetFolder(folder)
        assert(type(folder) == "string" and #folder > 0, "Folder must be a non-empty string")
        self.Folder = folder
        self:BuildFolderTree()
    end

    -- Create each segment of the folder path if it doesn't exist
    function SaveManager:BuildFolderTree()
        local segments = {}
        for seg in self.Folder:gmatch("[^/\\]+") do
            table.insert(segments, seg)
        end
        local path = ""
        for _, seg in ipairs(segments) do
            path = (path == "" and seg) or (path .. "/" .. seg)
            if not isfolder(path) then
                makefolder(path)
            end
        end
    end

    -- Save current options into "<Folder>/<ConfigName>.json"
    function SaveManager:Save()
        local fullPath = ("%s/%s.json"):format(self.Folder, self.ConfigName)
        local data = { objects = {} }
        for idx, opt in next, self.Options do
            if not self.Parser[opt.Type] then
                continue
            end
            if self.Ignore[idx] then
                continue
            end
            table.insert(data.objects, self.Parser[opt.Type].Save(idx, opt))
        end
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not ok then
            return false, "failed to encode data"
        end
        writefile(fullPath, encoded)
        return true
    end

    -- Load options from "<Folder>/<ConfigName>.json"
    function SaveManager:Load()
        local fullPath = ("%s/%s.json"):format(self.Folder, self.ConfigName)
        if not isfile(fullPath) then
            return false, "config file not found"
        end
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(fullPath))
        if not ok then
            return false, "failed to decode data"
        end
        for _, obj in next, decoded.objects do
            local parser = self.Parser[obj.type]
            if parser then
                task.spawn(function()
                    parser.Load(obj.idx, obj)
                end)
            end
        end
        return true
    end

    -- Bind to Fluent, auto-load or auto-init, and hook auto-save with debug logs
    function SaveManager:SetLibrary(library)
        self.Library = library
        self.Options = library.Options

        -- Ensure folder exists
        self:BuildFolderTree()

        -- If config exists, load it; otherwise create an initial one
        local fullPath = ("%s/%s.json"):format(self.Folder, self.ConfigName)
        if isfile(fullPath) then
            local ok, err = self:Load()
            if not ok then
                warn(("[SaveManager] Load error: %s"):format(err))
            end
        else
            local ok, err = self:Save()
            if not ok then
                warn(("[SaveManager] Initial save error: %s"):format(err))
            end
        end

        -- Hook every option's OnChanged to auto-save
        for _, opt in pairs(self.Options) do
            if type(opt.OnChanged) == "function" then
                opt:OnChanged(function()
                    local ok, err = self:Save()
                    if ok then
                        print(("[SaveManager] Auto-saved '%s.json'"):format(self.ConfigName))
                    else
                        warn(("[SaveManager] Failed to auto-save '%s.json': %s"):format(self.ConfigName, err))
                    end
                end)
            end
        end
    end
end

return SaveManager
