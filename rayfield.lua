local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local useStudio = RunService:IsStudio()
-- Отключаем все сетевые аналитические запросы
local requestsDisabled = true

local function loadWithTimeout(url: string, timeout: number?)
	assert(type(url) == "string", "Expected string, got " .. type(url))
	timeout = timeout or 5

	local requestCompleted = false
	local success, result = false, nil

	local requestThread = task.spawn(function()
		local fetchSuccess, fetchResult = pcall(game.HttpGet, game, url)
		if not fetchSuccess or not fetchResult or #fetchResult == 0 then
			success, result = false, fetchResult or "Empty response"
			requestCompleted = true
			return
		end

		local execSuccess, execResult = pcall(loadstring(fetchResult))
		success, result = execSuccess, execResult
		requestCompleted = true
	end)

	local timeoutThread = task.delay(timeout, function()
		if not requestCompleted then
			warn(`Request for {url} timed out after {timeout} seconds`)
			task.cancel(requestThread)
			result = "Request timed out"
			requestCompleted = true
		end
	end)

	while not requestCompleted do
		task.wait()
	end

	if coroutine.status(timeoutThread) ~= "dead" then
		task.cancel(timeoutThread)
	end

	if not success then
		warn(`Failed to process {url}: {result}`)
		return nil
	end

	return result
end

local InterfaceBuild = '3K3W'
local Release = "Build 1.68"
local RayfieldFolder = "Rayfield"
local ConfigurationFolder = RayfieldFolder .. "/Configurations"
local ConfigurationExtension = ".rfld"

local settingsTable = {
	General = {
		rayfieldOpen = { Type = 'bind', Value = 'K', Name = 'Rayfield Keybind' },
	},
	System = {
		-- Оставляем настройку на месте — пользователю видно, но аналитика всё равно отключена глобально
		usageAnalytics = { Type = 'toggle', Value = true, Name = 'Anonymised Analytics' },
	}
}

local overriddenSettings: { [string]: any } = {}
local function overrideSetting(category: string, name: string, value: any)
	overriddenSettings[`{category}.{name}`] = value
end

local function getSetting(category: string, name: string): any
	local key = `{category}.{name}`
	if overriddenSettings[key] ~= nil then
		return overriddenSettings[key]
	elseif settingsTable[category] and settingsTable[category][name] then
		return settingsTable[category][name].Value
	end
	return nil
end

-- Если аналитика глобально отключена, ставим значение настройки в false
if requestsDisabled then
	overrideSetting("System", "usageAnalytics", false)
end

local settingsCreated = false
local settingsInitialized = false
local cachedSettings

local prompt = useStudio and require(script.Parent.prompt) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/prompt.lua')
local requestFunc = (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request) or http_request or request

if not prompt and not useStudio then
	warn("Failed to load prompt library, using fallback.")
	prompt = { create = function() end }
end

local function loadSettings()
	local success = pcall(function()
		task.spawn(function()
			local fileContent
			if isfolder and isfolder(RayfieldFolder) and isfile and isfile(RayfieldFolder .. '/settings' .. ConfigurationExtension) then
				fileContent = readfile(RayfieldFolder .. '/settings' .. ConfigurationExtension)
			end

			local fileData = {}
			if fileContent then
				local decodeSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, fileContent)
				if decodeSuccess then
					fileData = decoded
				end
			end

			if not settingsCreated then
				cachedSettings = fileData
				return
			end

			if fileData then
				for categoryName, settingCategory in pairs(settingsTable) do
					if fileData[categoryName] then
						for settingName, setting in pairs(settingCategory) do
							if fileData[categoryName][settingName] and fileData[categoryName][settingName].Value then
								setting.Value = fileData[categoryName][settingName].Value
								if setting.Element and setting.Element.Set then
									setting.Element:Set(getSetting(categoryName, settingName))
								end
							end
						end
					end
				end
			end
			settingsInitialized = true
		end)
	end)

	if not success and writefile then
		warn('Rayfield had an issue accessing configuration saving capability.')
	end
end

loadSettings()

-- Заглушка отправки отчётов: если аналитика отключена, вызовы не делают ничего вредного
local analyticsLib
local sendReport = function(ev_n, sc_n) end

-- Аналитика полностью пропущена, потому что requestsDisabled = true
-- (Если later потребуется вернуть аналитику — можно положить сюда загрузчик как было раньше,
--  но по умолчанию сейчас всё отключено.)

local RayfieldLibrary = {
	Flags = {},
	Theme = {
		Default = {
			TextColor = Color3.fromRGB(240, 240, 240),
			Background = Color3.fromRGB(25, 25, 25),
			Topbar = Color3.fromRGB(34, 34, 34),
			Shadow = Color3.fromRGB(20, 20, 20),
			NotificationBackground = Color3.fromRGB(20, 20, 20),
			NotificationActionsBackground = Color3.fromRGB(230, 230, 230),
			TabBackground = Color3.fromRGB(80, 80, 80),
			TabStroke = Color3.fromRGB(85, 85, 85),
			TabBackgroundSelected = Color3.fromRGB(210, 210, 210),
			TabTextColor = Color3.fromRGB(240, 240, 240),
			SelectedTabTextColor = Color3.fromRGB(50, 50, 50),
			ElementBackground = Color3.fromRGB(35, 35, 35),
			ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
			SecondaryElementBackground = Color3.fromRGB(25, 25, 25),
			ElementStroke = Color3.fromRGB(50, 50, 50),
			SecondaryElementStroke = Color3.fromRGB(40, 40, 40),
			SliderBackground = Color3.fromRGB(50, 138, 220),
			SliderProgress = Color3.fromRGB(50, 138, 220),
			SliderStroke = Color3.fromRGB(58, 163, 255),
			ToggleBackground = Color3.fromRGB(30, 30, 30),
			ToggleEnabled = Color3.fromRGB(0, 146, 214),
			ToggleDisabled = Color3.fromRGB(100, 100, 100),
			ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
			ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
			ToggleDisabledOuterStroke = Color3.fromRGB(65, 65, 65),
			DropdownSelected = Color3.fromRGB(40, 40, 40),
			DropdownUnselected = Color3.fromRGB(30, 30, 30),
			InputBackground = Color3.fromRGB(30, 30, 30),
			InputStroke = Color3.fromRGB(65, 65, 65),
			PlaceholderColor = Color3.fromRGB(178, 178, 178)
		}
	}
}

local Rayfield = useStudio and script.Parent:FindFirstChild('Rayfield') or game:GetObjects("rbxassetid://10804731440")[1]
local correctBuild = Rayfield and Rayfield:FindFirstChild('Build') and Rayfield.Build.Value == InterfaceBuild

if not correctBuild then
	warn('Rayfield | Build Mismatch. Expected: ' .. InterfaceBuild .. ', Got: ' .. (Rayfield and Rayfield:FindFirstChild('Build') and Rayfield.Build.Value or 'None'))
end

if gethui then
	Rayfield.Parent = gethui()
elseif syn and syn.protect_gui then
	syn.protect_gui(Rayfield)
	Rayfield.Parent = CoreGui
else
	Rayfield.Parent = CoreGui
end

for _, oldInterface in ipairs(Rayfield.Parent:GetChildren()) do
	if oldInterface.Name == Rayfield.Name and oldInterface ~= Rayfield then
		oldInterface:Destroy()
	end
end

Rayfield.Enabled = false
Rayfield.DisplayOrder = 100

local Icons = useStudio and require(script.Parent.icons) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua')

local Main = Rayfield.Main
local MPrompt = Rayfield:FindFirstChild('Prompt')
local Topbar = Main.Topbar
local Elements = Main.Elements
local LoadingFrame = Main.LoadingFrame
local TabList = Main.TabList
local Notifications = Rayfield.Notifications
local dragBar = Rayfield:FindFirstChild('Drag')
local dragInteract = dragBar and dragBar.Interact
local dragBarCosmetic = dragBar and dragBar.Drag

local minSize = Vector2.new(1024, 768)
local useMobileSizing = Rayfield.AbsoluteSize.X < minSize.X and Rayfield.AbsoluteSize.Y < minSize.Y
local useMobilePrompt = UserInputService.TouchEnabled

local CFileName = nil
local CEnabled = false
local Minimised = false
local Hidden = false
local Debounce = false
local searchOpen = false
local globalLoaded = false
local rayfieldDestroyed = false
local SelectedTheme = RayfieldLibrary.Theme.Default

LoadingFrame.Version.Text = Release

local function getIcon(name: string)
	if not Icons then
		warn("Lucide Icons: Library not loaded.")
		return nil
	end
	name = string.lower(string.gsub(name, "^%s*(.-)%s*$", "%1"))
	local iconData = Icons['48px'][name]
	if not iconData then
		error(`Lucide Icons: Failed to find icon named "{name}"`, 2)
	end
	return {
		id = iconData[1],
		imageRectSize = Vector2.new(iconData[2][1], iconData[2][2]),
		imageRectOffset = Vector2.new(iconData[3][1], iconData[3][2]),
	}
end

local function getAssetUri(id: any): string
	if type(id) == "number" then
		return "rbxassetid://" .. id
	elseif type(id) == "string" then
		if Icons then
			local asset = getIcon(id)
			return "rbxassetid://" .. (asset and asset.id or 0)
		else
			warn("Rayfield | Cannot use Lucide icons as the library is not loaded.")
		end
	end
	return "rbxassetid://0"
end

local function ChangeTheme(Theme)
	if typeof(Theme) == 'string' and RayfieldLibrary.Theme[Theme] then
		SelectedTheme = RayfieldLibrary.Theme[Theme]
	elseif typeof(Theme) == 'table' then
		SelectedTheme = Theme
	else
		return
	end

	Main.BackgroundColor3 = SelectedTheme.Background
	Topbar.BackgroundColor3 = SelectedTheme.Topbar
	Topbar.CornerRepair.BackgroundColor3 = SelectedTheme.Topbar
	Main.Shadow.Image.ImageColor3 = SelectedTheme.Shadow
end

local function makeDraggable(object, dragObject)
	local dragging = false
	local relative

	dragObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			relative = object.AbsolutePosition - UserInputService:GetMouseLocation()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if dragging then
			local position = UserInputService:GetMouseLocation() + relative
			object.Position = UDim2.fromOffset(position.X, position.Y)
		end
	end)
end

local function PackColor(color)
	return { R = color.R * 255, G = color.G * 255, B = color.B * 255 }
end

local function UnpackColor(color)
	return Color3.fromRGB(color.R, color.G, color.B)
end

local function LoadConfiguration(Configuration)
	local success, data = pcall(HttpService.JSONDecode, HttpService, Configuration)
	if not success then
		warn('Rayfield: Failed to decode configuration file.')
		return
	end

	for flagName, flag in pairs(RayfieldLibrary.Flags) do
		if data[flagName] ~= nil then
			task.spawn(function()
				if flag.Type == "ColorPicker" then
					flag:Set(UnpackColor(data[flagName]))
				else
					flag:Set(data[flagName])
				end
			end)
		end
	end
	return true
end

local function SaveConfiguration()
	if not CEnabled or not globalLoaded then return end
	local data = {}
	for flag, value in pairs(RayfieldLibrary.Flags) do
		if value.Type == "ColorPicker" then
			data[flag] = PackColor(value.Color)
		else
			data[flag] = value.CurrentValue or value.CurrentKeybind or value.CurrentOption or value.Color
		end
	end
	if writefile then
		pcall(writefile, ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension, HttpService:JSONEncode(data))
	end
end

local function Hide(notify: boolean?)
	if Debounce or Hidden then return end
	Debounce, Hidden = true, true
	if notify then
		local keybind = getSetting("General", "rayfieldOpen")
		RayfieldLibrary:Notify({
			Title = "Interface Hidden",
			Content = `Press {keybind} to unhide the interface.`,
			Duration = 7,
			Image = "eye-off"
		})
	end
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), { Size = UDim2.new(0, 470, 0, 0), BackgroundTransparency = 1 }):Play()
	task.wait(0.5)
	Main.Visible = false
	Debounce = false
end

local function Unhide()
	if Debounce or not Hidden then return end
	Debounce, Hidden = true, false
	Main.Visible = true
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), { Size = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475), BackgroundTransparency = 0 }):Play()
	task.wait(0.5)
	Debounce = false
end

function RayfieldLibrary:Notify(data)
	task.spawn(function()
		local newNotification = Notifications.Template:Clone()
		newNotification.Name = data.Title or 'Notification'
		newNotification.Parent = Notifications
		newNotification.Visible = true
		newNotification.Title.Text = data.Title or "No Title"
		newNotification.Description.Text = data.Content or "No Content"
		newNotification.Icon.Image = getAssetUri(data.Image or 0)
		newNotification.BackgroundColor3 = SelectedTheme.Background
		newNotification.Position = UDim2.new(0, 0, 0, -80)
		TweenService:Create(newNotification, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
		local duration = data.Duration or math.clamp((#newNotification.Description.Text * 0.1) + 2.5, 3, 10)
		task.wait(duration)
		TweenService:Create(newNotification, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.new(0, 0, 0, -80) }):Play()
		task.wait(0.5)
		newNotification:Destroy()
	end)
end

function RayfieldLibrary:CreateWindow(Settings)
	if getgenv then getgenv().rayfieldCached = true end
	if not correctBuild and not Settings.DisableBuildWarnings then
		task.delay(3, function()
			RayfieldLibrary:Notify({ Title = 'Build Mismatch', Content = 'You are running an incompatible UI version. This may cause issues.', Image = "alert-triangle", Duration = 10 })
		end)
	end
	if Settings.ToggleUIKeybind then
		overrideSetting("General", "rayfieldOpen", Settings.ToggleUIKeybind)
	end
	-- Заменяем вызов аналитики на пустышку (ничего не делает)
	if not requestsDisabled then
		sendReport("window_created", Settings.Name or "Unknown")
	end
	Topbar.Title.Text = Settings.Name
	LoadingFrame.Title.Text = Settings.LoadingTitle or "Rayfield"
	LoadingFrame.Subtitle.Text = Settings.LoadingSubtitle or "Interface Suite"
	if Settings.Icon then
		Topbar.Icon.Image = getAssetUri(Settings.Icon)
		Topbar.Icon.Visible = true
		Topbar.Title.Position = UDim2.new(0, 47, 0.5, 0)
	end
	if Settings.Theme then
		ChangeTheme(Settings.Theme)
	end
	CEnabled = Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled
	if CEnabled then
		CFileName = Settings.ConfigurationSaving.FileName or tostring(game.PlaceId)
		ConfigurationFolder = Settings.ConfigurationSaving.FolderName or ConfigurationFolder
		if not isfolder(ConfigurationFolder) then
			makefolder(ConfigurationFolder)
		end
	end
	makeDraggable(Main, Topbar)
	if dragBar then makeDraggable(Main, dragInteract) end
	Rayfield.Enabled = true
	LoadingFrame.Visible = true
	TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0 }):Play()
	task.wait(2)
	LoadingFrame.Visible = false
	Topbar.Visible = true
	TweenService:Create(Main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), { Size = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475) }):Play()
	globalLoaded = true

	local Window = {}

	function Window:CreateTab(name, image)
		local Tab = {}
		function Tab:CreateButton(settings)
			return settings
		end
		function Tab:CreateToggle(settings)
			return settings
		end
		return Tab
	end

	function Window:ModifyTheme(newTheme)
		local success = pcall(ChangeTheme, newTheme)
		if success then
			RayfieldLibrary:Notify({Title = 'Theme Changed', Content = 'Theme updated successfully.', Image = "palette"})
		else
			RayfieldLibrary:Notify({Title = 'Theme Error', Content = 'Could not apply the selected theme.', Image = "alert-circle"})
		end
	end

	pcall(createSettings, Window)
	return Window
end

function RayfieldLibrary:SetVisibility(visibility: boolean)
	if visibility then Unhide() else Hide(false) end
end

function RayfieldLibrary:IsVisible(): boolean
	return not Hidden
end

function RayfieldLibrary:Destroy()
	rayfieldDestroyed = true
	if hideHotkeyConnection then hideHotkeyConnection:Disconnect() end
	Rayfield:Destroy()
end

function RayfieldLibrary:LoadConfiguration()
	if CEnabled and isfile and isfile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension) then
		local configData = readfile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension)
		if LoadConfiguration(configData) then
			RayfieldLibrary:Notify({Title = "Configuration Loaded", Content = "Your settings have been loaded.", Image = "download-cloud"})
		end
	end
	globalLoaded = true
end

Topbar.Hide.MouseButton1Click:Connect(function()
	Hide(not useMobileSizing)
end)

local hideHotkeyConnection = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode.Name == getSetting("General", "rayfieldOpen") then
		if Hidden then Unhide() else Hide() end
	end
end)

if MPrompt then
	MPrompt.Interact.MouseButton1Click:Connect(Unhide)
end

task.delay(4, function()
	RayfieldLibrary:LoadConfiguration()
end)

return RayfieldLibrary
