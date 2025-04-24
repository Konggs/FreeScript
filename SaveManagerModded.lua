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
                return { type = "Dropdown", idx = idx, value = object.Value, mutli = object.Multi }
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

    -- Đánh dấu các index không cần save
    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    -- Thay đổi folder gốc
    function SaveManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    -- Save thủ công
    function SaveManager:Save(name)
        if not name then
            return false, "no config file is selected"
        end

        local fullPath = self.Folder .. "/settings/" .. name .. ".json"
        local data = { objects = {} }

        for idx, option in next, self.Options do
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end
            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end

        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not ok then
            return false, "failed to encode data"
        end

        writefile(fullPath, encoded)
        return true
    end

    -- Load thủ công
    function SaveManager:Load(name)
        if not name then
            return false, "no config file is selected"
        end

        local file = self.Folder .. "/settings/" .. name .. ".json"
        if not isfile(file) then
            return false, "invalid file"
        end

        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
        if not ok then
            return false, "decode error"
        end

        for _, option in next, decoded.objects do
            if self.Parser[option.type] then
                task.spawn(function()
                    self.Parser[option.type].Load(option.idx, option)
                end)
            end
        end

        return true
    end

    -- Bỏ save các theme-setting
    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            "InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
        })
    end

    -- Tạo thư mục nếu chưa có
    function SaveManager:BuildFolderTree()
        local paths = {
            self.Folder,
            self.Folder .. "/settings"
        }
        for _, p in ipairs(paths) do
            if not isfolder(p) then
                makefolder(p)
            end
        end
    end

    -- Lấy danh sách file configs
    function SaveManager:RefreshConfigList()
        local list = listfiles(self.Folder .. "/settings")
        local out = {}
        for _, file in ipairs(list) do
            if file:sub(-5) == ".json" then
                local base = file:match("([^/\\]+)%.json$")
                if base and base ~= "options" then
                    table.insert(out, base)
                end
            end
        end
        return out
    end

    -- Thiết lập thư viện, khởi tạo auto-load và auto-save
    function SaveManager:SetLibrary(library)
        self.Library = library
        self.Options = library.Options

        -- đảm bảo folder
        self:BuildFolderTree()

        -- tạo default.json nếu chưa có
        local defaultPath = self.Folder .. "/settings/" .. DEFAULT_CONFIG .. ".json"
        if not isfile(defaultPath) then
            self:Save(DEFAULT_CONFIG)
        end

        -- ghi autoload.txt về default
        writefile(self.Folder .. "/settings/autoload.txt", DEFAULT_CONFIG)

        -- auto-load default
        self:LoadAutoloadConfig()

        -- hook mỗi option: khi nào OnChanged được gọi thì Save + debug
        for _, opt in pairs(self.Options) do
            if type(opt.OnChanged) == "function" then
                opt:OnChanged(function()
                    local ok, err = self:Save(DEFAULT_CONFIG)
                    if ok then
                        print(("[SaveManager] Auto-saved config '%s'"):format(DEFAULT_CONFIG))
                    else
                        warn(("[SaveManager] Failed to auto-save '%s': %s"):format(DEFAULT_CONFIG, err))
                    end
                end)
            end
        end
    end

    -- Load config được chỉ định trong autoload.txt
    function SaveManager:LoadAutoloadConfig()
        local txt = self.Folder .. "/settings/autoload.txt"
        if isfile(txt) then
            local name = readfile(txt)
            local ok, err = self:Load(name)
            if not ok then
                self.Library:Notify({
                    Title = "Interface",
                    Content = "Config loader",
                    SubContent = "Failed to load autoload config: " .. err,
                    Duration = 7
                })
            else
                self.Library:Notify({
                    Title = "Interface",
                    Content = "Config loader",
                    SubContent = string.format("Auto-loaded config %q", name),
                    Duration = 7
                })
            end
        end
    end

    -- Lần đầu khởi tạo folder
    SaveManager:BuildFolderTree()
end

return SaveManager
