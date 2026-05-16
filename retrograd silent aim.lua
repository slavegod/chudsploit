local players_service = cloneref(game:GetService("Players"))
local local_player = players_service.LocalPlayer
local camera = workspace.CurrentCamera
local part

local wallbang = true

local env = getrenv()

local teammates = {}
local enemies = {}

local fov_circle = Drawing.new("Circle")
fov_circle.Radius = 165
fov_circle.Position = camera.ViewportSize / 2
fov_circle.Color = Color3.new(1, 1, 1)
fov_circle.Visible = true
fov_circle.Thickness = 2
fov_circle.NumSides = 64
fov_circle.Filled = false

local is_valid_player = function(player)
    if player.Character and player.Backpack then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0.1 then
            return true
        end
    end

    return false
end

local is_traitor = function(player)
    if is_valid_player(player) then
        if player.Backpack:FindFirstChild("Radar") or player.Character:FindFirstChild("Radar") then
            return true
        end
    end

    return false
end

local is_sherrif = function(player)
    if is_valid_player(player) then
        if player.Backpack:FindFirstChild("PoliceBadge") or player.Character:FindFirstChild("PoliceBadge") then
            return true
        end
    end

    return false
end

local is_teammate = function(player)
    if is_valid_player(player) then
        if env._G.Teammates[player] then
            return true
        end
    end

    return false
end

local clear_game = function()
    teammates = {}
    enemies = {}
end

game:GetService("ReplicatedStorage").Remotes.StateChanged.OnClientEvent:Connect(function()
    clear_game()
    task.wait(2) -- give it some time
    for index, player in ipairs(players_service:GetPlayers()) do
        if is_traitor(player) then
            teammates[player] = false
        elseif is_sherrif(player) and not is_traitor(local_player) then
            teammates[player] = true
        elseif is_teammate(player) then
            teammates[player] = true
        end
    end
end)

local get_target = function()
    local target, last_distance = nil, fov_circle.Radius
    for _, player in ipairs(players_service:GetPlayers()) do
        if not teammates[player] and not is_teammate(player) then
            local character = player.Character
            if not (character and player ~= local_player) then continue end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local root = humanoid and humanoid.RootPart
            if not (humanoid and root and humanoid.Health > 0.1) then continue end

            local target_part = character:FindFirstChild('Head')
            if not target_part then continue end

            local center = camera.ViewportSize / 2
            local screen_pos, on_screen = camera:WorldToViewportPoint(target_part.Position)
            local distance_2d = (center - Vector2.new(screen_pos.X, screen_pos.Y)).Magnitude
            if not (on_screen and distance_2d < last_distance) then continue end

            target = target_part
            last_distance = distance_2d
        end
    end
    return target
end

local target_func
for index, value in getgc(true) do
    if type(value) ~= "table" then continue end
    if not rawget(value, "Fire") then continue end

    local func = rawget(value, "Fire")
    if type(func) ~= "function" then continue end

    local source = debug.info(func, "s")
    if source == "ReplicatedStorage.Modules.Framework.ProjectileHandler" then
        target_func = func
    end
end

task.wait(1)

if not target_func then
    local_player:Kick("Failed To Get Fire Function.")
end

local fire
fire = hookfunction(target_func, function(self, ...)
    local args = {...}
    if not args[5] then return fire(self, unpack(args)) end
    if part then
        args[2] = (part.Position - args[1])
    end
    return fire(self, unpack(args))
end)

local namecall
namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if checkcaller() then return namecall(self, ...) end

    local args = {...}
    local method = getnamecallmethod()

    if method == "FireServer" and self.Name == "GunFire" and part then
        local bullets = args[1]
        for index, data in ipairs(bullets) do
            data[2] = (part.Position - data[1])
        end
        args[1] = bullets
    elseif method == "FireServer" and self.Name == "GunHit" and part then
        for index, data in ipairs(args) do
            if typeof(data) == "Instance" then
                args[index] = part
            end
        end
    end

    return namecall(self, unpack(args))
end))

task.spawn(function()
    while task.wait() do
        fov_circle.Position = camera.ViewportSize / 2
        part = get_target()
    end
end)