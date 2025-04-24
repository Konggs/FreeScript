local SaveManager = {} do

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

    function SaveManager:SetConfigName(name)
        assert(type(name) == "string" and #name > 0, "ConfigName must be a non-empty string")
        self.ConfigName = name
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        assert(type(folder) == "string" and #folder > 0, "Folder must be a non-empty string")
        self.Folder = folder
        self:BuildFolderTree()
    end

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
        local ok, encoded = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), data)
        if not ok then
            return false, "failed to encode data"
        end
        writefile(fullPath, encoded)
        return true
    end

    function SaveManager:Load()
        local fullPath = ("%s/%s.json"):format(self.Folder, self.ConfigName)
        if not isfile(fullPath) then
            return false, "config file not found"
        end
        local ok, decoded = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), readfile(fullPath))
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

    function SaveManager:SetLibrary(library)
        self.Library = library
        self.Options = library.Options

        self:BuildFolderTree()

        local fullPath = ("%s/%s.json"):format(self.Folder, self.ConfigName)
        if isfile(fullPath) then
            self:Load()
        else
            self:Save()
        end

        for _, opt in pairs(self.Options) do
            if type(opt.OnChanged) == "function" then
                opt:OnChanged(function()
                    self:Save()
                end)
            end
        end
    end
end

return SaveManager
