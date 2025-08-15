-- SCRIPT START TIME
local startTime = tick()

-- CONFIG
local KEY_TOGGLE = Enum.KeyCode.P
local PICKUP_DELAY = 1            -- wait 1 second on part before collecting
local PARTS_BEFORE_COOLDOWN = 5
local COOLDOWN_TIME = 10
local SAFEZONE = Vector3.new(1083, -36, -47)
local NAMES = { Gear = true, Spring = true, Blade = true }
local VISIBLE_T = 0.05
local ESP_COLOR = Color3.fromRGB(255, 182, 193) -- femboy pink
local ESP_FONT = Enum.Font.IndieFlower
local ESP_TEXT_SIZE = 20

-- SERVICES
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local collecting = false
local running = false
local collectedCount = 0
local tracked = {}
local connections = {}
local esps = {}

-- HELPER: Notifications with image
local function notify(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = duration or 3,
        Icon = "rbxassetid://109122098413314"
    })
end

-- Load notification
notify("xori's partfarm script", string.format("Loaded in %.3f seconds", tick() - startTime), 5)

-- TRACKING
local function isTargetBasePart(inst)
    if not inst:IsA("BasePart") then return false end
    if NAMES[inst.Name] then return true end
    local p = inst.Parent
    if p and NAMES[p.Name] then return true end
    return false
end

local function track(part)
    if tracked[part] then return end
    if not part:IsDescendantOf(Workspace) then return end
    tracked[part] = true
    connections[part] = {}

    table.insert(connections[part], part:GetPropertyChangedSignal("Transparency"):Connect(function()
        if part.Transparency >= 1 or not part.Parent then
            tracked[part] = nil
            if esps[part] then
                esps[part]:Destroy()
                esps[part] = nil
            end
        end
    end))
    table.insert(connections[part], part.AncestryChanged:Connect(function(_, parent)
        if not parent then
            tracked[part] = nil
            if esps[part] then
                esps[part]:Destroy()
                esps[part] = nil
            end
        end
    end))

    -- ESP
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0,150,0,50)
    bill.Adornee = part
    bill.AlwaysOnTop = true
    local label = Instance.new("TextLabel", bill)
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = part.Name
    label.TextColor3 = ESP_COLOR
    label.Font = ESP_FONT
    label.TextSize = ESP_TEXT_SIZE
    esps[part] = bill
    bill.Parent = player:WaitForChild("PlayerGui")
end

local function untrack(part)
    if not tracked[part] then return end
    tracked[part] = nil
    if connections[part] then
        for _,c in ipairs(connections[part]) do pcall(function() c:Disconnect() end) end
        connections[part] = nil
    end
    if esps[part] then
        esps[part]:Destroy()
        esps[part] = nil
    end
end

local function seed()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if isTargetBasePart(d) and d.Transparency <= VISIBLE_T then
            track(d)
        end
    end
end

Workspace.DescendantAdded:Connect(function(obj)
    if isTargetBasePart(obj) and obj.Transparency <= VISIBLE_T then
        track(obj)
    end
end)

Workspace.DescendantRemoving:Connect(function(obj)
    if tracked[obj] then untrack(obj) end
end)

-- PROXIMITY PROMPT
local function findPrompt(part)
    local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then return prompt end
    if part.Parent then
        prompt = part.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    return prompt
end

local function triggerPrompt(part)
    local prompt = findPrompt(part)
    if not prompt or not prompt.Enabled then return end
    pcall(function()
        fireproximityprompt(prompt, prompt.HoldDuration or 0.05)
    end)
end

-- TELEPORT TO PART AND COLLECT
local function goToPart(part)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
    -- Wait to simulate collecting
    task.wait(PICKUP_DELAY)
    triggerPrompt(part)
end

-- FIND ANY PART
local function findAnyPart()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest = nil
    local closestDist = math.huge
    for part,_ in pairs(tracked) do
        if part and part.Parent and part.Transparency < 1 then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist < closestDist then
                closest = part
                closestDist = dist
            end
        end
    end
    return closest
end

-- MAIN LOOP
local function runLoop()
    if running then return end
    running = true
    seed()
    collectedCount = 0

    while collecting do
        local part = findAnyPart()
        if not part then
            task.wait(0.5)
            RunService.Heartbeat:Wait()
            continue
        end

        goToPart(part)
        collectedCount = collectedCount + 1

        -- cooldown after 5 parts
        if collectedCount % PARTS_BEFORE_COOLDOWN == 0 then
            notify("anticheat cooldown", "going to safe zone for "..COOLDOWN_TIME.."s", COOLDOWN_TIME)
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(SAFEZONE)
            end
            task.wait(COOLDOWN_TIME)
        end

        RunService.Heartbeat:Wait()
    end

    running = false
end

-- TOGGLE
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == KEY_TOGGLE then
        collecting = not collecting
        if collecting then
            notify("Part Farming", "ON", 2)
            task.spawn(runLoop)
        else
            notify("Part Farming", "OFF", 2)
        end
    end
end)
