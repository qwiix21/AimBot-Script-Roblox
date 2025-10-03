local teamCheck = false
local fov = 150
local smoothing = 1
local isActive = false 
local targetPart = "Head" 
local showFOV = true
local activationKey = Enum.KeyCode.X
local aimbotEnabled = true
local minimizeKey = Enum.KeyCode.RightControl
local fovColor = Color3.fromRGB(255, 128, 128)
local fovThickness = 1.5
local fovTransparency = 1
local lockMode = false
local instantLock = false
local predictionEnabled = false
local predictionStrength = 0.15
local wallCheck = false
local triggerBot = false
local autoShoot = false
local rageMode = false
local aimMode = "Toggle"
local swapKey = Enum.KeyCode.C
local mouseAiming = false
local toggleState = false

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

local FOVring = nil
local loop = nil
local keyBindConnection = nil
local currentTarget = nil

local ignoredTeams = {}
local ignoredPlayers = {}

local ActivationKeyButton, MinimizeKeyButton, SwapKeyButton, ControlsLabel

local function getKeyName(keyCode)
    local keys = {
        A="A", B="B", C="C", D="D", E="E", F="F", G="G", H="H", I="I", J="J", K="K", L="L", M="M",
        N="N", O="O", P="P", Q="Q", R="R", S="S", T="T", U="U", V="V", W="W", X="X", Y="Y", Z="Z",
        One="1", Two="2", Three="3", Four="4", Five="5", Six="6", Seven="7", Eight="8", Nine="9", Zero="0",
        LeftShift="L-Shift", RightShift="R-Shift", LeftControl="L-Ctrl", RightControl="R-Ctrl",
        LeftAlt="L-Alt", RightAlt="R-Alt", Tab="Tab", CapsLock="Caps", Space="Space",
        Return="Enter", Backspace="Backspace", Delete="Delete", Insert="Insert",
        MouseButton1="LMB", MouseButton2="RMB", MouseButton3="MMB",
        MouseButton4="Mouse4", MouseButton5="Mouse5",
        Home="Home", End="End", PageUp="PgUp", PageDown="PgDown",
        Up="↑", Down="↓", Left="←", Right="→"
    }
    
    for i = 1, 12 do
        keys["F"..i] = "F"..i
    end
    
    local name = tostring(keyCode):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "")
    return keys[name] or name
end

local function saveSettings()
    local settings = {
        teamCheck = teamCheck, fov = fov, smoothing = smoothing,
        targetPart = targetPart, showFOV = showFOV, activationKey = activationKey,
        minimizeKey = minimizeKey, aimbotEnabled = aimbotEnabled,
        fovColor = {fovColor.R, fovColor.G, fovColor.B},
        fovThickness = fovThickness, fovTransparency = fovTransparency,
        lockMode = lockMode, instantLock = instantLock, predictionEnabled = predictionEnabled,
        predictionStrength = predictionStrength, wallCheck = wallCheck,
        triggerBot = triggerBot, autoShoot = autoShoot, rageMode = rageMode,
        aimMode = aimMode, mouseAiming = mouseAiming, swapKey = swapKey
    }
    
    writefile("aimbot_settings.json", game:GetService("HttpService"):JSONEncode(settings))
end

local function loadSettings()
    if isfile("aimbot_settings.json") then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile("aimbot_settings.json"))
        end)
        
        if success and data then
            teamCheck = data.teamCheck or teamCheck
            fov = data.fov or fov
            smoothing = data.smoothing or smoothing
            targetPart = data.targetPart or targetPart
            showFOV = data.showFOV or showFOV
            activationKey = data.activationKey or activationKey
            minimizeKey = data.minimizeKey or minimizeKey
            aimbotEnabled = data.aimbotEnabled or aimbotEnabled
            fovThickness = data.fovThickness or fovThickness
            fovTransparency = data.fovTransparency or fovTransparency
            lockMode = data.lockMode or lockMode
            instantLock = data.instantLock or instantLock
            predictionEnabled = data.predictionEnabled or predictionEnabled
            predictionStrength = data.predictionStrength or predictionStrength
            wallCheck = data.wallCheck or wallCheck
            triggerBot = data.triggerBot or triggerBot
            autoShoot = data.autoShoot or autoShoot
            rageMode = data.rageMode or rageMode
            aimMode = data.aimMode or aimMode
            mouseAiming = data.mouseAiming or mouseAiming
            swapKey = data.swapKey or swapKey
            
            if data.fovColor then
                fovColor = Color3.fromRGB(data.fovColor[1], data.fovColor[2], data.fovColor[3])
            end
        end
    end
end

local function checkWall(target)
    if not wallCheck then return false end
    
    local camera = workspace.CurrentCamera
    local direction = (target.Position - camera.CFrame.Position).Unit * (target.Position - camera.CFrame.Position).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {localPlayer.Character, target.Parent}
    
    local ray = workspace:Raycast(camera.CFrame.Position, direction, raycastParams)
    
    return ray ~= nil
end

local function predictPosition(target)
    if not predictionEnabled then return target.Position end
    
    local humanoid = target.Parent:FindFirstChild("Humanoid")
    if humanoid and humanoid.MoveDirection.Magnitude > 0 then
        local velocity = humanoid.MoveDirection * humanoid.WalkSpeed
        return target.Position + (velocity * predictionStrength)
    end
    
    return target.Position
end

local function getClosest(cframe)
    if mouseAiming then
        local target = nil
        local mag = math.huge
        local cam = workspace.CurrentCamera
        local mousePos = Vector2.new(mouse.X, mouse.Y)
        
        for i,v in pairs(Players:GetPlayers()) do
            if v.Character and v.Character:FindFirstChild(targetPart) and v.Character:FindFirstChild("Humanoid") and v.Character:FindFirstChild("HumanoidRootPart") and v ~= localPlayer then
                if teamCheck and localPlayer.Team and v.Team and localPlayer.Team == v.Team then
                    continue
                end
                
                if ignoredPlayers[v.Name] then continue end
                if v.Team and ignoredTeams[v.Team.Name] then continue end
                if v.Character.Humanoid.Health <= 0 then continue end
                if checkWall(v.Character[targetPart]) then continue end
                
                local targetPos = v.Character[targetPart].Position
                local ssPoint = cam:WorldToScreenPoint(targetPos)
                local screenPos = Vector2.new(ssPoint.X, ssPoint.Y)
                local magBuf = (screenPos - mousePos).Magnitude
                
                if magBuf < fov and magBuf < mag then
                    mag = magBuf
                    target = v
                end
            end
        end
        
        return target
    else
        local ray = Ray.new(cframe.Position, cframe.LookVector).Unit
        local target = nil
        local mag = math.huge
        
        for i,v in pairs(Players:GetPlayers()) do
            if v.Character and v.Character:FindFirstChild(targetPart) and v.Character:FindFirstChild("Humanoid") and v.Character:FindFirstChild("HumanoidRootPart") and v ~= localPlayer then
                if teamCheck and localPlayer.Team and v.Team and localPlayer.Team == v.Team then
                    continue
                end
                
                if ignoredPlayers[v.Name] then continue end
                if v.Team and ignoredTeams[v.Team.Name] then continue end
                if v.Character.Humanoid.Health <= 0 then continue end
                if checkWall(v.Character[targetPart]) then continue end
                
                local magBuf = (v.Character[targetPart].Position - ray:ClosestPoint(v.Character[targetPart].Position)).Magnitude
                
                if magBuf < mag then
                    mag = magBuf
                    target = v
                end
            end
        end
        
        return target
    end
end

local function moveMouse(x, y)
    if mouseAiming then
        mousemoverel(x, y)
    end
end

local function autoFire()
    if not autoShoot then return end
    
    mouse1press()
    wait(0.01)
    mouse1release()
end

local function checkTrigger()
    if not triggerBot then return end
    
    local target = mouse.Target
    if target and target.Parent:FindFirstChild("Humanoid") then
        local player = Players:GetPlayerFromCharacter(target.Parent)
        if player and player ~= localPlayer then
            if teamCheck and localPlayer.Team and player.Team and localPlayer.Team == player.Team then
                return
            end
            
            if ignoredPlayers[player.Name] then return end
            if player.Team and ignoredTeams[player.Team.Name] then return end
            
            autoFire()
        end
    end
end

local function cleanup()
    if loop then
        loop:Disconnect()
        loop = nil
    end
    currentTarget = nil
    isActive = false
end

local function toggleAimbot(state)
    if state then
        if loop then loop:Disconnect() end
        
        loop = RunService.RenderStepped:Connect(function()
            if not aimbotEnabled or not isActive then return end
            
            checkTrigger()
            
            local cam = workspace.CurrentCamera
            local zz = workspace.CurrentCamera.ViewportSize/2
            
            if lockMode and currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild(targetPart) then
                if currentTarget.Character.Humanoid.Health > 0 then
                    local targetPos = predictPosition(currentTarget.Character[targetPart])
                    local ssHeadPoint = cam:WorldToScreenPoint(targetPos)
                    ssHeadPoint = Vector2.new(ssHeadPoint.X, ssHeadPoint.Y)
                    
                    local mousePos = mouseAiming and Vector2.new(mouse.X, mouse.Y) or zz
                    if (ssHeadPoint - mousePos).Magnitude < fov * 2 then
                        local aimSpeed = instantLock and 1 or (rageMode and 0.8 or smoothing / 100)
                        
                        if mouseAiming then
                            local delta = ssHeadPoint - mousePos
                            local moveDelta = delta / (smoothing * 0.2)
                            moveMouse(moveDelta.X, moveDelta.Y)
                        else
                            workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetPos), aimSpeed)
                        end
                        
                        if autoShoot and (ssHeadPoint - mousePos).Magnitude < 30 then
                            autoFire()
                        end
                        return
                    else
                        currentTarget = nil
                    end
                end
            end
            
            local curTar = getClosest(cam.CFrame)
            if curTar and curTar.Character and curTar.Character:FindFirstChild(targetPart) then
                if lockMode then
                    currentTarget = curTar
                end
                
                local targetPos = predictPosition(curTar.Character[targetPart])
                local ssHeadPoint = cam:WorldToScreenPoint(targetPos)
                ssHeadPoint = Vector2.new(ssHeadPoint.X, ssHeadPoint.Y)
                local mousePos = mouseAiming and Vector2.new(mouse.X, mouse.Y) or zz
                
                if (ssHeadPoint - mousePos).Magnitude < fov then
                    local aimSpeed = instantLock and 1 or (rageMode and 0.8 or smoothing / 100)
                    
                    if mouseAiming then
                        local delta = ssHeadPoint - mousePos
                        local moveDelta = delta / (smoothing * 0.2)
                        moveMouse(moveDelta.X, moveDelta.Y)
                    else
                        workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetPos), aimSpeed)
                    end
                    
                    if autoShoot and (ssHeadPoint - mousePos).Magnitude < 30 then
                        autoFire()
                    end
                end
            end
        end)
    else
        cleanup()
    end
end

local function createFOVRing()
    if FOVring then FOVring:Remove() end
    
    FOVring = Drawing.new("Circle")
    FOVring.Visible = showFOV
    FOVring.Thickness = fovThickness
    FOVring.Radius = fov
    FOVring.Transparency = fovTransparency
    FOVring.Color = fovColor
    FOVring.Position = mouseAiming and Vector2.new(mouse.X, mouse.Y) or workspace.CurrentCamera.ViewportSize/2
    
    local function updatePosition()
        if FOVring then
            FOVring.Position = mouseAiming and Vector2.new(mouse.X, mouse.Y) or workspace.CurrentCamera.ViewportSize/2
        end
    end
    
    RunService.RenderStepped:Connect(updatePosition)
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePosition)
end

local function updateFOVRing()
    if FOVring then
        FOVring.Visible = showFOV
        FOVring.Color = fovColor
        FOVring.Thickness = fovThickness
        FOVring.Transparency = fovTransparency
        FOVring.Radius = fov
    end
end

local function updateControlsText()
    if ControlsLabel then
        local newText = "Controls:\n" .. 
                       "Activation: " .. getKeyName(activationKey) .. " (" .. aimMode .. ")\n" ..
                       "Target Swap: " .. getKeyName(swapKey) .. "\n" ..
                       "Minimize: " .. getKeyName(minimizeKey) .. "\n\n" ..
                       "Features:\n" ..
                       "• Iron-grip target locking\n" ..
                       "• Movement prediction\n" ..
                       "• Wall penetration check\n" ..
                       "• Trigger bot & auto-shoot\n" ..
                       "• Mouse/Camera aiming modes\n" ..
                       "• Hold/Toggle activation\n" ..
                       "• Team/player exclusions"
        
        ControlsLabel:SetDesc(newText)
    end
end

local function shutdownScript()
    cleanup()
    if FOVring then
        FOVring:Remove()
        FOVring = nil
    end
end

loadSettings()

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "🔥 Elite Aimbot v0.8",
    SubTitle = "Ultimate aiming solution",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = minimizeKey
})

local function bindKey(keyName, callback)
    if keyBindConnection then keyBindConnection:Disconnect() end
    
    Fluent:Notify({
        Title = "Key Setup",
        Content = "Press any key/mouse button to set as " .. keyName,
        Duration = 5
    })
    
    keyBindConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton) then
            local newKey = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
            callback(newKey)
            keyBindConnection:Disconnect()
            keyBindConnection = nil
            saveSettings()
            Fluent:Notify({
                Title = "Key Changed",
                Content = "New " .. keyName .. ": " .. getKeyName(newKey),
                Duration = 3
            })
        end
    end)
end

local windowVisible = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == minimizeKey then
        windowVisible = not windowVisible
        if windowVisible then
            Window:Minimize(false)
        end
    end
end)

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "settings" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "sword" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Exclusions = Window:AddTab({ Title = "Exclusions", Icon = "shield" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "sliders" }),
    Advanced = Window:AddTab({ Title = "Advanced", Icon = "cpu" }),
    Info = Window:AddTab({ Title = "Information", Icon = "info" })
}

Tabs.Main:AddToggle("AimbotEnabled", {
    Title = "Enable Aimbot",
    Description = "Master aimbot toggle",
    Default = aimbotEnabled
}):OnChanged(function(value)
    aimbotEnabled = value
    saveSettings()
end)

Tabs.Main:AddToggle("TeamCheck", {
    Title = "Team Check",
    Description = "Ignore teammates",
    Default = teamCheck
}):OnChanged(function(value)
    teamCheck = value
    saveSettings()
end)

Tabs.Main:AddSlider("FOV", {
    Title = "FOV (Field of View)",
    Description = "Target detection radius",
    Default = fov,
    Min = 50,
    Max = 800,
    Rounding = 0
}):OnChanged(function(value)
    fov = value
    if FOVring then FOVring.Radius = fov end
    saveSettings()
end)

Tabs.Main:AddSlider("Smoothing", {
    Title = "Smoothing",
    Description = "Aiming speed (1 = instant, 50 = slow)",
    Default = smoothing,
    Min = 1,
    Max = 50,
    Rounding = 1
}):OnChanged(function(value)
    smoothing = value
    saveSettings()
end)

Tabs.Main:AddDropdown("TargetPart", {
    Title = "Target Body Part",
    Description = "Select aiming target",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Multi = false,
    Default = targetPart
}):OnChanged(function(value)
    targetPart = value
    saveSettings()
end)

Tabs.Main:AddDropdown("AimMode", {
    Title = "Aim Mode",
    Description = "Hold = hold key to aim, Toggle = press to toggle",
    Values = {"Hold", "Toggle"},
    Multi = false,
    Default = aimMode
}):OnChanged(function(value)
    aimMode = value
    if aimMode == "Toggle" and isActive then
        toggleState = true
    else
        toggleState = false
    end
    updateControlsText()
    saveSettings()
end)

Tabs.Main:AddToggle("MouseAiming", {
    Title = "Mouse Aiming",
    Description = "Use mouse movement instead of camera",
    Default = mouseAiming
}):OnChanged(function(value)
    mouseAiming = value
    saveSettings()
end)

SwapKeyButton = Tabs.Main:AddButton({
    Title = "Target Swap Key: " .. getKeyName(swapKey),
    Description = "Key to swap between Head/Body",
    Callback = function()
        bindKey("swap key", function(newKey)
            swapKey = newKey
            SwapKeyButton:SetTitle("Target Swap Key: " .. getKeyName(swapKey))
        end)
    end
})

Tabs.Combat:AddToggle("LockMode", {
    Title = "Target Lock Mode",
    Description = "Iron-grip lock onto target (hard to break)",
    Default = lockMode
}):OnChanged(function(value)
    lockMode = value
    if not value then currentTarget = nil end
    saveSettings()
end)

Tabs.Combat:AddToggle("InstantLock", {
    Title = "Instant Lock",
    Description = "Instant snap to target (no smoothing)",
    Default = instantLock
}):OnChanged(function(value)
    instantLock = value
    saveSettings()
end)

Tabs.Combat:AddToggle("RageMode", {
    Title = "Rage Mode",
    Description = "Ultra-aggressive aiming (very fast)",
    Default = rageMode
}):OnChanged(function(value)
    rageMode = value
    saveSettings()
end)

Tabs.Combat:AddToggle("PredictionEnabled", {
    Title = "Movement Prediction",
    Description = "Predict target movement",
    Default = predictionEnabled
}):OnChanged(function(value)
    predictionEnabled = value
    saveSettings()
end)

Tabs.Combat:AddSlider("PredictionStrength", {
    Title = "Prediction Strength",
    Description = "How much to predict movement",
    Default = predictionStrength,
    Min = 0,
    Max = 1,
    Rounding = 2
}):OnChanged(function(value)
    predictionStrength = value
    saveSettings()
end)

Tabs.Combat:AddToggle("WallCheck", {
    Title = "Wall Check",
    Description = "Don't aim through walls",
    Default = wallCheck
}):OnChanged(function(value)
    wallCheck = value
    saveSettings()
end)

Tabs.Combat:AddToggle("TriggerBot", {
    Title = "Trigger Bot",
    Description = "Auto-shoot when hovering over enemy",
    Default = triggerBot
}):OnChanged(function(value)
    triggerBot = value
    saveSettings()
end)

Tabs.Combat:AddToggle("AutoShoot", {
    Title = "Auto Shoot",
    Description = "Auto-shoot when aimed at target",
    Default = autoShoot
}):OnChanged(function(value)
    autoShoot = value
    saveSettings()
end)

Tabs.Visuals:AddToggle("ShowFOV", {
    Title = "Show FOV Circle",
    Description = "Display field of view circle",
    Default = showFOV
}):OnChanged(function(value)
    showFOV = value
    updateFOVRing()
    saveSettings()
end)

Tabs.Visuals:AddColorpicker("FOVColor", {
    Title = "FOV Circle Color",
    Description = "Choose circle color",
    Default = fovColor
}):OnChanged(function(value)
    fovColor = value
    updateFOVRing()
    saveSettings()
end)

Tabs.Visuals:AddSlider("FOVThickness", {
    Title = "FOV Circle Thickness",
    Description = "Circle line thickness",
    Default = fovThickness,
    Min = 1,
    Max = 10,
    Rounding = 1
}):OnChanged(function(value)
    fovThickness = value
    updateFOVRing()
    saveSettings()
end)

Tabs.Visuals:AddSlider("FOVTransparency", {
    Title = "FOV Circle Transparency",
    Description = "Circle transparency (0 = invisible, 1 = fully visible)",
    Default = fovTransparency,
    Min = 0,
    Max = 1,
    Rounding = 2
}):OnChanged(function(value)
    fovTransparency = value
    updateFOVRing()
    saveSettings()
end)

local teamToggles = {}
local playerToggles = {}

local function updateExclusionLists()
    for _, team in pairs(Teams:GetTeams()) do
        if not teamToggles[team.Name] then
            teamToggles[team.Name] = Tabs.Exclusions:AddToggle("Team_" .. team.Name, {
                Title = "Ignore " .. team.Name,
                Description = "Don't aim at this team",
                Default = false
            })
            teamToggles[team.Name]:OnChanged(function(value)
                ignoredTeams[team.Name] = value or nil
            end)
        end
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and not playerToggles[player.Name] then
            playerToggles[player.Name] = Tabs.Exclusions:AddToggle("Player_" .. player.Name, {
                Title = "Ignore " .. player.Name,
                Description = "Don't aim at this player",
                Default = false
            })
            playerToggles[player.Name]:OnChanged(function(value)
                ignoredPlayers[player.Name] = value or nil
            end)
        end
    end
end

updateExclusionLists()
Players.PlayerAdded:Connect(updateExclusionLists)
Teams.ChildAdded:Connect(updateExclusionLists)

Tabs.Exclusions:AddButton({
    Title = "Clear All Exclusions",
    Description = "Remove all ignored teams and players",
    Callback = function()
        ignoredTeams = {}
        ignoredPlayers = {}
        
        for _, toggle in pairs(teamToggles) do
            toggle:SetValue(false)
        end
        for _, toggle in pairs(playerToggles) do
            toggle:SetValue(false)
        end
        
        Fluent:Notify({
            Title = "Exclusions Cleared",
            Content = "All exclusions have been removed",
            Duration = 3
        })
    end
})

ActivationKeyButton = Tabs.Settings:AddButton({
    Title = "Activation Key: " .. getKeyName(activationKey),
    Description = "Click to change activation key",
    Callback = function()
        bindKey("activation key", function(newKey)
            activationKey = newKey
            ActivationKeyButton:SetTitle("Activation Key: " .. getKeyName(activationKey))
            updateControlsText()
        end)
    end
})

MinimizeKeyButton = Tabs.Settings:AddButton({
    Title = "Minimize Key: " .. getKeyName(minimizeKey),
    Description = "Click to change minimize key",
    Callback = function()
        bindKey("minimize key", function(newKey)
            minimizeKey = newKey
            Window.MinimizeKey = minimizeKey
            MinimizeKeyButton:SetTitle("Minimize Key: " .. getKeyName(minimizeKey))
            updateControlsText()
        end)
    end
})

Tabs.Advanced:AddButton({
    Title = "Force Unlock Target",
    Description = "Release current locked target",
    Callback = function()
        currentTarget = nil
        Fluent:Notify({
            Title = "Target Unlocked",
            Content = "Current target has been released",
            Duration = 2
        })
    end
})

Tabs.Advanced:AddButton({
    Title = "Reset All Settings",
    Description = "Reset all settings to default values",
    Callback = function()
        teamCheck = false
        fov = 150
        smoothing = 1
        targetPart = "Head"
        showFOV = true
        activationKey = Enum.KeyCode.E
        minimizeKey = Enum.KeyCode.RightControl
        fovColor = Color3.fromRGB(255, 128, 128)
        fovThickness = 1.5
        fovTransparency = 1
        lockMode = false
        instantLock = false
        predictionEnabled = false
        predictionStrength = 0.15
        wallCheck = false
        triggerBot = false
        autoShoot = false
        rageMode = false
        aimMode = "Hold"
        mouseAiming = false
        toggleState = false
        ignoredTeams = {}
        ignoredPlayers = {}
        
        saveSettings()
        updateFOVRing()
        updateControlsText()
        
        Fluent:Notify({
            Title = "Settings Reset",
            Content = "All settings have been reset to default",
            Duration = 3
        })
    end
})

Tabs.Advanced:AddButton({
    Title = "Emergency Shutdown",
    Description = "Completely disable the script",
    Callback = function()
        shutdownScript()
        Fluent:Notify({
            Title = "Script Shutdown",
            Content = "Aimbot has been completely disabled",
            Duration = 3
        })
    end
})

ControlsLabel = Tabs.Info:AddParagraph({
    Title = "Controls and Features",
    Content = ""
})

Tabs.Info:AddParagraph({
    Title = "Ultimate Features",
    Content = "• Iron-grip target locking\n• Movement prediction system\n• Wall penetration detection\n• Trigger bot with auto-shoot\n• Mouse & Camera aiming modes\n• Hold & Toggle activation\n• Rage mode for competitive play\n• Advanced exclusion system\n• Professional-grade accuracy"
})

Tabs.Info:AddButton({
    Title = "GitHub Repository",
    Description = "Open script repository",
    Callback = function()
        setclipboard("https://github.com/qwiix21/AimBot-Script-Roblox")
        Fluent:Notify({
            Title = "Link Copied",
            Content = "GitHub repository link copied to clipboard",
            Duration = 3
        })
    end
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == activationKey or input.UserInputType == activationKey then
        if aimMode == "Hold" then
            isActive = true
            toggleAimbot(true)
        elseif aimMode == "Toggle" then
            toggleState = not toggleState
            isActive = toggleState
            toggleAimbot(toggleState)
        end
    elseif input.KeyCode == swapKey then
        targetPart = targetPart == "Head" and "HumanoidRootPart" or "Head"
        saveSettings()
        Fluent:Notify({
            Title = "Target Swapped",
            Content = "Now targeting: " .. targetPart,
            Duration = 2
        })
    elseif input.KeyCode == Enum.KeyCode.Delete then
        shutdownScript()
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if (input.KeyCode == activationKey or input.UserInputType == activationKey) and aimMode == "Hold" then
        isActive = false
        toggleAimbot(false)
    end
end)

createFOVRing()
updateControlsText()

game.Players.PlayerRemoving:Connect(function(player)
    if player == localPlayer then
        shutdownScript()
    end
end)

print("Elite Aimbot v0.8 loaded!")
print("Activation key: " .. getKeyName(activationKey) .. " (" .. aimMode .. " mode)")
print("Mouse aiming: " .. (mouseAiming and "ON" or "OFF"))
print("Features: Lock Mode, Prediction, Wall Check, Trigger Bot, Hold/Toggle")
