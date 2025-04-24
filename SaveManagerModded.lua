local HttpService = game:GetService("HttpService")

local SaveManager = {} do
    -- TÊN CONFIG MẶC ĐỊNH
    local DEFAULT_CONFIG = "default"

    -- Thư mục gốc
    SaveManager.Folder = "FluentSettings"
    SaveManager.Ignore = {}

    -- Parser cho từng loại UI element
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
                return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
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

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in ipairs(list) do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function SaveManager:BuildFolderTree()
        local paths = { self.Folder, self.Folder .. "/settings" }
        for _, p in ipairs(paths) do
            if not isfolder(p) then makefolder(p) end
        end
    end

    function SaveManager:RefreshConfigList()
        local list = listfiles(self.Folder .. "/settings")
        local out = {}
        for _, file in ipairs(list) do
            if file:sub(-5) == ".json" then
                local base = file:match("([^/\\]+)%%.json$")
                if base and base ~= "options" then table.insert(out, base) end
            end
        end
        return out
    end

    function SaveManager:Save(name)
        if not name then return false, "no config file is selected" end
        local fullPath = self.Folder .. "/settings/" .. name .. ".json"
        local data = { objects = {} }
        for idx, opt in pairs(self.Options) do
            if self.Parser[opt.Type] and not self.Ignore[idx] then
                table.insert(data.objects, self.Parser[opt.Type].Save(idx, opt))
            end
        end
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not ok then return false, "failed to encode data" end
        writefile(fullPath, encoded)
        return true
    end

    function SaveManager:Load(name)
        if not name then return false, "no config file is selected" end
        local file = self.Folder .. "/settings/" .. name .. ".json"
        if not isfile(file) then return false, "invalid file" end
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
        if not ok then return false, "decode error" end
        for _, obj in ipairs(decoded.objects) do
            local parser = self.Parser[obj.type]
            if parser then
                task.spawn(function() parser.Load(obj.idx, obj) end)
            end
        end
        return true
    end

    function SaveManager:LoadAutoloadConfig()
        local txt = self.Folder .. "/settings/autoload.txt"
        if isfile(txt) then
            local name = readfile(txt)
            local ok, err = self:Load(name)
            if not ok then
                self.Library:Notify({ Title = "Interface", Content = "Config loader",
                    SubContent = "Failed to load autoload config: "..err, Duration = 7 })
            end
        end
    end

    function SaveManager:SetLibrary(lib)
        self.Library = lib
        self.Options = lib.Options
        -- chuẩn bị thư mục
        self:BuildFolderTree()
        -- khởi tạo default nếu chưa có
        local defaultPath = self.Folder.."/settings/"..DEFAULT_CONFIG..".json"
        if not isfile(defaultPath) then self:Save(DEFAULT_CONFIG) end
        -- ghi autoload
        writefile(self.Folder.."/settings/autoload.txt", DEFAULT_CONFIG)
        -- load ngay lần đầu
        self:LoadAutoloadConfig()
        -- hook OnChanged của từng option để auto-save
        for idx, opt in pairs(self.Options) do
            if type(opt.OnChanged) == "function" then
                opt:OnChanged(function()
                    self:Save(DEFAULT_CONFIG)
                end)
            end
        end
    end

    -- Tùy chọn: bỏ UI config section
    -- function SaveManager:BuildConfigSection(tab) end

    -- Khởi tạo folder lần đầu
    SaveManager:BuildFolderTree()
end

return SaveManager
