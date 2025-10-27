local HttpService = game:GetService("HttpService")
local plugin_folder = script.Parent

-- Load raw JSON string from child ModuleScript "VFXJSON"
local raw_json = require(plugin_folder:WaitForChild("VFXJSON"))
local success, decoded = pcall(function()
	return HttpService:JSONDecode(raw_json)
end)
if not success then
	warn("Failed to parse VFXJSON:", decoded)
	decoded = {}
end

-- Flatten: subkeys like 'Effect', 'Text', 'Lightning' become categories
local cleaned = decoded
local categories = {}

-- Top-level key is Textures, and inside it are category tabs like Effect, Text, Lightning
local textures_table = cleaned["Textures"]
textures_table["Beams"] = cleaned["Beams"]
for name, artist_table in pairs(cleaned["Artists"]) do
	textures_table[name] = artist_table
end
if typeof(textures_table) == "table" then
	for category_name, entries in pairs(textures_table) do
		if typeof(entries) == "table" then
			categories[category_name] = entries
		end
	end
end

local toolbar = plugin:CreateToolbar("OpenVFX")
local toggle_button = toolbar:CreateButton("Textures", "Show Textures", "rbxassetid://118676849439255")

local plugin_gui = plugin:CreateDockWidgetPluginGui("OpenVFX", DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	300, 400, 150, 200
	))
plugin_gui.Title = "OpenVFX"
plugin_gui.Enabled = false

toggle_button.Click:Connect(function()
	plugin_gui.Enabled = not plugin_gui.Enabled
end)

local frame = plugin_folder.ui_template:WaitForChild("frame"):Clone()
local content_frame = frame:WaitForChild("content_frame")
content_frame.Parent = plugin_gui

local tabs = content_frame:WaitForChild("category_scrollingframe")
local scroll = content_frame:WaitForChild("texture_scrollingframe")

-- Resize helper
local function auto_resize_canvas(scrolling_frame)
	local layout = scrolling_frame:FindFirstChildWhichIsA("UIGridLayout")
	if layout then
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scrolling_frame.CanvasSize = UDim2.new(0, 0, 1, layout.AbsoluteContentSize.Y + 10)
		end)
		task.defer(function()
			scrolling_frame.CanvasSize = UDim2.new(0, 0, 1, layout.AbsoluteContentSize.Y + 10)
		end)
	end
end

-- Prevent deleting layout
local function clear_content()
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

local function render_category()
	clear_content()

	local category_name = plugin_folder.current_category.Value
	local category_data = categories[category_name]
	if not category_data then return end

	local is_flat = false
	for _, value in pairs(category_data) do
		if typeof(value) == "table" and value.Texture then
			is_flat = true
			break
		end
	end
	if is_flat then
		category_data = { category_data }
	end

	for _, subcategory in pairs(category_data) do
		for _, entry in pairs(subcategory) do
			local id = entry.Texture and entry.Texture:match("%d+")
			local pass
			if plugin_folder.current_type.Value == "static" then
				if entry.Type == "Static" then
					pass = true
				else
					pass = false
				end
			else
				if entry.Type ~= "Static" then
					pass = true
				else
					pass = false
				end
			end

			if pass and id then
				local image_button = Instance.new("ImageButton")
				image_button.Size = UDim2.new(0, 100, 0, 100)
				image_button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				image_button.Image = "rbxassetid://" .. id
				image_button.ScaleType = Enum.ScaleType.Fit
				image_button.Parent = scroll

				image_button.MouseButton1Click:Connect(function()
					local emitter = Instance.new("ParticleEmitter")
					emitter.Texture = "rbxassetid://" .. id
					
					if entry.Type == "2x2" then
						emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
					end
					if entry.Type == "4x4" then
						emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
					end
					if entry.Type == "8x8" then
						emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
					end
					
					emitter.Lifetime = NumberRange.new(1)
					emitter.Rate = 0.5
					emitter.FlipbookFramerate = NumberRange.new(24)
					emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
					emitter.Speed = NumberRange.new(0)
					
					
					local part = Instance.new("Part")
					part.Transparency = 0.4
					part.Color = Color3.new(1, 0, 0)
					part.Size = Vector3.new(0.5,0.5,0.5)
					part.Anchored = true
					part.Position = workspace.Camera.CFrame.Position + workspace.Camera.CFrame.LookVector*5
					part.Parent = workspace
					
					local attachment = Instance.new("Attachment")
					attachment.Parent = part
					attachment.CFrame = CFrame.new(0,1,0)
					emitter.Parent = attachment
				end)
			end
		end
	end
end


plugin_folder.current_type.Changed:Connect(render_category)
plugin_folder.current_category.Changed:Connect(render_category)


for i ,v in pairs(content_frame.type_frame:GetChildren()) do
	if v:IsA("TextButton") then
		v.Activated:Connect(function()
			plugin_folder.current_type.Value = v.Name:gsub("_button$", "")
		end)
	end
end

for category_name, category_data in pairs(categories) do
	local tab = Instance.new("TextButton")
	tab.Size = UDim2.new(0, 100, 0, 30)
	tab.Text = category_name
	tab.Name = category_name
	tab.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	tab.TextColor3 = Color3.new(1, 1, 1)
	tab.Parent = tabs

	tab.MouseButton1Click:Connect(function()
		--render_category(category_data)
		plugin_folder.current_category.Value = category_name
	end)
end

-- Init auto resizing once
auto_resize_canvas(tabs)
auto_resize_canvas(scroll)
render_category()
