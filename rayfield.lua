print("Скрипт запущен. Инициализация сервисов...")
local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local useStudio = RunService:IsStudio()
print("Режим работы: " .. (useStudio and "Studio" or "В игре"))

local function loadWithTimeout(url: string, timeout: number?)
	assert(type(url) == "string", "Ожидалась строка, получено " .. type(url))
	timeout = timeout or 5
	print("[loadWithTimeout] Загрузка URL: " .. url .. " с таймаутом " .. timeout .. " секунд.")

	local requestCompleted = false
	local success, result = false, nil

	local requestThread = task.spawn(function()
		print("[loadWithTimeout] Запуск pcall для game.HttpGet: " .. url)
		local fetchSuccess, fetchResult = pcall(game.HttpGet, game, url)
		if not fetchSuccess then
			warn("[loadWithTimeout] Ошибка при выполнении HttpGet: ", fetchResult)
			success, result = false, fetchResult
			requestCompleted = true
			return
		end

		if not fetchResult or #fetchResult == 0 then
			warn("[loadWithTimeout] HttpGet вернул пустой или неверный результат.")
			success, result = false, fetchResult or "Пустой ответ"
			requestCompleted = true
			return
		end
		
		print("[loadWithTimeout] HttpGet успешно завершен. Длина ответа: " .. #fetchResult)
		print("[loadWithTimeout] Запуск pcall для loadstring.")
		local execSuccess, execResult = pcall(loadstring(fetchResult))
		if not execSuccess then
			warn("[loadWithTimeout] Ошибка при выполнении loadstring: ", execResult)
		else
			print("[loadWithTimeout] loadstring успешно выполнен.")
		end

		success, result = execSuccess, execResult
		requestCompleted = true
	end)

	local timeoutThread = task.delay(timeout, function()
		if not requestCompleted then
			warn("[loadWithTimeout] Запрос превысил таймаут (" .. timeout .. "с) для URL: " .. url)
			task.cancel(requestThread)
			result = "Запрос превысил таймаут"
			requestCompleted = true
		end
	end)

	while not requestCompleted do
		task.wait()
	end
	
	print("[loadWithTimeout] Цикл ожидания завершен.")

	if coroutine.status(timeoutThread) ~= "dead" then
		print("[loadWithTimeout] Отмена потока таймаута.")
		task.cancel(timeoutThread)
	end

	if not success then
		warn("[loadWithTimeout] Не удалось загрузить и выполнить код с URL: " .. url .. ". Причина: " .. tostring(result))
		return nil
	end

	print("[loadWithTimeout] Успешно загружен и выполнен код с URL: " .. url)
	return result
end

local InterfaceBuild = '3K3W'
local Release = "Build 1.68"
local RayfieldFolder = "Rayfield"
local ConfigurationFolder = RayfieldFolder .. "/Configurations"
local ConfigurationExtension = ".rfld"
print("Переменные окружения установлены. Build: " .. InterfaceBuild)

local settingsTable = {
	General = {
		rayfieldOpen = { Type = 'bind', Value = 'K', Name = 'Rayfield Keybind' },
	}
}

local overriddenSettings: { [string]: any } = {}
local function overrideSetting(category: string, name: string, value: any)
	print(string.format("[Настройки] Переопределение настройки: '%s.%s' на значение '%s'", category, name, tostring(value)))
	overriddenSettings[`{category}.{name}`] = value
end

local function getSetting(category: string, name: string): any
	local key = `{category}.{name}`
	if overriddenSettings[key] ~= nil then
		print(string.format("[Настройки] Получение переопределенной настройки: '%s' = '%s'", key, tostring(overriddenSettings[key])))
		return overriddenSettings[key]
	elseif settingsTable[category] and settingsTable[category][name] then
		print(string.format("[Настройки] Получение стандартной настройки: '%s' = '%s'", key, tostring(settingsTable[category][name].Value)))
		return settingsTable[category][name].Value
	end
	warn(string.format("[Настройки] Настройка не найдена: '%s'", key))
	return nil
end

local settingsCreated = false
local settingsInitialized = false
local cachedSettings

print("Попытка загрузки 'prompt' модуля...")
local prompt = useStudio and require(script.Parent.prompt) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/prompt.lua')
if not prompt and not useStudio then
	warn("'prompt' модуль не был загружен. Будет использована заглушка.")
	prompt = { create = function() print("[prompt-заглушка] create вызван.") end }
else
	print("'prompt' модуль успешно загружен.")
end


local function loadSettings()
	print("[Настройки] Запуск функции loadSettings.")
	local success = pcall(function()
		task.spawn(function()
			print("[Настройки] Запущен новый поток для загрузки настроек.")
			local fileContent
			local settingsPath = RayfieldFolder .. '/settings' .. ConfigurationExtension
			
			if isfolder and isfolder(RayfieldFolder) then
				print("[Настройки] Папка Rayfield существует.")
				if isfile and isfile(settingsPath) then
					print("[Настройки] Файл настроек найден: " .. settingsPath)
					fileContent = readfile(settingsPath)
					print("[Настройки] Содержимое файла прочитано. Длина: " .. #fileContent)
				else
					warn("[Настройки] Файл настроек не найден по пути: " .. settingsPath)
				end
			else
				warn("[Настройки] Папка Rayfield не существует.")
			end


			local fileData = {}
			if fileContent then
				print("[Настройки] Попытка декодирования JSON из файла настроек.")
				local decodeSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, fileContent)
				if decodeSuccess then
					print("[Настройки] JSON успешно декодирован.")
					fileData = decoded
				else
					warn("[Настройки] Ошибка декодирования JSON: ", decoded)
				end
			end

			if not settingsCreated then
				print("[Настройки] Элементы UI еще не созданы. Кэширование настроек.")
				cachedSettings = fileData
				return
			end
			
			print("[Настройки] Элементы UI уже созданы. Применение настроек.")
			if fileData then
				for categoryName, settingCategory in pairs(settingsTable) do
					if fileData[categoryName] then
						for settingName, setting in pairs(settingCategory) do
							if fileData[categoryName][settingName] and fileData[categoryName][settingName].Value then
								print(string.format("[Настройки] Применение '%s.%s' со значением '%s'", categoryName, settingName, tostring(fileData[categoryName][settingName].Value)))
								setting.Value = fileData[categoryName][settingName].Value
								if setting.Element and setting.Element.Set then
									print(string.format("[Настройки] Обновление элемента UI для '%s.%s'", categoryName, settingName))
									setting.Element:Set(getSetting(categoryName, settingName))
								end
							end
						end
					end
				end
			end
			settingsInitialized = true
			print("[Настройки] Инициализация настроек завершена.")
		end)
	end)
	if not success then
		warn('Rayfield столкнулся с проблемой при доступе к возможности сохранения конфигурации.')
	end
end

loadSettings()

-- === Секция аналитики удалена ===
print("Секция аналитики пропущена.")

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
print("Библиотека Rayfield и тема по умолчанию определены.")


print("Загрузка основного UI Rayfield...")
local Rayfield = useStudio and script.Parent:FindFirstChild('Rayfield') or game:GetObjects("rbxassetid://10804731440")[1]
local correctBuild = Rayfield and Rayfield:FindFirstChild('Build') and Rayfield.Build.Value == InterfaceBuild

if not correctBuild then
	warn('Rayfield | Несоответствие сборки. Ожидалось: ' .. InterfaceBuild .. ', Получено: ' .. (Rayfield and Rayfield:FindFirstChild('Build') and Rayfield.Build.Value or 'None'))
else
	print("Версия сборки UI Rayfield совпадает: " .. InterfaceBuild)
end


if gethui then
	print("Используется gethui() для родительского элемента.")
	Rayfield.Parent = gethui()
elseif syn and syn.protect_gui then
	print("Используется syn.protect_gui() для родительского элемента.")
	syn.protect_gui(Rayfield)
	Rayfield.Parent = CoreGui
else
	print("Используется CoreGui для родительского элемента.")
	Rayfield.Parent = CoreGui
end
print("Родитель для Rayfield UI установлен: " .. Rayfield.Parent.Name)

print("Поиск и удаление старых версий интерфейса...")
for _, oldInterface in ipairs(Rayfield.Parent:GetChildren()) do
	if oldInterface.Name == Rayfield.Name and oldInterface ~= Rayfield then
		print("Найден и удален старый экземпляр Rayfield: " .. oldInterface:GetFullName())
		oldInterface:Destroy()
	end
end
print("Очистка старых интерфейсов завершена.")


Rayfield.Enabled = false
Rayfield.DisplayOrder = 100

print("Загрузка иконок...")
local Icons = useStudio and require(script.Parent.icons) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua')
if Icons then
	print("Иконки успешно загружены.")
else
	warn("Не удалось загрузить иконки.")
end


local Main = Rayfield.Main
local MPrompt = Rayfield:FindFirstChild('Prompt')
local Topbar = Main.Topbar
local LoadingFrame = Main.LoadingFrame
local Notifications = Rayfield.Notifications
local dragBar = Rayfield:FindFirstChild('Drag')
local dragInteract = dragBar and dragBar.Interact

local minSize = Vector2.new(1024, 768)
local useMobileSizing = Rayfield.AbsoluteSize.X < minSize.X and Rayfield.AbsoluteSize.Y < minSize.Y
local useMobilePrompt = UserInputService.TouchEnabled
print("Переменные UI инициализированы. Мобильный режим: " .. tostring(useMobileSizing))

local CFileName = nil
local CEnabled = false
local Hidden = false
local Debounce = false
local globalLoaded = false
local rayfieldDestroyed = false
local SelectedTheme = RayfieldLibrary.Theme.Default

LoadingFrame.Version.Text = Release
print("Версия на экране загрузки установлена: " .. Release)


local function getIcon(name: string)
	if not Icons then return nil end
	name = string.lower(string.gsub(name, "^%s*(.-)%s*$", "%1"))
	local iconData = Icons['48px'][name]
	if not iconData then return nil end
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
		end
	end
	return "rbxassetid://0"
end

local function ChangeTheme(Theme)
	print("[Тема] Попытка сменить тему.")
	if typeof(Theme) == 'string' and RayfieldLibrary.Theme[Theme] then
		SelectedTheme = RayfieldLibrary.Theme[Theme]
		print("[Тема] Тема изменена на: " .. Theme)
	elseif typeof(Theme) == 'table' then
		SelectedTheme = Theme
		print("[Тема] Применена пользовательская тема.")
	else
		warn("[Тема] Неверный формат темы. Смена отменена.")
		return
	end

	Main.BackgroundColor3 = SelectedTheme.Background
	Topbar.BackgroundColor3 = SelectedTheme.Topbar
	Main.Shadow.Image.ImageColor3 = SelectedTheme.Shadow
	print("[Тема] Элементы UI обновлены в соответствии с новой темой.")
end

local function makeDraggable(object, dragObject)
	print("Создание возможности перетаскивания для: " .. object.Name .. " с помощью " .. dragObject.Name)
	local dragging = false
	local relative

	dragObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			relative = object.AbsolutePosition - UserInputService:GetMouseLocation()
			print("Начало перетаскивания.")
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				print("Окончание перетаскивания.")
			end
		end
	end)

	-- Заменено на Heartbeat для более плавного движения
	RunService.Heartbeat:Connect(function()
		if dragging then
			local position = UserInputService:GetMouseLocation() + relative
			object.Position = UDim2.fromOffset(position.X, position.Y)
		end
	end)
end

local function Hide()
	if Debounce or Hidden then print("Вызов Hide() проигнорирован. Debounce: " .. tostring(Debounce) .. ", Hidden: " .. tostring(Hidden)) return end
	print("Запуск функции Hide().")
	Debounce, Hidden = true, true
	local anim = TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),
		{ Size = UDim2.new(0, 470, 0, 0), BackgroundTransparency = 1 })
	anim:Play()
	print("Анимация скрытия запущена.")
	anim.Completed:Wait()
	print("Анимация скрытия завершена.")
	Main.Visible = false
	Debounce = false
	print("Функция Hide() завершена.")
end

local function Unhide()
	if Debounce or not Hidden then print("Вызов Unhide() проигнорирован. Debounce: " .. tostring(Debounce) .. ", Hidden: " .. tostring(not Hidden)) return end
	print("Запуск функции Unhide().")
	Debounce, Hidden = true, false
	Main.Visible = true
	local targetSize = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)
	local anim = TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),
		{ Size = targetSize, BackgroundTransparency = 0 })
	anim:Play()
	print("Анимация показа запущена.")
	anim.Completed:Wait()
	print("Анимация показа завершена.")
	Debounce = false
	print("Функция Unhide() завершена.")
end

function RayfieldLibrary:Notify(data)
	task.spawn(function()
		local template = Notifications:FindFirstChild("Template")
		if not template then
			warn("Rayfield Notify Error: Не удалось найти 'Template' внутри 'Notifications'. Уведомление не может быть создано.")
			return
		end

		local newNotification = template:Clone()
		newNotification.Name = data.Title or 'Notification'
		newNotification.Parent = Notifications
		newNotification.Visible = true
		newNotification.Title.Text = data.Title or "No Title"
		newNotification.Description.Text = data.Content or "No Content"
		newNotification.Icon.Image = getAssetUri(data.Image or 0)
		newNotification.BackgroundColor3 = SelectedTheme.Background
		newNotification.Position = UDim2.new(0, 0, 0, -80)
		TweenService:Create(newNotification, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, 0, 0, 0) }):Play()
		local duration = data.Duration or math.clamp((#newNotification.Description.Text * 0.1) + 2.5, 3, 10)
		task.wait(duration)
		TweenService:Create(newNotification, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Position = UDim2.new(0, 0, 0, -80) }):Play()
		task.wait(0.5)
		newNotification:Destroy()
	end)
end

function RayfieldLibrary:CreateWindow(Settings)
	print("[CreateWindow] Начало создания окна. Название: " .. (Settings.Name or "Rayfield"))
	Topbar.Title.Text = Settings.Name or "Rayfield"
	LoadingFrame.Title.Text = Settings.LoadingTitle or "Rayfield"
	LoadingFrame.Subtitle.Text = Settings.LoadingSubtitle or "Interface Suite"
	if Settings.Icon then
		print("[CreateWindow] Установка иконки окна.")
		Topbar.Icon.Image = getAssetUri(Settings.Icon)
		Topbar.Icon.Visible = true
		Topbar.Title.Position = UDim2.new(0, 47, 0.5, 0)
	end
	if Settings.Theme then ChangeTheme(Settings.Theme) end

	CEnabled = Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled
	if CEnabled then
		CFileName = Settings.ConfigurationSaving.FileName or tostring(game.PlaceId)
		ConfigurationFolder = Settings.ConfigurationSaving.FolderName or ConfigurationFolder
		print("[CreateWindow] Сохранение конфигурации включено. Имя файла: " .. CFileName .. ", Папка: " .. ConfigurationFolder)
		if not isfolder(ConfigurationFolder) then
			print("[CreateWindow] Папка конфигурации не найдена, создается новая...")
			makefolder(ConfigurationFolder)
		end
	else
		print("[CreateWindow] Сохранение конфигурации отключено.")
	end


	makeDraggable(Main, Topbar)
	if dragBar then makeDraggable(Main, dragInteract) end

	Rayfield.Enabled = true
	LoadingFrame.Visible = true
	print("[CreateWindow] Экран загрузки показан.")
	
	TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0 }):Play()
	task.wait(2)
	LoadingFrame.Visible = false
	Topbar.Visible = true
	print("[CreateWindow] Экран загрузки скрыт, топбар показан.")
	
	local targetSize = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)
	TweenService:Create(Main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential),
		{ Size = targetSize }):Play()
	print("[CreateWindow] Запущена анимация изменения размера главного окна.")
	globalLoaded = true
	print("[CreateWindow] Окно успешно создано и глобальная загрузка завершена.")

	local Window = {}
	function Window:CreateTab(name, image)
		print("[Window] Создание новой вкладки: " .. name)
		local Tab = {}
		function Tab:CreateButton(settings) print("[Tab] Создание кнопки: " .. (settings.Name or 'Без имени')); return settings end
		function Tab:CreateToggle(settings) print("[Tab] Создание переключателя: " .. (settings.Name or 'Без имени')); return settings end
		return Tab
	end
	return Window
end

function RayfieldLibrary:SetVisibility(visibility: boolean)
	print("Вызов SetVisibility с параметром: " .. tostring(visibility))
	if visibility then Unhide() else Hide() end
end

function RayfieldLibrary:IsVisible(): boolean
	print("Проверка видимости. Текущее состояние (скрыто): " .. tostring(Hidden))
	return not Hidden
end

function RayfieldLibrary:Destroy()
	print("!!! Запуск функции Destroy для Rayfield. !!!")
	rayfieldDestroyed = true
	if hideHotkeyConnection then
		print("Отключение обработчика горячей клавиши.")
		hideHotkeyConnection:Disconnect()
	end
	Rayfield:Destroy()
	print("!!! Экземпляр Rayfield уничтожен. !!!")
end

Topbar.Hide.MouseButton1Click:Connect(function()
	print("Нажата кнопка скрытия на топбаре.")
	Hide()
end)

local hideHotkeyConnection = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local keybind = getSetting("General", "rayfieldOpen")
	if input.KeyCode.Name == keybind then
		print("Нажата горячая клавиша: " .. keybind)
		if Hidden then
			print("UI был скрыт, показываем...")
			Unhide()
		else
			print("UI был показан, скрываем...")
			Hide()
		end
	end
end)
print("Обработчик горячей клавиши для скрытия/показа UI подключен.")

if MPrompt then
	MPrompt.Interact.MouseButton1Click:Connect(function()
		print("Нажат prompt для показа UI.")
		Unhide()
	end)
	print("Обработчик нажатия на prompt подключен.")
end


print("Скрипт Rayfield завершил инициализацию. Возврат библиотеки.")
return RayfieldLibrary
