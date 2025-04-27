local FileLockLib = {}
local HttpService = game:GetService('HttpService')
function FileLockLib.SetupFile(FileName, Data, UpdateTime)
    local FileData = {
        Updated = 0,
        Data = Data
    }
    if not isfile(FileName) then 
        writefile(FileName, HttpService:JSONEncode(FileData))
    end
    local FileStatus = {
        LastHasAcc = tick(),
        HasAcc = false,
        NeedUpdateTime = UpdateTime
    }
    local StatusFileName = FileName .. "_Status.json"
    if not isfile(StatusFileName) then 
        writefile(StatusFileName, HttpService:JSONEncode(FileStatus))
    else
        FileStatus = HttpService:JSONDecode(readfile(StatusFileName))
    end
end
function FileLockLib.ReadFile(FileName)
    local FileData = {
        Updated = 0,
        Data = {}
    }
    if not isfile(FileName) then
        writefile(FileName, HttpService:JSONEncode(FileData))
    else
        FileData = HttpService:JSONDecode(readfile(FileName))
    end
    local StatusFileName = FileName .. "_Status.json"
    local FileStatus = HttpService:JSONDecode(readfile(StatusFileName))
    local NeedUpdateData = false
    if FileStatus.HasAcc and tick() - FileStatus.LastHasAcc > 120 then 
        FileStatus.HasAcc = false 
    end
    if tick() - FileData.Updated > FileStatus.NeedUpdateTime and not FileStatus.HasAcc then 
        NeedUpdateData = true
    end
    return FileData.Data, NeedUpdateData
end
function FileLockLib.SetUpdateStatus(FileName, Status)
    local StatusFileName = FileName .. "_Status.json"
    local FileStatus = HttpService:JSONDecode(readfile(StatusFileName))
    FileStatus.HasAcc = Status
    if Status then 
        FileStatus.LastHasAcc = tick()
    end
    writefile(StatusFileName, HttpService:JSONEncode(FileStatus))
end
function FileLockLib.SaveFile(FileName, Data)
    local StatusFileName = FileName .. "_Status.json"
    local FileStatus = HttpService:JSONDecode(readfile(StatusFileName))
    writefile(StatusFileName, HttpService:JSONEncode(FileStatus))
    local FileData = HttpService:JSONDecode(readfile(FileName))
    FileData.Data = Data
    FileData.Updated = tick()
    FileLockLib.SetUpdateStatus(FileName, false)
    writefile(FileName, HttpService:JSONEncode(FileData))
end
FileLockLib.SetupFile("DataGame.json", {}, 2 * 60 * 60)
if game.PlaceId == CheckDataPlace then 
    FileLockLib.SaveFile("DataGame.json", GetData())
else
    local Data, NeedUpdateData = FileLockLib.ReadFile("DataGame.json")
    if NeedUpdateData then 
        FileLockLib.SetUpdateStatus("DataGame.json", true)
        game:GetService("TeleportService"):Teleport(CheckDataPlace)
    end
end
function NewHopServer()
    FileLockLib.SetupFile("HopServerData.json", {}, 2 * 60)
    local Data, NeedUpdateData = FileLockLib.ReadFile("HopServerData.json")
    local ListSite = {ListSite = {}}
    if NeedUpdateData then 
        FileLockLib.SetUpdateStatus("HopServerData.json", true)
        Data = {}
        local Cursor = ""
        for i = 1, 3 do 
            local Url = 'https://games.roblox.com/v1/games/' .. game.PlaceId .. '/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true'
            if Cursor and Cursor ~= "" then 
                Url = Url .. '&cursor=' .. Cursor
            end
            local Ret = game:HttpGet(Url)
            local Site = HttpService:JSONDecode(Ret)
            if Site.errors then 
                wait(10)
                return
            end
            if Site.data then 
                for _, v in ipairs(Site.data) do 
                    table.insert(ListSite.ListSite, v.id)
                end
            end
            if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
                Cursor = Site.nextPageCursor
            else
                break
            end
            wait(1)
        end
        if #ListSite.ListSite > 10 then 
            FileLockLib.SaveFile("HopServerData.json", ListSite.ListSite)
        else
            print("Save fail (not enough servers)")
            wait(20)
        end
        FileLockLib.SetUpdateStatus("HopServerData.json", false)
        return NewHopServer(game.PlaceId)
    else
        local ServerIdJoined = {}
        if isfile("ServerIdJoined.json") then 
            ServerIdJoined = HttpService:JSONDecode(readfile("ServerIdJoined.json"))
        end
        for k, v in pairs(ServerIdJoined) do 
            if tick() - v > 60 * 40 then 
                ServerIdJoined[k] = nil
            end
        end
        local Site
        local c = 0
        while not Site and #Data > 0 do
            local r = math.random(1, #Data)
            local Sited = Data[r]
            if not ServerIdJoined[Sited] then 
                Site = Sited
            end
            c = c + 1
            if c % 100 == 0 then wait() end
        end
        if not Site then
            warn("Không tìm thấy server phù hợp, tải lại danh sách server mới!")
            return NewHopServer(game.PlaceId)
        end
        ServerIdJoined[Site] = tick()
        writefile("ServerIdJoined.json", HttpService:JSONEncode(ServerIdJoined))
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, Site, game.Players.LocalPlayer)
        print("Hoped!")
    end
end
NewHopServer()
