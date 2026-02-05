--//==============================================================
--//  SignatureUI — Lunar Noir AAA (Framework Library)
--//  Built from "Signature UI — Lunar Noir AAA (Design Overhaul)"
--//  Version: v2.0.0 (library)
--//
--//  Goal: mega-simple, mega-convenient API.
--//
--//  Usage (minimal):
--//      local SignatureUI = require(path.To.SignatureUI)
--//      local ui = SignatureUI.new({ Name="signature", Version="v1.0" })
--//      local home = ui:Tab("Home","☾")
--//      home:Button("Self-check", function() ui:Toast("OK","Everything fine") end)
--//      ui:Open()
--//
--//  Public API:
--//      SignatureUI.new(opts) -> ui
--//      ui:Tab(name, icon?) -> tab
--//      ui:Open() / ui:Close() / ui:Toggle()
--//      ui:Toast(title, desc, color?, duration?)
--//      ui:Confirm(title, desc, onYes, onNo?)    -- modal
--//      ui:SetDragLocked(bool)
--//      ui:SetReduceFX(bool)
--//      ui:Center()
--//      ui:Destroy()
--//
--//      tab:Label(text)
--//      tab:Paragraph(text)
--//      tab:Divider()
--//      tab:Section(title)
--//      tab:Button(text, callback, hint?)
--//      tab:Toggle(text, default, callback)
--//      tab:Slider(text, opts, callback)         -- opts: Min, Max, Step, Default, Suffix
--//      tab:Dropdown(text, items, opts, callback)-- opts: Multi, Default
--//      tab:ColorPicker(text, defaultColor, callback) -- callback(col, alpha01)
--//
--//  Notes:
--//  - This module does NOT fetch remote assets.
--//  - Works as a LocalScript requiring the module OR can be used from an executor
--//    if you can require it (or copy/paste this file as a script).
--//==============================================================

--==============================================================
-- Services
--==============================================================
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

--==============================================================
-- Small utilities
--==============================================================
local function clamp01(x) return math.clamp(x, 0, 1) end
local function trim(s)
	s = tostring(s or "")
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function toLower(s) return string.lower(tostring(s or "")) end

local function parseNumeric(text)
	if type(text) ~= "string" then return nil end
	local s = text:gsub(",", ".")
	local m = s:match("[-+]?%d+%.?%d*") or s:match("[-+]?%d*%.%d+")
	if not m then return nil end
	return tonumber(m)
end

local function roundStep(v, step)
	step = math.max(step or 1, 1e-6)
	return math.floor((v / step) + 0.5) * step
end

local function lerpColor(a, b, t)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function toHex(c)
	local r = math.clamp(math.floor(c.R * 255 + 0.5), 0, 255)
	local g = math.clamp(math.floor(c.G * 255 + 0.5), 0, 255)
	local b = math.clamp(math.floor(c.B * 255 + 0.5), 0, 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

local function fromHex(hex)
	if type(hex) ~= "string" then return nil end
	local s = hex:gsub("%s+", "")
	if s:sub(1,1) == "#" then s = s:sub(2) end
	if #s ~= 6 then return nil end
	if not s:match("^[0-9a-fA-F]+$") then return nil end
	local r = tonumber(s:sub(1,2), 16)
	local g = tonumber(s:sub(3,4), 16)
	local b = tonumber(s:sub(5,6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

local function smoothStep(current, target, dt, speed)
	return current + (target - current) * (1 - math.exp(-(speed or 12) * dt))
end

local function tween(obj, info, goals)
	local t = TweenService:Create(obj, info, goals)
	t:Play()
	return t
end

local function mk(className, props, children)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	return inst
end

local function addCornerPx(parent, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
	return c
end

local function addCornerRound(parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = parent
	return c
end

local function addStroke(parent, thickness, transparency, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.6
	s.Color = color or Color3.fromRGB(255,255,255)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addGradient(parent, rot, colors, trans)
	local g = Instance.new("UIGradient")
	g.Rotation = rot or 0
	g.Color = colors
	if trans then g.Transparency = trans end
	g.Parent = parent
	return g
end

local function addPadding(parent, l, r, t, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingRight = UDim.new(0, r or 0)
	p.PaddingTop = UDim.new(0, t or 0)
	p.PaddingBottom = UDim.new(0, b or 0)
	p.Parent = parent
	return p
end

local function addList(parent, padding)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, padding or 0)
	l.Parent = parent
	return l
end

local function getMousePos()
	local pos = UserInputService:GetMouseLocation()
	local tl = Vector2.new(0, 0)
	pcall(function() tl = GuiService:GetGuiInset() end)
	if typeof(tl) == "Vector2" then
		pos -= tl
	end
	return pos
end

--==============================================================
-- Maid (cleanup)
--==============================================================
local Maid = {}
Maid.__index = Maid
function Maid.new()
	return setmetatable({ tasks = {} }, Maid)
end
function Maid:Give(t)
	table.insert(self.tasks, t)
	return t
end
function Maid:Cleanup()
	for _, t in ipairs(self.tasks) do
		if typeof(t) == "RBXScriptConnection" then
			pcall(function() t:Disconnect() end)
		elseif typeof(t) == "Instance" then
			pcall(function() t:Destroy() end)
		elseif typeof(t) == "function" then
			pcall(t)
		end
	end
	self.tasks = {}
end

--==============================================================
-- Defaults (config + theme)
--==============================================================
local DEFAULTS = {
	Name = "signature",
	Version = "v2.0.0",
	Parent = CoreGui, -- auto PlayerGui or Custom
	KeybindPrimary = Enum.KeyCode.RightShift,
	KeybindSecondary = Enum.KeyCode.LeftShift,

	WindowSize = Vector2.new(1020, 610),
	SidebarWidth = 260,
	SidebarCollapsedWidth = 86,

	DimAlpha = 0.20,
	BlurSize = 14,

	MoonSize = 430,
	MoonTransparency = 0.58,

	StarCount = 150,
	MaxLines = 3000,
	ConnectDistance = 175,
	LinesUpdateRate = 0.10,
	StarSpeed = Vector2.new(10, 16),

	-- Animations
	OpenTween = TweenInfo.new(0.58, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	CloseTween = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
	SoftTween  = TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	FastTween  = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	SnapTween  = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

	-- Drag spring
	DragFrequency = 9.0,
	DragDamping = 0.92,

	-- Sounds
	ToastSoundId = 117409737658405,
	ModalSoundId = 124951621656853,

	-- Design
	SheenSpeed = 0.10,
	AccentSheenSpeed = 0.13,

	-- Search
	SearchDebounce = 0.14,
	SearchMaxResults = 40,

    -- Misc
    DefaultTabs = nil,
    AutoOpen = true,
    AutoHelloToast = false,

}

local DEFAULT_THEME = {
	BG      = Color3.fromRGB(66, 69, 77),
	PANEL   = Color3.fromRGB(82, 85, 97),
	PANEL_2 = Color3.fromRGB(14, 16, 24),
	PANEL_3 = Color3.fromRGB(88, 89, 97),

	STROKE  = Color3.fromRGB(92, 105, 140),
	SOFT    = Color3.fromRGB(140, 150, 190),

	TEXT    = Color3.fromRGB(255, 255, 255),
	MUTED   = Color3.fromRGB(255, 255, 255),

	ACCENT   = Color3.fromRGB(175, 195, 255),
	ACCENT_2 = Color3.fromRGB(120, 155, 255),
	ACCENT_3 = Color3.fromRGB(255, 220, 220),

	DANGER  = Color3.fromRGB(255, 110, 120),
	SUCCESS = Color3.fromRGB(140, 255, 200),
}

local DEFAULT_GREETINGS = {
	"Have a great session, %s",
	"Good to see you, %s",
	"Stars online for %s",
	"Ready when you are, %s",
	"Welcome back, %s",
	"Enjoy your run, %s",
	"Tonight looks bright, %s",
	"Have fun, %s",
	"Let the run begin, %s",
	"Play smart, %s",
	"Stay focused, %s",
	"Make it look easy, %s",
}

--==============================================================
-- Checkerboard (real grid, no stripes)
--==============================================================
local CHECKER_LIGHT = Color3.fromRGB(34, 36, 46)
local CHECKER_DARK  = Color3.fromRGB(22, 24, 32)

local function stripePenalty(rem)
	if rem == 0 then return 0 end
	if rem == 1 then return 1000 end
	if rem == 2 then return 250 end
	if rem == 3 then return 80 end
	return 10
end

local function pickCheckerTile(w, h, baseTile)
	baseTile = math.max(2, math.floor((baseTile or 8) + 0.5))
	local maxT = math.max(2, math.min(baseTile, math.min(w, h)))

	local bestT = math.max(2, math.floor(maxT))
	local bestScore = math.huge

	for t = maxT, 2, -1 do
		local cols = math.floor(w / t)
		local rows = math.floor(h / t)
		if cols >= 2 and rows >= 2 then
			local rw = w % t
			local rh = h % t
			local score = stripePenalty(rw) + stripePenalty(rh)
			if rows < 3 then score += 60 end
			if cols < 3 then score += 20 end
			score += (baseTile - t) * 2
			if score < bestScore then
				bestScore = score
				bestT = t
			end
		end
	end
	return math.max(2, bestT)
end

local function buildChecker(parent, tile, maid)
	if not parent or not parent:IsA("Frame") then return end
	local old = parent:FindFirstChild("CheckerGrid")
	if old then old:Destroy() end

	local grid = mk("Frame", {
		Name = "CheckerGrid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 0),
		ZIndex = parent.ZIndex,
		ClipsDescendants = true,
	})
	grid.Parent = parent

	local base = mk("Frame", {
		Name = "Base",
		BackgroundColor3 = CHECKER_LIGHT,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = grid.ZIndex,
	})
	base.Parent = grid

	local darkLayer = mk("Frame", {
		Name = "Dark",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = grid.ZIndex + 1,
	})
	darkLayer.Parent = grid

	local baseTile = math.max(2, math.floor((tile or 8) + 0.5))

	local function clearDark()
		for _, ch in ipairs(darkLayer:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
	end

	local function rebuild()
		if not parent.Parent then return end
		if not grid.Parent then return end
		local w = math.floor(parent.AbsoluteSize.X + 0.5)
		local h = math.floor(parent.AbsoluteSize.Y + 0.5)
		if w < 2 or h < 2 then return end

		local t = pickCheckerTile(w, h, baseTile)
		clearDark()

		for y = 0, h - 1, t do
			local yi = math.floor(y / t)
			for x = 0, w - 1, t do
				local xi = math.floor(x / t)
				if ((xi + yi) % 2) == 1 then
					local sqW = math.min(t, w - x)
					local sqH = math.min(t, h - y)
					local sq = mk("Frame", {
						BackgroundColor3 = CHECKER_DARK,
						BackgroundTransparency = 0,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(x, y),
						Size = UDim2.fromOffset(sqW, sqH),
						ZIndex = darkLayer.ZIndex,
					})
					sq.Parent = darkLayer
				end
			end
		end
	end

	local conn = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
	if maid then maid:Give(conn) end
	task.defer(function()
		rebuild()
		task.defer(rebuild)
	end)
end

--==============================================================
-- Design primitives (lunar glass)
--==============================================================
local function derivePalette(THEME)
	local moonBase = lerpColor(THEME.PANEL_2, THEME.PANEL, 0.22)
	local moonHi   = lerpColor(moonBase, THEME.ACCENT, 0.10)
	local moonLo   = lerpColor(moonBase, Color3.new(0,0,0), 0.40)

	return {
		Deep = lerpColor(THEME.PANEL_2, Color3.fromRGB(119, 126, 155), 0.25),

		Ink = lerpColor(THEME.PANEL_2, THEME.BG, 0.18),
		Glass = lerpColor(THEME.PANEL, THEME.PANEL_2, 0.35),
		Glass2 = lerpColor(THEME.PANEL, THEME.BG, 0.20),
		EdgeDark = lerpColor(THEME.STROKE, Color3.new(0,0,0), 0.55),
		EdgeLite = lerpColor(THEME.STROKE, THEME.ACCENT_3, 0.22),
		Highlight = lerpColor(THEME.ACCENT_3, Color3.new(1,1,1), 0.30),

		MoonBase = moonBase,
		MoonHi = moonHi,
		MoonLo = moonLo,

		MoonDark = moonBase,
	}
end

local function makeSoftShadow(parent, z, radius)
	local function layer(sizeAdd, tr, off, rAdd)
		local f = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, off.X, 0.5, off.Y),
			Size = UDim2.new(1, sizeAdd, 1, sizeAdd),
			BackgroundColor3 = Color3.new(0,0,0),
			BackgroundTransparency = tr,
			BorderSizePixel = 0,
			ZIndex = z,
		})
		f.Parent = parent
		addCornerPx(f, radius + rAdd)
		addGradient(f, 90,
			ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0)),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.20),
				NumberSequenceKeypoint.new(1, 0.55),
			})
		)
		return f
	end
	layer(92, 0.92, Vector2.new(10, 12), 34)
	local l2 = layer(58, 0.86, Vector2.new(8, 10), 28); l2.ZIndex = z + 1
	local l3 = layer(34, 0.80, Vector2.new(6, 8), 22);  l3.ZIndex = z + 2
	local l4 = layer(18, 0.74, Vector2.new(4, 6), 18);  l4.ZIndex = z + 3
end

local function attachAccentStrokeGradient(stroke, THEME, accentShimmers)
	local g = stroke:FindFirstChildOfClass("UIGradient")
	if g then return g end
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.ACCENT),
		ColorSequenceKeypoint.new(1, THEME.ACCENT_2),
	})
	grad.Offset = Vector2.new(0, 0)
	grad.Parent = stroke
	table.insert(accentShimmers, grad)
	return grad
end

local function makeLunarPanel(parent, props, THEME, PALETTE, shimmerGradients)
	local frame = mk("Frame", {
		Name = props.Name or "Panel",
		Position = props.Position or UDim2.fromOffset(0,0),
		Size = props.Size,
		BackgroundColor3 = props.BaseColor,
		BackgroundTransparency = props.BaseTransparency,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		ClipsDescendants = (props.Clips == nil) and true or props.Clips,
	})
	frame.Parent = parent
	addCornerPx(frame, props.Corner)

	addGradient(frame, -25,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, lerpColor(props.BaseColor, THEME.ACCENT_3, 0.12)),
			ColorSequenceKeypoint.new(0.55, props.BaseColor),
			ColorSequenceKeypoint.new(1, lerpColor(props.BaseColor, PALETTE.Deep, 0.28)),
		}),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(1, 0.18),
		})
	)

	local stroke = addStroke(frame, 1, props.StrokeTransparency or 0.55, props.StrokeColor or PALETTE.EdgeDark)

	local innerBorder = mk("Frame", {
		Name = "InnerBorder",
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex + 1,
	})
	innerBorder.Parent = frame
	addCornerPx(innerBorder, math.max(2, props.Corner - 1))
	addStroke(innerBorder, 1, props.InnerStrokeTransparency or 0.72, PALETTE.EdgeLite)

	local sheen = mk("Frame", {
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex + 2,
	})
	sheen.Parent = frame

	local sheenGrad = addGradient(sheen, 18,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
			ColorSequenceKeypoint.new(0.25, Color3.new(1,1,1)),
			ColorSequenceKeypoint.new(0.55, Color3.new(1,1,1)),
			ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
		}),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.00),
			NumberSequenceKeypoint.new(0.18, 0.92),
			NumberSequenceKeypoint.new(0.45, 0.98),
			NumberSequenceKeypoint.new(0.62, 0.90),
			NumberSequenceKeypoint.new(1, 1.00),
		})
	)
	sheenGrad.Offset = Vector2.new(-0.35, 0)
	table.insert(shimmerGradients, sheenGrad)

	local topLite = mk("Frame", {
		Name = "TopLite",
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex + 3,
	})
	topLite.Parent = frame
	addCornerPx(topLite, props.Corner)
	addGradient(topLite, 90,
		ColorSequence.new(PALETTE.Highlight, PALETTE.Highlight),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.80),
			NumberSequenceKeypoint.new(0.35, 0.95),
			NumberSequenceKeypoint.new(1, 1.00),
		})
	)

	if props.Glow then
		local glowFrame = mk("Frame", {
			Name = "GlowRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 18, 1, 18),
			BackgroundColor3 = THEME.ACCENT,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			ZIndex = props.ZIndex - 1,
		})
		glowFrame.Parent = frame
		addCornerPx(glowFrame, props.Corner + 10)
		addGradient(glowFrame, 45,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, THEME.ACCENT),
				ColorSequenceKeypoint.new(1, THEME.ACCENT_2),
			}),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.86),
				NumberSequenceKeypoint.new(1, 0.96),
			})
		)
	end

	local pad = props.SafePadding or 10
	local safe = mk("Frame", {
		Name = "Safe",
		Position = UDim2.new(0, pad, 0, pad),
		Size = UDim2.new(1, -(pad*2), 1, -(pad*2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex + 10,
		ClipsDescendants = false,
	})
	safe.Parent = frame

	return frame, stroke, sheenGrad, safe
end

--==============================================================
-- SignatureUI class
--==============================================================
local SignatureUI = {}
SignatureUI.__index = SignatureUI

-- Tab class
local Tab = {}
Tab.__index = Tab

--==============================================================
-- Constructor
--==============================================================
function SignatureUI.new(opts)
	opts = opts or {}
	local self = setmetatable({}, SignatureUI)
	self._maid = Maid.new()

	-- merge defaults
	self.Config = table.clone(DEFAULTS)
	for k, v in pairs(opts) do
		self.Config[k] = v
	end

	self.Config.Parent = CoreGui

	self.Theme = table.clone(DEFAULT_THEME)
	if type(opts.Theme) == "table" then
		for k, v in pairs(opts.Theme) do
			self.Theme[k] = v
		end
	end
	self.Greetings = (type(opts.Greetings) == "table") and opts.Greetings or DEFAULT_GREETINGS
	self.Palette = derivePalette(self.Theme)

	self.State = {
		dragLocked = false,
		reduceFX = false,
	}

	self._rng = Random.new()
	self._searchIndex = {} -- { {tab=string, key=string, node=Instance} }
	self._buildTabName = ""

	-- create UI now
	self:_build()

	return self
end

--==============================================================
-- Public: Tab
--==============================================================
function SignatureUI:Tab(name, icon)
    assert(type(name) == "string" and name ~= "", "Tab name must be a string")
    if self._tabs[name] then
        return self._tabs[name].api
    end

    local f = self._factory
    return self:_createTab(
        name,
        icon or "•",
        nil,
        f and f.TabsStack,
        f and f.makePage,
        f and f.makeButton,
        f and f.makeToggle,
        f and f.makeSlider,
        f and f.makeDropdown,
        f and f.makeColorPicker
    )
end

--==============================================================
-- Public: Open/Close/Toggle/Destroy
--==============================================================
function SignatureUI:Open() self:_openUI() end
function SignatureUI:Close() self:_closeUI() end
function SignatureUI:Toggle() if self._isOpen then self:_closeUI() else self:_openUI() end end
function SignatureUI:Center() self:_centerWindow() end
function SignatureUI:SetDragLocked(v) self.State.dragLocked = (v == true) end
function SignatureUI:SetReduceFX(v) self.State.reduceFX = (v == true) end

function SignatureUI:Destroy()
	self:_unload()
end

--==============================================================
-- Public: Toast + Confirm
--==============================================================
function SignatureUI:Toast(title, desc, color, duration)
	if self._toast then
		self._toast(title, desc, color, duration)
	end
end

function SignatureUI:Confirm(title, desc, onYes, onNo)
	title = tostring(title or "Confirm")
	desc = tostring(desc or "")
	self._modalTitle.Text = title
	self._modalDesc.Text = desc
	self._modalYes = onYes
	self._modalNo = onNo
	self:_showModal(true)
end

--==============================================================
-- Internal: Search
--==============================================================
function SignatureUI:_registerSearch(node, key)
	if not node then return end
	if self._buildTabName == "" then return end
	key = trim(key or "")
	if key == "" then return end
	table.insert(self._searchIndex, { tab = self._buildTabName, key = key, node = node })
	pcall(function()
		node:SetAttribute("SearchKey", key)
		node:SetAttribute("SearchTab", self._buildTabName)
	end)
end

--==============================================================
-- Internal: build UI
--==============================================================
function SignatureUI:_build()
	local C = self.Config
	local THEME = self.Theme
	local PALETTE = self.Palette

	local player = Players.LocalPlayer
	local parent = CoreGui -- FORCE CoreGui
	self.Parent = parent

	-- cleanup previous (by name) to avoid stacking when re-running
	pcall(function()
		local old = parent:FindFirstChild("SignatureUI")
		if old then old:Destroy() end
	end)
	pcall(function()
		local oldT = parent:FindFirstChild("SignatureToasts")
		if oldT then oldT:Destroy() end
	end)

	-- toast gui (always enabled)
	local ToastGui = mk("ScreenGui", {
		Name = "SignatureToasts",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 99999,
		Enabled = true,
	})
	ToastGui.Parent = parent
	self._maid:Give(ToastGui)
	self.ToastGui = ToastGui

	-- main gui (toggle)
	local ScreenGui = mk("ScreenGui", {
		Name = "SignatureUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	ScreenGui.Parent = parent
	self._maid:Give(ScreenGui)
	self.ScreenGui = ScreenGui

	-- blur
	local BLUR_NAME = "Signature_BlurEffect"
	local createdBlur = false
	local blur = Lighting:FindFirstChild(BLUR_NAME)
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = BLUR_NAME
		blur.Size = 0
		blur.Parent = Lighting
		createdBlur = true
	end
	self._blur = blur
	self._createdBlur = createdBlur
	self._blurName = BLUR_NAME

	-- sounds host
	local SoundHost = mk("Folder", { Name = "Signature_Sounds" })
	SoundHost.Parent = SoundService
	self._maid:Give(SoundHost)
	self._soundHost = SoundHost

	local function playSound(assetId, volume)
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. tostring(assetId)
		s.Volume = volume or 0.55
		s.Parent = SoundHost
		s:Play()
		task.delay(3, function() if s then s:Destroy() end end)
	end
	self._playSound = playSound

	-- Shimmers
	local ShimmerGradients = {}
	local AccentShimmers = {}
	self._shimmer = ShimmerGradients
	self._accentShimmer = AccentShimmers

	-- Backdrop
	local BackdropGroup = mk("CanvasGroup", {
		Name = "BackdropGroup",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 1,
	})
	BackdropGroup.Parent = ScreenGui
	self.BackdropGroup = BackdropGroup

	local Dim = mk("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	})
	Dim.Parent = BackdropGroup
	self.Dim = Dim

	-- Nebula shards
	local Nebula = mk("Frame", {
		Name = "Nebula",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	Nebula.Parent = BackdropGroup

	local function nebulaBlob(pos, size, rot, z)
		local f = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = size,
			BackgroundColor3 = lerpColor(THEME.PANEL_2, THEME.ACCENT_2, 0.08),
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
			ZIndex = z,
		})
		f.Parent = Nebula
		addCornerRound(f)
		addGradient(f, rot,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, lerpColor(THEME.PANEL_2, THEME.ACCENT_2, 0.12)),
				ColorSequenceKeypoint.new(1, THEME.PANEL_2),
			}),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.90),
				NumberSequenceKeypoint.new(1, 0.98),
			})
		)
	end
	nebulaBlob(UDim2.fromScale(0.22, 0.26), UDim2.fromOffset(720, 520), 25, 2)
	nebulaBlob(UDim2.fromScale(0.74, 0.18), UDim2.fromOffset(640, 420), -30, 3)
	nebulaBlob(UDim2.fromScale(0.62, 0.78), UDim2.fromOffset(820, 640), 18, 2)
	nebulaBlob(UDim2.fromScale(0.18, 0.78), UDim2.fromOffset(560, 420), -20, 3)

	local Vignette = mk("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	Vignette.Parent = BackdropGroup
	addGradient(Vignette, 0,
		ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0)),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.5, 1.00),
			NumberSequenceKeypoint.new(1, 0.45),
		})
	)

	-- Moon
	local Moon = mk("Frame", {
		Name = "Moon",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 70),
		Size = UDim2.new(0, C.MoonSize, 0, C.MoonSize),
		BackgroundColor3 = PALETTE.MoonBase,
		BackgroundTransparency = C.MoonTransparency,
		BorderSizePixel = 0,
		ZIndex = 4,
	})
	Moon.Parent = BackdropGroup
	addCornerRound(Moon)
	addGradient(Moon, -35,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, PALETTE.MoonHi),
			ColorSequenceKeypoint.new(0.55, PALETTE.MoonBase),
			ColorSequenceKeypoint.new(1, PALETTE.MoonLo),
		}),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.10),
			NumberSequenceKeypoint.new(1, 0.38),
		})
	)
	self.Moon = Moon

	local function ring(sizeAdd, tr, thick, col, z)
		local r = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, sizeAdd, 1, sizeAdd),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = z,
		})
		r.Parent = Moon
		addCornerRound(r)
		local s = addStroke(r, thick, tr, col)
		attachAccentStrokeGradient(s, THEME, AccentShimmers)
	end
	ring(74, 0.82, 1, lerpColor(THEME.ACCENT, THEME.PANEL_2, 0.55), 2)
	ring(48, 0.86, 1, lerpColor(THEME.ACCENT_2, THEME.PANEL_2, 0.60), 2)

	local function crater(sizePx, x, y, tr)
		local c = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.new(0, sizePx, 0, sizePx),
			BackgroundColor3 = lerpColor(PALETTE.MoonLo, THEME.PANEL_2, 0.20),
			BackgroundTransparency = tr,
			BorderSizePixel = 0,
			ZIndex = 6,
		})
		addCornerRound(c)
		addGradient(c, -25,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, lerpColor(PALETTE.MoonHi, Color3.new(1,1,1), 0.08)),
				ColorSequenceKeypoint.new(1, lerpColor(PALETTE.MoonLo, Color3.new(0,0,0), 0.10)),
			}),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.85),
				NumberSequenceKeypoint.new(1, 0.95),
			})
		)

		local inner = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.50, 0.50),
			Size = UDim2.new(0, math.max(10, sizePx - 14), 0, math.max(10, sizePx - 14)),
			BackgroundColor3 = Color3.fromRGB(18, 20, 26),
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = 7,
		})
		addCornerRound(inner)
		inner.Parent = c

		local rim = addStroke(c, 1, 0.85, Color3.fromRGB(140, 150, 190))
		rim.Color = lerpColor(rim.Color, THEME.PANEL_2, 0.55)

		return c
	end
	for _, c2 in ipairs({
		crater(78, 0.30, 0.34, 0.55),
		crater(52, 0.62, 0.26, 0.62),
		crater(40, 0.74, 0.56, 0.68),
		crater(64, 0.48, 0.72, 0.58),
		crater(30, 0.26, 0.63, 0.70),
		crater(24, 0.60, 0.48, 0.72),
		crater(44, 0.84, 0.38, 0.66),
	}) do
		c2.Parent = Moon
	end

	-- Constellation
	local Constellation = mk("Frame", {
		Name = "Constellation",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	})
	Constellation.Parent = BackdropGroup
	self.Constellation = Constellation

	local stars = {}
	local lines = {}
	self._stars = stars
	self._lines = lines

	local STAR_DOT_COLOR  = lerpColor(THEME.SOFT, THEME.ACCENT, 0.20)
	local STAR_CORE_COLOR = lerpColor(THEME.ACCENT_3, THEME.SOFT, 0.25)
	local STAR_GLOW_COLOR = lerpColor(THEME.ACCENT, PALETTE.Glass2, 0.25)
	local LINE_COLOR      = lerpColor(THEME.STROKE, THEME.ACCENT, 0.32)

	local function makeStar(i)
		local size = self._rng:NextInteger(3, 6)
		local x = self._rng:NextNumber(0.08, 0.92)
		local y = self._rng:NextNumber(0.10, 0.92)

		local glow = mk("Frame", {
			Name = "StarGlow_" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.new(0, size * 1, 0, size * 1),
			BackgroundColor3 = STAR_GLOW_COLOR,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
		addCornerRound(glow)
		glow.Parent = Constellation

		local dot = mk("Frame", {
			Name = "StarDot_" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.new(0, size, 0, size),
			BackgroundColor3 = STAR_DOT_COLOR,
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			ZIndex = 4,
		})
		addCornerRound(dot)
		dot.Parent = Constellation

		local core = mk("Frame", {
			Name = "StarCore_" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, math.max(1, math.floor(size * 0.42)), 0, math.max(1, math.floor(size * 0.42))),
			BackgroundColor3 = STAR_CORE_COLOR,
			BackgroundTransparency = 0.22,
			BorderSizePixel = 0,
			ZIndex = 5,
		})
		addCornerRound(core)
		core.Parent = dot

		local spx = self._rng:NextNumber(-C.StarSpeed.X, C.StarSpeed.X)
		local spy = self._rng:NextNumber(-C.StarSpeed.Y, C.StarSpeed.Y)
		if math.abs(spx) < 4 then spx = 6 * (spx >= 0 and 1 or -1) end
		if math.abs(spy) < 4 then spy = 6 * (spy >= 0 and 1 or -1) end

		return {
			dot = dot,
			glow = glow,
			pos = Vector2.new(x, y),
			vel = Vector2.new(spx, spy),
		}
	end

	local function makeLine(i)
		local ln = mk("Frame", {
			Name = "Line_" .. i,
			BackgroundColor3 = LINE_COLOR,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 2,
		})
		addCornerRound(ln)
		ln.Parent = Constellation
		return { line = ln, alpha = 0, target = 0 }
	end

	for i = 1, C.StarCount do stars[i] = makeStar(i) end
	for i = 1, C.MaxLines do lines[i] = makeLine(i) end

	-- Root
	local Root = mk("CanvasGroup", {
		Name = "Root",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		GroupTransparency = 1,
		Size = UDim2.fromOffset(C.WindowSize.X, C.WindowSize.Y),
	})
	Root.Parent = ScreenGui
	self._maid:Give(Root)
	self.Root = Root

	makeSoftShadow(Root, 40, 14)

	local WindowGroup = mk("CanvasGroup", {
		Name = "WindowGroup",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		ZIndex = 80,
	})
	WindowGroup.Parent = Root

	local WindowBase, _, _, WindowSafe = makeLunarPanel(WindowGroup, {
		Name = "WindowBase",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 85,
		Corner = 14,
		BaseColor = PALETTE.Glass,
		BaseTransparency = 0.08,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.40,
		InnerStrokeTransparency = 0.70,
		Glow = true,
		SafePadding = 10,
	}, THEME, PALETTE, ShimmerGradients)

	local WindowSurface, _, _, SurfaceSafe = makeLunarPanel(WindowBase, {
		Name = "WindowSurface",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		ZIndex = 90,
		Corner = 12,
		BaseColor = lerpColor(PALETTE.Glass2, THEME.PANEL_2, 0.15),
		BaseTransparency = 0.10,
		StrokeColor = PALETTE.EdgeLite,
		StrokeTransparency = 0.72,
		InnerStrokeTransparency = 0.82,
		Glow = false,
		SafePadding = 12,
	}, THEME, PALETTE, ShimmerGradients)

	-- TopBar
	local TopBar = mk("Frame", {
		Name = "TopBar",
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 140,
	})
	TopBar.Parent = SurfaceSafe

	local TopBarCard, _, _, TopBarSafe = makeLunarPanel(TopBar, {
		Name = "TopBarCard",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 140,
		Corner = 12,
		BaseColor = lerpColor(THEME.PANEL_2, THEME.PANEL, 0.10),
		BaseTransparency = 0.10,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.52,
		InnerStrokeTransparency = 0.78,
		Glow = false,
		SafePadding = 12,
	}, THEME, PALETTE, ShimmerGradients)

	local Brand = mk("TextLabel", {
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(0, 260, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = THEME.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(C.Name),
		ZIndex = 160,
	})
	Brand.Parent = TopBarSafe

	local BrandSub = mk("TextLabel", {
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(0, 340, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(C.Version) .. "  • coder & owner: @luaudocumentation discord",
		ZIndex = 160,
	})
	BrandSub.Parent = TopBarSafe

	local playerName = (player and player.Name) or "Player"
	local greeting = self.Greetings[self._rng:NextInteger(1, #self.Greetings)]:format(playerName)
	self._greeting = greeting

	local GreetingLabel = mk("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.56, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = THEME.TEXT,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = greeting,
		ZIndex = 160,
	})
	GreetingLabel.Parent = TopBarCard

	-- Controls (top-right)
	local Controls = mk("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.new(0, 154, 0, 28),
		BackgroundTransparency = 1,
		ZIndex = 170,
	})
	Controls.Parent = TopBarCard
	local controlsList = addList(Controls, 8)
	controlsList.FillDirection = Enum.FillDirection.Horizontal
	controlsList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	controlsList.VerticalAlignment = Enum.VerticalAlignment.Center

	local function iconButton(symbol, color)
		local holder = mk("Frame", {
			Size = UDim2.new(0, 46, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 170,
		})
		holder.Parent = Controls

		local panel, stroke = makeLunarPanel(holder, {
			Name = "BtnPanel",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 171,
			Corner = 10,
			BaseColor = PALETTE.Glass2,
			BaseTransparency = 0.10,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.62,
			InnerStrokeTransparency = 0.82,
			Glow = false,
			SafePadding = 0,
		}, THEME, PALETTE, ShimmerGradients)

		local b = mk("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = color or THEME.TEXT,
			Text = symbol,
			AutoButtonColor = false,
			ZIndex = 180,
		})
		b.Parent = panel

		b.MouseEnter:Connect(function()
			tween(panel, C.FastTween, { BackgroundTransparency = 0.05 })
			if stroke then
				tween(stroke, C.FastTween, { Transparency = 0.35 })
				attachAccentStrokeGradient(stroke, THEME, AccentShimmers)
			end
		end)

		b.MouseLeave:Connect(function()
			tween(panel, C.FastTween, { BackgroundTransparency = 0.10 })
			if stroke then
				tween(stroke, C.FastTween, { Transparency = 0.62, Color = PALETTE.EdgeDark })
			end
		end)

		b.Activated:Connect(function()
			tween(panel, C.SnapTween, { Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1) })
			task.delay(0.08, function()
				if panel then tween(panel, C.FastTween, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 0) }) end
			end)
		end)

		return b
	end

	local BtnCollapse = iconButton("≡")
	local BtnMin = iconButton("—")
	local BtnClose = iconButton("×", THEME.DANGER)
	self.BtnMin = BtnMin

	-- Drag hit area
	local DragHit = mk("Frame", {
		Name = "DragHit",
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -170, 0, 56),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 150,
	})
	DragHit.Parent = TopBarCard
	self.DragHit = DragHit

	-- Body
	local Body = mk("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 88),
		Size = UDim2.new(1, 0, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 140,
	})
	Body.Parent = SurfaceSafe

	local SidebarHost = mk("Frame", {
		Name = "SidebarHost",
		Size = UDim2.new(0, C.SidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 150,
	})
	SidebarHost.Parent = Body

	local ContentHost = mk("Frame", {
		Name = "ContentHost",
		Position = UDim2.new(0, C.SidebarWidth + 14, 0, 0),
		Size = UDim2.new(1, -(C.SidebarWidth + 14), 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 150,
	})
	ContentHost.Parent = Body

	-- Sidebar panel
	local SidebarPanel, _, _, SidebarSafe = makeLunarPanel(SidebarHost, {
		Name = "SidebarPanel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 150,
		Corner = 12,
		BaseColor = lerpColor(THEME.PANEL_2, THEME.PANEL, 0.08),
		BaseTransparency = 0.10,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.60,
		InnerStrokeTransparency = 0.82,
		Glow = false,
		SafePadding = 12,
	}, THEME, PALETTE, ShimmerGradients)

	local SideHeader = mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.10),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "NAVIGATION",
		ZIndex = 165,
	})
	SideHeader.Parent = SidebarSafe

	local SideHeaderLine = mk("Frame", {
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = THEME.STROKE,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 165,
	})
	SideHeaderLine.Parent = SidebarSafe
	addGradient(SideHeaderLine, 0,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.STROKE),
			ColorSequenceKeypoint.new(0.5, THEME.ACCENT_3),
			ColorSequenceKeypoint.new(1, THEME.STROKE),
		}),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(0.5, 0.72),
			NumberSequenceKeypoint.new(1, 0.86),
		})
	)

	local TabsArea = mk("Frame", {
		Name = "TabsArea",
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 165,
	})
	TabsArea.Parent = SidebarSafe

	local TabsStack = mk("Frame", {
		Name = "TabsStack",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 165,
	})
	TabsStack.Parent = TabsArea

	local TabsOverlay = mk("Frame", {
		Name = "TabsOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 220,
	})
	TabsOverlay.Parent = TabsArea

	addList(TabsStack, 10)

	-- Tab indicator
	local TabIndicator = mk("Frame", {
		Name = "TabIndicator",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0, 26),
		Size = UDim2.new(0, 6, 0, 22),
		BackgroundColor3 = THEME.ACCENT,
		BackgroundTransparency = 0.10,
		BorderSizePixel = 0,
		ZIndex = 230,
	})
	TabIndicator.Parent = TabsOverlay
	addCornerRound(TabIndicator)

	local TabIndicatorGlow = mk("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
		BackgroundColor3 = THEME.ACCENT_2,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		ZIndex = 229,
	})
	TabIndicatorGlow.Parent = TabIndicator
	addCornerRound(TabIndicatorGlow)
	addGradient(TabIndicatorGlow, 45,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.ACCENT),
			ColorSequenceKeypoint.new(1, THEME.ACCENT_2),
		}),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(1, 0.98),
		})
	)

	local TabIndicatorGrad = addGradient(TabIndicator, 90,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.ACCENT),
			ColorSequenceKeypoint.new(1, THEME.ACCENT_2),
		}),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.00),
			NumberSequenceKeypoint.new(1, 0.00),
		})
	)
	TabIndicatorGrad.Offset = Vector2.new(0, 0)
	self._tabIndicatorGrad = TabIndicatorGrad
	self._tabIndicator = TabIndicator
	self._tabsArea = TabsArea

	-- Content panel
	local ContentPanel, _, _, ContentSafe = makeLunarPanel(ContentHost, {
		Name = "ContentPanel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 150,
		Corner = 12,
		BaseColor = lerpColor(THEME.PANEL_2, THEME.PANEL, 0.08),
		BaseTransparency = 0.10,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.60,
		InnerStrokeTransparency = 0.82,
		Glow = false,
		SafePadding = 14,
	}, THEME, PALETTE, ShimmerGradients)

	local ContentHeader = mk("Frame", {
		Name = "ContentHeader",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		ZIndex = 165,
	})
	ContentHeader.Parent = ContentSafe

	local CurrentTabTitle = mk("TextLabel", {
		Size = UDim2.new(1, -520, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = THEME.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Home",
		ZIndex = 170,
	})
	CurrentTabTitle.Parent = ContentHeader
	self._tabTitle = CurrentTabTitle

	local StatsHolder = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 190, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 170,
	})
	StatsHolder.Parent = ContentHeader

	local StatsPanel = select(1, makeLunarPanel(StatsHolder, {
		Name = "StatsPanel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 170,
		Corner = 10,
		BaseColor = PALETTE.Glass2,
		BaseTransparency = 0.10,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.66,
		InnerStrokeTransparency = 0.86,
		Glow = false,
		SafePadding = 8,
	}, THEME, PALETTE, ShimmerGradients))

	local StatsText = mk("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.10),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "fps: --",
		ZIndex = 180,
	})
	StatsText.Parent = StatsPanel
	self._statsText = StatsText

	-- Search bar
	local SearchHolder = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(190 + 12), 0.5, 0),
		Size = UDim2.new(0, 300, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 170,
	})
	SearchHolder.Parent = ContentHeader

	local SearchPanel = select(1, makeLunarPanel(SearchHolder, {
		Name = "SearchPanel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 170,
		Corner = 10,
		BaseColor = PALETTE.Glass2,
		BaseTransparency = 0.10,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.66,
		InnerStrokeTransparency = 0.86,
		Glow = false,
		SafePadding = 8,
	}, THEME, PALETTE, ShimmerGradients))
	local SearchSafe = SearchPanel:FindFirstChild("Safe")

	local SearchBox = mk("TextBox", {
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -26, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = THEME.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Text = "",
		ZIndex = 180,
	})
	SearchBox.Parent = SearchSafe
	self._searchBox = SearchBox

	local SearchPlaceholder = mk("TextLabel", {
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -26, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.25),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Search…  (Ctrl+F)",
		ZIndex = 179,
	})
	SearchPlaceholder.Parent = SearchSafe
	self._searchPlaceholder = SearchPlaceholder

	local ClearSearch = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 20, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = THEME.SOFT,
		Text = "×",
		AutoButtonColor = false,
		ZIndex = 181,
	})
	ClearSearch.Parent = SearchSafe
	self._clearSearch = ClearSearch
	ClearSearch.Visible = false

	local Pages = mk("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 160,
	})
	Pages.Parent = ContentSafe
	self._pagesHolder = Pages

	-- Tabs container (runtime)
	self._tabs = {}
	self._tabButtons = {}
	self._pages = {}
	self._selectedTab = nil
	self._searchMode = false
	self._lastTabBeforeSearch = nil
	self._sidebarCollapsed = false

	--==========================================================
	-- Components factory (used by Tab methods)
	--==========================================================
	local function makeCard(parent2, height, searchKey)
		local outer = mk("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			ZIndex = 170,
		})
		outer.Parent = parent2

		local panel, _stroke, _sheen, safe = makeLunarPanel(outer, {
			Name = "Card",
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 170,
			Corner = 12,
			BaseColor = PALETTE.Glass2,
			BaseTransparency = 0.10,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.62,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 12,
		}, THEME, PALETTE, ShimmerGradients)

		if searchKey then self:_registerSearch(outer, searchKey) end
		return outer, panel, safe
	end

	local function makeButton(parent2, text, hint, onClick)
		local outer, panel, safe = makeCard(parent2, 52, text .. " " .. (hint or ""))

		local btn = mk("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = THEME.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
			AutoButtonColor = false,
			ZIndex = 180,
		})
		btn.Parent = safe

		local hintLabel = mk("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 160, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = hint or "",
			ZIndex = 180,
		})
		hintLabel.Parent = safe

		local stroke = panel:FindFirstChildOfClass("UIStroke")
		btn.MouseEnter:Connect(function()
			tween(panel, C.FastTween, { BackgroundTransparency = 0.06 })
			if stroke then
				attachAccentStrokeGradient(stroke, THEME, AccentShimmers)
				tween(stroke, C.FastTween, { Transparency = 0.38 })
			end
		end)
		btn.MouseLeave:Connect(function()
			tween(panel, C.FastTween, { BackgroundTransparency = 0.10 })
			if stroke then
				tween(stroke, C.FastTween, { Transparency = 0.62, Color = PALETTE.EdgeDark })
			end
		end)
		btn.Activated:Connect(function()
			tween(panel, C.SnapTween, { Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1) })
			task.delay(0.08, function()
				if panel then tween(panel, C.FastTween, { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 0) }) end
			end)
			if typeof(onClick) == "function" then onClick() end
		end)

		return outer
	end

	local function makeToggle(parent2, text, default, onChanged)
		local outer, panel, safe = makeCard(parent2, 64, text)

		local label = mk("TextLabel", {
			Size = UDim2.new(1, -94, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = THEME.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			ZIndex = 180,
		})
		label.Parent = safe

		local switchHolder = mk("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 74, 0, 30),
			BackgroundTransparency = 1,
			ZIndex = 220,
		})
		switchHolder.Parent = safe

		local switchPanel = select(1, makeLunarPanel(switchHolder, {
			Name = "SwitchPanel",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 220,
			Corner = 999,
			BaseColor = lerpColor(PALETTE.Glass2, THEME.PANEL_2, 0.14),
			BaseTransparency = 0.12,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.70,
			InnerStrokeTransparency = 0.90,
			Glow = false,
			SafePadding = 0,
		}, THEME, PALETTE, ShimmerGradients))

		local knob = mk("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.new(0, 20, 0, 20),
			BackgroundColor3 = THEME.MUTED,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			ZIndex = 240,
		})
		knob.Parent = switchHolder
		addCornerRound(knob)
		local knobStroke = addStroke(knob, 1, 0.70, PALETTE.EdgeDark)

		local hit = mk("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 9999,
			Active = true,
		})
		hit.Parent = switchHolder

		local state = default == true
		local function render(instant)
			local pos2 = state and UDim2.new(1, -25, 0.5, 0) or UDim2.new(0, 5, 0.5, 0)
			local kc = state and THEME.ACCENT or THEME.MUTED
			local tr = state and 0.40 or 0.70
			if instant then
				knob.Position = pos2
				knob.BackgroundColor3 = kc
				knobStroke.Transparency = tr
			else
				tween(knob, C.FastTween, { Position = pos2, BackgroundColor3 = kc })
				tween(knobStroke, C.FastTween, { Transparency = tr })
			end
		end

		render(true)
		hit.Activated:Connect(function()
			state = not state
			render(false)
			if typeof(onChanged) == "function" then onChanged(state) end
		end)

		return outer, function() return state end, function(v) state = (v==true); render(true) end
	end

	local function makeSlider(parent2, labelText, opts, onChanged)
		opts = opts or {}
		local minVal = tonumber(opts.Min) or 0
		local maxVal = tonumber(opts.Max) or 100
		local step = tonumber(opts.Step) or 1
		local suffix = tostring(opts.Suffix or "%")
		local startVal = math.clamp(tonumber(opts.Default) or minVal, minVal, maxVal)

		local outer, panel, safe = makeCard(parent2, 78, labelText)

		local top = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
		top.Parent = safe

		local label = mk("TextLabel", {
			Size = UDim2.new(1, -120, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = THEME.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = labelText,
		})
		label.Parent = top

		local box = mk("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 110, 0, 26),
			BackgroundColor3 = PALETTE.Glass2,
			BackgroundTransparency = 0.10,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = THEME.TEXT,
			Text = tostring(math.floor(startVal + 0.5)) .. suffix,
			ClearTextOnFocus = false,
		})
		box.Parent = top
		addCornerPx(box, 8)
		addStroke(box, 1, 0.70, PALETTE.EdgeDark)

		local rail = mk("Frame", {
			Position = UDim2.new(0, 0, 0, 34),
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundColor3 = lerpColor(PALETTE.Glass2, THEME.PANEL_2, 0.25),
			BackgroundTransparency = 0.10,
			BorderSizePixel = 0,
		})
		rail.Parent = safe
		addCornerRound(rail)
		addStroke(rail, 1, 0.82, PALETTE.EdgeDark)

		local fill = mk("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = THEME.ACCENT,
			BackgroundTransparency = 0.10,
			BorderSizePixel = 0,
		})
		fill.Parent = rail
		addCornerRound(fill)

		local knob = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 16, 0, 16),
			BackgroundColor3 = THEME.ACCENT_3,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
		})
		knob.Parent = rail
		addCornerRound(knob)
		addStroke(knob, 1, 0.55, PALETTE.EdgeDark)

		local hint = mk("TextLabel", {
			Position = UDim2.new(0, 0, 0, 48),
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("Range: %s–%s", tostring(minVal), tostring(maxVal)),
		})
		hint.Parent = safe

		local dragging = false
		local value = startVal

		local targetT = (startVal - minVal) / math.max(1e-6, (maxVal - minVal))
		local currentT = targetT
		local SMOOTH = 18
		local editing = false

		local function syncBoxText(v)
			if editing or box:IsFocused() then return end
			box.Text = tostring(math.floor(v + 0.5)) .. suffix
		end

		local function setByT(t, fromText)
			t = math.clamp(t, 0, 1)
			targetT = t
			local v = minVal + (maxVal - minVal) * t
			v = roundStep(v, step)
			v = math.clamp(v, minVal, maxVal)
			value = v
			syncBoxText(v)
			if typeof(onChanged) == "function" then
				onChanged(value, fromText == true)
			end
		end

		local function setByValue(v, fromText)
			v = math.clamp(roundStep(v, step), minVal, maxVal)
			setByT((v - minVal) / math.max(1e-6, (maxVal - minVal)), fromText)
		end

		local function applyMouse(mx)
			local x0 = rail.AbsolutePosition.X
			local w = rail.AbsoluteSize.X
			local t = math.clamp((mx - x0) / math.max(1, w), 0, 1)
			setByT(t, false)
		end

		local hit = mk("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 9999,
		})
		hit.Parent = rail
		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				applyMouse(getMousePos().X)
			end
		end)

		self._maid:Give(UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				applyMouse(getMousePos().X)
			end
		end))

		self._maid:Give(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if dragging then
					dragging = false
					setByValue(value, false)
				end
			end
		end))

		box.Focused:Connect(function()
			editing = true
			box.Text = ""
		end)

		box.FocusLost:Connect(function()
			editing = false
			local n = parseNumeric(box.Text)
			if n then
				setByValue(n, true)
			else
				box.Text = tostring(math.floor(value + 0.5)) .. suffix
			end
		end)

		self._maid:Give(RunService.RenderStepped:Connect(function(dt)
			currentT = smoothStep(currentT, targetT, dt, SMOOTH)
			fill.Size = UDim2.new(currentT, 0, 1, 0)
			knob.Position = UDim2.new(currentT, 0, 0.5, 0)
		end))

		task.defer(function() setByValue(startVal, false) end)

		return outer, function() return value end, function(v) setByValue(v, true) end
	end

	local function makeDropdown(parent2, labelText, items, opts, onChanged)
		opts = opts or {}
		items = items or {}
		local multi = opts.Multi == true
		local default = opts.Default

		local ITEM_H = 34
		local POP_PAD = 12
		local POP_MAX_H = math.min(220, (#items * (ITEM_H + 8)) + (POP_PAD * 2))

		local outer = mk("Frame", {
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
		})
		outer.Parent = parent2
		self:_registerSearch(outer, labelText .. " " .. table.concat(items, " "))

		local panel = select(1, makeLunarPanel(outer, {
			Name = "DropRow",
			Size = UDim2.new(1, 0, 0, 54),
			ZIndex = 170,
			Corner = 12,
			BaseColor = PALETTE.Glass2,
			BaseTransparency = 0.10,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.62,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 12,
		}, THEME, PALETTE, ShimmerGradients))

		local safe = panel:FindFirstChild("Safe")

		local label = mk("TextLabel", {
			Size = UDim2.new(1, -220, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = THEME.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = labelText,
		})
		label.Parent = safe

		local btnHolder = mk("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 210, 0, 30),
			BackgroundTransparency = 1,
		})
		btnHolder.Parent = safe

		local btnPanel = select(1, makeLunarPanel(btnHolder, {
			Name = "DropBtnPanel",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 190,
			Corner = 10,
			BaseColor = PALETTE.Glass,
			BaseTransparency = 0.06,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.62,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 0,
		}, THEME, PALETTE, ShimmerGradients))

		local btnText = mk("TextLabel", {
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -28, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.15),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "Select…",
			ZIndex = 210,
		})
		btnText.Parent = btnPanel

		local caret = mk("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 16, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = THEME.SOFT,
			Text = "▾",
			ZIndex = 210,
		})
		caret.Parent = btnPanel

		local btn = mk("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 9999,
		})
		btn.Parent = btnHolder

		local popup = mk("CanvasGroup", {
			Position = UDim2.new(0, 0, 0, 58),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			ClipsDescendants = true,
			ZIndex = 200,
		})
		popup.Parent = outer

		local popupPanel = select(1, makeLunarPanel(popup, {
			Name = "DropPopupPanel",
			Size = UDim2.new(1, 0, 0, POP_MAX_H),
			ZIndex = 200,
			Corner = 12,
			BaseColor = PALETTE.Glass,
			BaseTransparency = 0.06,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.58,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 0,
		}, THEME, PALETTE, ShimmerGradients))

		local scroller = mk("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(0,0,0,0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageTransparency = 0.35,
		})
		scroller.Parent = popupPanel
		addPadding(scroller, POP_PAD, POP_PAD, POP_PAD, POP_PAD)
		addList(scroller, 8)

		local selectedSingle = nil
		local selectedMulti = {}
		if default then
			if multi then
				for _, it in ipairs(default) do selectedMulti[it] = true end
			else
				selectedSingle = default
			end
		end

		local rowRefs = {}
		local function renderButtonText()
			if multi then
				local picked = {}
				for _, it in ipairs(items) do
					if selectedMulti[it] then table.insert(picked, it) end
				end
				btnText.Text = (#picked > 0) and table.concat(picked, ", ") or "Select…"
			else
				btnText.Text = selectedSingle or "Select…"
			end
		end

		local function fireChanged()
			if typeof(onChanged) ~= "function" then return end
			if multi then
				local out = {}
				for _, it in ipairs(items) do
					if selectedMulti[it] then table.insert(out, it) end
				end
				onChanged(out)
			else
				onChanged(selectedSingle)
			end
		end

		local function updateVisual(it)
			local ref = rowRefs[it]
			if not ref then return end
			local active = multi and (selectedMulti[it] == true) or (selectedSingle == it)

			ref.dot.BackgroundTransparency = active and 0.12 or 1
			ref.txt.TextColor3 = active and THEME.ACCENT_3 or THEME.TEXT

			if ref.stroke then
				if active then
					attachAccentStrokeGradient(ref.stroke, THEME, AccentShimmers)
					ref.stroke.Transparency = 0.45
				else
					ref.stroke.Transparency = 0.74
					local g = ref.stroke:FindFirstChildOfClass("UIGradient")
					if g then g:Destroy() end
					ref.stroke.Color = PALETTE.EdgeDark
				end
			end
		end

		local open = false
		local function setOpen(v)
			open = v
			if open then
				popup.Visible = true
				tween(popup, C.FastTween, { GroupTransparency = 0 })
				tween(popup, C.SoftTween, { Size = UDim2.new(1, 0, 0, POP_MAX_H) })
				tween(outer, C.SoftTween, { Size = UDim2.new(1, 0, 0, 54 + POP_MAX_H + 8) })
				caret.Text = "▴"
			else
				tween(popup, C.FastTween, { GroupTransparency = 1 })
				tween(popup, C.SoftTween, { Size = UDim2.new(1, 0, 0, 0) })
				tween(outer, C.SoftTween, { Size = UDim2.new(1, 0, 0, 54) })
				caret.Text = "▾"
				task.delay(C.SoftTween.Time + 0.02, function()
					if not open then popup.Visible = false end
				end)
			end
		end

		btn.Activated:Connect(function() setOpen(not open) end)

		for _, it in ipairs(items) do
			local row = mk("Frame", { Size = UDim2.new(1, 0, 0, ITEM_H), BackgroundTransparency = 1 })
			row.Parent = scroller

			local rowPanel = select(1, makeLunarPanel(row, {
				Name = "ItemPanel_" .. it,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 210,
				Corner = 10,
				BaseColor = PALETTE.Glass2,
				BaseTransparency = 0.12,
				StrokeColor = PALETTE.EdgeDark,
				StrokeTransparency = 0.74,
				InnerStrokeTransparency = 0.92,
				Glow = false,
				SafePadding = 0,
			}, THEME, PALETTE, ShimmerGradients))

			local st = rowPanel:FindFirstChildOfClass("UIStroke")
			local dot = mk("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.new(0, 14, 0, 14),
				BackgroundColor3 = THEME.ACCENT,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 240,
			})
			dot.Parent = rowPanel
			addCornerRound(dot)
			addStroke(dot, 1, 0.55, PALETTE.EdgeDark)

			local txt = mk("TextLabel", {
				Name = "ItemText",
				Position = UDim2.new(0, 34, 0, 0),
				Size = UDim2.new(1, -44, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = THEME.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = it,
				ZIndex = 240,
			})
			txt.Parent = rowPanel

			local hit = mk("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 9999,
			})
			hit.Parent = rowPanel

			rowRefs[it] = { dot = dot, txt = txt, stroke = st }

			hit.Activated:Connect(function()
				if multi then
					selectedMulti[it] = not selectedMulti[it]
				else
					selectedSingle = it
				end
				renderButtonText()
				fireChanged()
				for _, name in ipairs(items) do updateVisual(name) end
			end)
		end

		renderButtonText()
		for _, it in ipairs(items) do updateVisual(it) end

		local function getValue()
			if multi then
				local out = {}
				for _, it in ipairs(items) do
					if selectedMulti[it] then table.insert(out, it) end
				end
				return out
			end
			return selectedSingle
		end

		return outer, getValue
	end

	-- Color picker (full luxury version)
	local function makeColorPicker(parent2, labelText, defaultColor, onChanged)
		defaultColor = defaultColor or THEME.ACCENT
		local POP_H = 410

		local outer = mk("Frame", {
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
		})
		outer.Parent = parent2
		self:_registerSearch(outer, labelText .. " color picker")

		local rowFrame = select(1, makeLunarPanel(outer, {
			Name = "ColorRow",
			Size = UDim2.new(1, 0, 0, 54),
			ZIndex = 170,
			Corner = 12,
			BaseColor = PALETTE.Glass2,
			BaseTransparency = 0.00,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.62,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 12,
		}, THEME, PALETTE, ShimmerGradients))
		local rowSafe = rowFrame:FindFirstChild("Safe")

		local label = mk("TextLabel", {
			Size = UDim2.new(1, -160, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = THEME.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = labelText,
		})
		label.Parent = rowSafe

		local swatchHolder = mk("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 140, 0, 30),
			BackgroundTransparency = 1,
		})
		swatchHolder.Parent = rowSafe

		local swatchPanel = select(1, makeLunarPanel(swatchHolder, {
			Name = "SwatchPanel",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 190,
			Corner = 10,
			BaseColor = PALETTE.Glass,
			BaseTransparency = 0.00,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.62,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 8,
		}, THEME, PALETTE, ShimmerGradients))
		local swSafe = swatchPanel:FindFirstChild("Safe")

		local swChecker = mk("Frame", {
			Size = UDim2.fromScale(1,1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})
		swChecker.Parent = swSafe
		addCornerPx(swChecker, 7)
		buildChecker(swChecker, 6, self._maid)

		local swatch = mk("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = defaultColor,
			BackgroundTransparency = 0.0,
			BorderSizePixel = 0,
		})
		swatch.Parent = swChecker
		addCornerPx(swatch, 7)

		local swatchBtn = mk("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 9999,
		})
		swatchBtn.Parent = swatchHolder

		local popup = mk("CanvasGroup", {
			Position = UDim2.new(0, 0, 0, 58),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			ClipsDescendants = true,
			ZIndex = 200,
		})
		popup.Parent = outer

		local popupPanel = select(1, makeLunarPanel(popup, {
			Name = "ColorPopupPanel",
			Size = UDim2.new(1, 0, 0, POP_H),
			ZIndex = 200,
			Corner = 12,
			BaseColor = PALETTE.Ink,
			BaseTransparency = 0.00,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.58,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 14,
		}, THEME, PALETTE, ShimmerGradients))
		local popSafe = popupPanel:FindFirstChild("Safe")

		local topRow = mk("Frame", { Size = UDim2.new(1,0,0,44), BackgroundTransparency = 1 })
		topRow.Parent = popSafe

		local body = mk("Frame", { Position = UDim2.new(0,0,0,52), Size = UDim2.new(1,0,1,-52), BackgroundTransparency = 1 })
		body.Parent = popSafe

		-- Preview
		local bigHolder = mk("Frame", { Size = UDim2.new(0, 44, 0, 44), BackgroundTransparency = 1 })
		bigHolder.Parent = topRow

		local bigPanel = select(1, makeLunarPanel(bigHolder, {
			Name = "BigPreview",
			Size = UDim2.fromScale(1,1),
			ZIndex = 240,
			Corner = 12,
			BaseColor = PALETTE.Glass2,
			BaseTransparency = 0.00,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.70,
			InnerStrokeTransparency = 0.90,
			Glow = false,
			SafePadding = 8,
		}, THEME, PALETTE, ShimmerGradients))
		local bigSafe = bigPanel:FindFirstChild("Safe")

		local bigChecker = mk("Frame", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, ClipsDescendants = true })
		bigChecker.Parent = bigSafe
		addCornerPx(bigChecker, 9)
		buildChecker(bigChecker, 5, self._maid)

		local big = mk("Frame", { Size = UDim2.fromScale(1,1), BackgroundColor3 = defaultColor, BackgroundTransparency = 0.0, BorderSizePixel = 0 })
		big.Parent = bigChecker
		addCornerPx(big, 9)

		local hexBox = mk("TextBox", {
			Position = UDim2.new(0, 56, 0, 9),
			Size = UDim2.new(0, 160, 0, 26),
			BackgroundColor3 = PALETTE.Glass2,
			BackgroundTransparency = 0.00,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = THEME.TEXT,
			ClearTextOnFocus = false,
			Text = toHex(defaultColor),
		})
		hexBox.Parent = topRow
		addCornerPx(hexBox, 8)
		addStroke(hexBox, 1, 0.70, PALETTE.EdgeDark)

		-- Buttons
		local btns = mk("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 9),
			Size = UDim2.new(0, 280, 0, 26),
			BackgroundTransparency = 1,
		})
		btns.Parent = topRow
		local bl = addList(btns, 10)
		bl.FillDirection = Enum.FillDirection.Horizontal
		bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		bl.VerticalAlignment = Enum.VerticalAlignment.Center

		local function smallPill(parent3, title)
			local hfr = mk("Frame", { Size = UDim2.new(0, 86, 1, 0), BackgroundTransparency = 1 })
			hfr.Parent = parent3

			select(1, makeLunarPanel(hfr, {
				Name = "Pill",
				Size = UDim2.fromScale(1,1),
				ZIndex = 250,
				Corner = 8,
				BaseColor = PALETTE.Glass2,
				BaseTransparency = 0.00,
				StrokeColor = PALETTE.EdgeDark,
				StrokeTransparency = 0.70,
				InnerStrokeTransparency = 0.90,
				Glow = false,
				SafePadding = 0,
			}, THEME, PALETTE, ShimmerGradients))

			local b = mk("TextButton", {
				Size = UDim2.fromScale(1,1),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = THEME.TEXT,
				Text = title,
				AutoButtonColor = false,
				ZIndex = 9999,
			})
			b.Parent = hfr
			return b
		end

		local CopyBtn = smallPill(btns, "COPY")
		local ResetBtn = smallPill(btns, "RESET")
		local RandBtn = smallPill(btns, "RANDOM")

		-- Body split
		local left = mk("Frame", { Size = UDim2.new(0, 240, 1, 0), BackgroundTransparency = 1 })
		left.Parent = body
		local right = mk("Frame", { Position = UDim2.new(0, 252, 0, 0), Size = UDim2.new(1, -252, 1, 0), BackgroundTransparency = 1 })
		right.Parent = body

		-- SV
		local SVHolder = mk("Frame", {
			Position = UDim2.new(0,0,0,0),
			Size = UDim2.new(0, 232, 0, 182),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		})
		SVHolder.Parent = left

		local SVClip = mk("Frame", {
			Size = UDim2.fromScale(1,1),
			BackgroundColor3 = Color3.fromHSV(0,1,1),
			BackgroundTransparency = 0.00,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})
		SVClip.Parent = SVHolder
		addCornerPx(SVClip, 12)
		addStroke(SVClip, 1, 0.60, PALETTE.EdgeDark)

		local sat = mk("Frame", { Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0 })
		sat.Parent = SVClip
		addGradient(sat, 0, ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1)), NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.00),
			NumberSequenceKeypoint.new(1, 1.00),
		}))

		local val = mk("Frame", { Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0 })
		val.Parent = SVClip
		addGradient(val, 90, ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0)), NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.00),
			NumberSequenceKeypoint.new(1, 0.00),
		}))

		local svKnob = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundColor3 = THEME.ACCENT_3,
			BorderSizePixel = 0,
			ZIndex = 300,
		})
		svKnob.Parent = SVHolder
		addCornerRound(svKnob)
		addStroke(svKnob, 2, 0.18, Color3.new(0,0,0))

		-- Hue bar
		local hueHolder = mk("Frame", {
			Position = UDim2.new(0, 0, 0, 194),
			Size = UDim2.new(0, 232, 0, 12),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		})
		hueHolder.Parent = left

		local hueClip = mk("Frame", {
			Size = UDim2.fromScale(1,1),
			BackgroundColor3 = Color3.new(1,1,1),
			BackgroundTransparency = 0.00,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})
		hueClip.Parent = hueHolder
		addCornerRound(hueClip)
		addStroke(hueClip, 1, 0.70, PALETTE.EdgeDark)

		addGradient(hueClip, 0, ColorSequence.new({
			ColorSequenceKeypoint.new(0/6, Color3.fromHSV(0/6, 1, 1)),
			ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
			ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
			ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
			ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
			ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
			ColorSequenceKeypoint.new(6/6, Color3.fromHSV(6/6, 1, 1)),
		}))

		local hueKnob = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundColor3 = THEME.ACCENT_3,
			BorderSizePixel = 0,
			ZIndex = 300,
		})
		hueKnob.Parent = hueHolder
		addCornerRound(hueKnob)
		addStroke(hueKnob, 2, 0.18, Color3.new(0,0,0))

		-- Alpha bar (checker + knob)
		local aHolder = mk("Frame", {
			Position = UDim2.new(0, 0, 0, 214),
			Size = UDim2.new(0, 232, 0, 12),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		})
		aHolder.Parent = left

		local aClip = mk("Frame", {
			Size = UDim2.fromScale(1,1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})
		aClip.Parent = aHolder
		addCornerRound(aClip)
		addStroke(aClip, 1, 0.70, PALETTE.EdgeDark)
		buildChecker(aClip, 5, self._maid)

		local aFill = mk("Frame", {
			Size = UDim2.fromScale(1,1),
			BackgroundColor3 = defaultColor,
			BackgroundTransparency = 0.0,
			BorderSizePixel = 0,
		})
		aFill.Parent = aClip
		addCornerRound(aFill)

		local aGrad = addGradient(aFill, 0,
			ColorSequence.new({ ColorSequenceKeypoint.new(0, defaultColor), ColorSequenceKeypoint.new(1, defaultColor) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.00), NumberSequenceKeypoint.new(1, 0.00) })
		)

		local aKnob = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundColor3 = THEME.ACCENT_3,
			BorderSizePixel = 0,
			ZIndex = 300,
		})
		aKnob.Parent = aHolder
		addCornerRound(aKnob)
		addStroke(aKnob, 2, 0.18, Color3.new(0,0,0))

		-- Right fields
		local function fieldRow(y, name, w)
			local lab = mk("TextLabel", {
				Position = UDim2.new(0, 0, 0, y),
				Size = UDim2.new(0, 20, 0, 26),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.15),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = name,
			})
			lab.Parent = right

			local box = mk("TextBox", {
				Position = UDim2.new(0, 24, 0, y),
				Size = UDim2.new(0, w, 0, 26),
				BackgroundColor3 = PALETTE.Glass2,
				BackgroundTransparency = 0.00,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = THEME.TEXT,
				ClearTextOnFocus = false,
				Text = "",
			})
			box.Parent = right
			addCornerPx(box, 8)
			addStroke(box, 1, 0.70, PALETTE.EdgeDark)
			return box
		end

		local rBox = fieldRow(0, "R", 80)
		local gBox = fieldRow(34, "G", 80)
		local bBox = fieldRow(68, "B", 80)
		local hBox = fieldRow(112, "H", 80)
		local sBox = fieldRow(146, "S", 80)
		local vBox = fieldRow(180, "V", 80)
		local aBox = fieldRow(214, "A", 80)

		local help = mk("TextLabel", {
			Position = UDim2.new(0, 120, 0, 0),
			Size = UDim2.new(1, -120, 0, 120),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Text = "SV: drag square\nHue: rainbow bar\nAlpha: checker bar\n\nH: 0–360\nS/V/A: 0–100",
		})
		help.Parent = right

		local recentLabel = mk("TextLabel", {
			Position = UDim2.new(0, 0, 0, 264),
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.15),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "RECENT",
		})
		recentLabel.Parent = right

		local recentRow = mk("Frame", {
			Position = UDim2.new(0, 0, 0, 286),
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
		})
		recentRow.Parent = right
		local rl = addList(recentRow, 8)
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		rl.VerticalAlignment = Enum.VerticalAlignment.Center

		local MAX_RECENT = 8
		local recent = { { c = defaultColor, a = 1 } }
		local recentSlots = {}

		for i = 1, MAX_RECENT do
			local hfr = mk("Frame", { Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1 })
			hfr.Parent = recentRow

			local p = select(1, makeLunarPanel(hfr, {
				Name = "Recent_"..i,
				Size = UDim2.fromScale(1,1),
				ZIndex = 260,
				Corner = 8,
				BaseColor = PALETTE.Glass2,
				BaseTransparency = 0.00,
				StrokeColor = PALETTE.EdgeDark,
				StrokeTransparency = 0.70,
				InnerStrokeTransparency = 0.90,
				Glow = false,
				SafePadding = 4,
			}, THEME, PALETTE, ShimmerGradients))
			local s = p:FindFirstChild("Safe")

			local checker = mk("Frame", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, ClipsDescendants = true })
			checker.Parent = s
			addCornerPx(checker, 6)
			buildChecker(checker, 5, self._maid)

			local col = mk("Frame", { Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.0, BorderSizePixel = 0 })
			col.Parent = checker
			addCornerPx(col, 6)

			local b = mk("TextButton", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9999 })
			b.Parent = hfr

			recentSlots[i] = { color = col, btn = b }
		end

		local function sameColor(a, b)
			return (math.abs(a.R - b.R) < 0.001) and (math.abs(a.G - b.G) < 0.001) and (math.abs(a.B - b.B) < 0.001)
		end

		local function pushRecent(c, a)
			for i = #recent, 1, -1 do
				local it = recent[i]
				if it and sameColor(it.c, c) and math.abs((it.a or 1) - a) < 0.01 then
					table.remove(recent, i)
				end
			end
			table.insert(recent, 1, { c = c, a = a })
			while #recent > MAX_RECENT do
				table.remove(recent, #recent)
			end
		end

		-- HSV + Alpha state
		local h0, s0, v0 = Color3.toHSV(defaultColor)
		local hT, sT, vT, aT = h0, s0, v0, 1
		local hC, sC, vC, aC = hT, sT, vT, aT

		local SMOOTH = 14
		local TEXT_RATE = 1/20
		local lastTextSync = 0
		local dirtyCommit = false

		local function hueSmooth(current, target, dt)
			local t = target
			local diff = t - current
			if diff > 0.5 then t -= 1 end
			if diff < -0.5 then t += 1 end
			local out = smoothStep(current, t, dt, SMOOTH)
			out = out % 1
			return out
		end

		local function currentColor()
			return Color3.fromHSV(hC, sC, vC)
		end

		local function setColor(c, a, fromRecent)
			local hh, ss, vv = Color3.toHSV(c)
			hT, sT, vT = hh, ss, vv
			hC, sC, vC = hh, ss, vv
			aT, aC = math.clamp(a or 1, 0, 1), math.clamp(a or 1, 0, 1)
			dirtyCommit = true
		end

		local function refreshRecent()
			for i = 1, MAX_RECENT do
				local it = recent[i]
				if it then
					recentSlots[i].color.BackgroundColor3 = it.c
					recentSlots[i].color.BackgroundTransparency = 1 - math.clamp(it.a or 1, 0, 1)
				else
					recentSlots[i].color.BackgroundColor3 = PALETTE.Deep
					recentSlots[i].color.BackgroundTransparency = 0
				end
			end
		end

		for i = 1, MAX_RECENT do
			local idx = i
			recentSlots[i].btn.Activated:Connect(function()
				local it = recent[idx]
				if it then setColor(it.c, it.a or 1, true) end
			end)
		end

		local function updateVisual(fullText)
			local col = currentColor()
			local alpha = math.clamp(aC, 0, 1)

			swatch.BackgroundColor3 = col
			swatch.BackgroundTransparency = 1 - alpha

			big.BackgroundColor3 = col
			big.BackgroundTransparency = 1 - alpha

			SVClip.BackgroundColor3 = Color3.fromHSV(hC, 1, 1)
			aFill.BackgroundColor3 = col

			aGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, col),
				ColorSequenceKeypoint.new(1, col),
			})
			aGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.00),
				NumberSequenceKeypoint.new(1, 1 - alpha),
			})

			if fullText then
				if not hexBox:IsFocused() then hexBox.Text = toHex(col) end
				local rr = math.floor(col.R * 255 + 0.5)
				local gg = math.floor(col.G * 255 + 0.5)
				local bb = math.floor(col.B * 255 + 0.5)
				if not rBox:IsFocused() then rBox.Text = tostring(rr) end
				if not gBox:IsFocused() then gBox.Text = tostring(gg) end
				if not bBox:IsFocused() then bBox.Text = tostring(bb) end
				if not hBox:IsFocused() then hBox.Text = tostring(math.floor(hC * 360 + 0.5)) end
				if not sBox:IsFocused() then sBox.Text = tostring(math.floor(sC * 100 + 0.5)) end
				if not vBox:IsFocused() then vBox.Text = tostring(math.floor(vC * 100 + 0.5)) end
				if not aBox:IsFocused() then aBox.Text = tostring(math.floor(alpha * 100 + 0.5)) end
			end
		end

		local function commitChange()
			dirtyCommit = false
			local col = currentColor()
			local alpha = math.clamp(aC, 0, 1)

			pushRecent(col, alpha)
			refreshRecent()

			if typeof(onChanged) == "function" then
				onChanged(col, alpha)
			end
		end

		-- smoothed knobs + text
		self._maid:Give(RunService.RenderStepped:Connect(function(dt)
			hC = hueSmooth(hC, hT, dt)
			sC = smoothStep(sC, sT, dt, SMOOTH)
			vC = smoothStep(vC, vT, dt, SMOOTH)
			aC = smoothStep(aC, aT, dt, SMOOTH)

			svKnob.Position = UDim2.new(sC, 0, 1 - vC, 0)
			hueKnob.Position = UDim2.new(hC, 0, 0.5, 0)
			aKnob.Position = UDim2.new(aC, 0, 0.5, 0)

			updateVisual(false)

			local now = os.clock()
			if now - lastTextSync >= TEXT_RATE then
				lastTextSync = now
				updateVisual(true)
			end

			if dirtyCommit then
				commitChange()
			end
		end))

		-- Open / close
		local open = false
		local function setOpen(vv)
			open = vv
			if open then
				popup.Visible = true
				tween(popup, C.FastTween, { GroupTransparency = 0 })
				tween(popup, C.SoftTween, { Size = UDim2.new(1, 0, 0, POP_H) })
				tween(outer, C.SoftTween, { Size = UDim2.new(1, 0, 0, 54 + POP_H + 8) })
			else
				tween(popup, C.FastTween, { GroupTransparency = 1 })
				tween(popup, C.SoftTween, { Size = UDim2.new(1, 0, 0, 0) })
				tween(outer, C.SoftTween, { Size = UDim2.new(1, 0, 0, 54) })
				task.delay(C.SoftTween.Time + 0.02, function()
					if not open then popup.Visible = false end
				end)
			end
		end

		swatchBtn.Activated:Connect(function() setOpen(not open) end)

		-- Dragging
		local draggingSV, draggingHue, draggingA = false, false, false

		local function tFromRail(railFrame, mx)
			local p = railFrame.AbsolutePosition
			local sz = railFrame.AbsoluteSize
			return math.clamp((mx - p.X) / math.max(1, sz.X), 0, 1)
		end

		local function setSVFromMouse(mx, my)
			local p = SVClip.AbsolutePosition
			local sz = SVClip.AbsoluteSize
			local tx = math.clamp((mx - p.X) / math.max(1, sz.X), 0, 1)
			local ty = math.clamp((my - p.Y) / math.max(1, sz.Y), 0, 1)
			sT = tx
			vT = 1 - ty
		end

		local svHit = mk("TextButton", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9999 })
		svHit.Parent = SVClip
		svHit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSV = true
				local m = getMousePos()
				setSVFromMouse(m.X, m.Y)
			end
		end)

		local hueHit = mk("TextButton", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9999 })
		hueHit.Parent = hueClip
		hueHit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingHue = true
				local m = getMousePos()
				hT = tFromRail(hueClip, m.X)
			end
		end)

		local aHit = mk("TextButton", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9999 })
		aHit.Parent = aClip
		aHit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingA = true
				local m = getMousePos()
				aT = tFromRail(aClip, m.X)
			end
		end)

		self._maid:Give(UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local m = getMousePos()
			if draggingSV then
				setSVFromMouse(m.X, m.Y)
			elseif draggingHue then
				hT = tFromRail(hueClip, m.X)
			elseif draggingA then
				aT = tFromRail(aClip, m.X)
			end
		end))

		self._maid:Give(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if draggingSV or draggingHue or draggingA then
					dirtyCommit = true
				end
				draggingSV, draggingHue, draggingA = false, false, false
			end
		end))

		-- Inputs
		hexBox.FocusLost:Connect(function()
			local c2 = fromHex(hexBox.Text)
			if c2 then
				local hh, ss, vv = Color3.toHSV(c2)
				hT, sT, vT = hh, ss, vv
				hC, sC, vC = hh, ss, vv
				dirtyCommit = true
			else
				hexBox.Text = toHex(currentColor())
			end
		end)

		local function applyRGB()
			local rr = parseNumeric(rBox.Text)
			local gg = parseNumeric(gBox.Text)
			local bb = parseNumeric(bBox.Text)
			if rr and gg and bb then
				rr = math.clamp(math.floor(rr + 0.5), 0, 255)
				gg = math.clamp(math.floor(gg + 0.5), 0, 255)
				bb = math.clamp(math.floor(bb + 0.5), 0, 255)
				local c2 = Color3.fromRGB(rr, gg, bb)
				local hh, ss, vv = Color3.toHSV(c2)
				hT, sT, vT = hh, ss, vv
				hC, sC, vC = hh, ss, vv
				dirtyCommit = true
			end
		end
		rBox.FocusLost:Connect(applyRGB)
		gBox.FocusLost:Connect(applyRGB)
		bBox.FocusLost:Connect(applyRGB)

		local function applyHSV()
			local hh = parseNumeric(hBox.Text)
			local ss = parseNumeric(sBox.Text)
			local vv = parseNumeric(vBox.Text)
			if hh then hT = math.clamp(hh, 0, 360) / 360; hC = hT end
			if ss then sT = math.clamp(ss, 0, 100) / 100; sC = sT end
			if vv then vT = math.clamp(vv, 0, 100) / 100; vC = vT end
			dirtyCommit = true
		end
		hBox.FocusLost:Connect(applyHSV)
		sBox.FocusLost:Connect(applyHSV)
		vBox.FocusLost:Connect(applyHSV)

		aBox.FocusLost:Connect(function()
			local n = parseNumeric(aBox.Text)
			if n then
				aT = math.clamp(n, 0, 100) / 100
				aC = aT
				dirtyCommit = true
			end
		end)

		-- Buttons
		CopyBtn.Activated:Connect(function()
			hexBox:CaptureFocus()
			hexBox.CursorPosition = 1
			hexBox.SelectionStart = #hexBox.Text + 1
			self:Toast("Color", "HEX selected (Ctrl+C)", THEME.ACCENT, 1.4)
		end)

		ResetBtn.Activated:Connect(function()
			hT, sT, vT = h0, s0, v0
			hC, sC, vC = h0, s0, v0
			aT, aC = 1, 1
			dirtyCommit = true
		end)

		RandBtn.Activated:Connect(function()
			local hh = self._rng:NextNumber(0.52, 0.78)
			local ss = self._rng:NextNumber(0.18, 0.55)
			local vv = self._rng:NextNumber(0.65, 0.98)
			hT, sT, vT = hh, ss, vv
			hC, sC, vC = hh, ss, vv
			aT, aC = self._rng:NextInteger(60, 100) / 100, self._rng:NextInteger(60, 100) / 100
			dirtyCommit = true
		end)

		refreshRecent()
		updateVisual(true)
		setOpen(false)

		return outer, function()
			return currentColor(), aC
		end
	end


	--==========================================================
	-- Page helper
	--==========================================================
	local function makePage(name)
		local page = mk("CanvasGroup", {
			Name = "Page_" .. name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 170,
		})
		page.Parent = Pages

		local scroll = mk("ScrollingFrame", {
			Name = "Scroll",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 3,
			ScrollBarImageTransparency = 0.30,
			ZIndex = 170,
		})
		scroll.Parent = page
		addPadding(scroll, 2, 10, 2, 12)
		addList(scroll, 12)
		return page, scroll
	end

			-- store factories so ui:Tab() can create tabs later even if DefaultTabs is empty
	self._factory = {
		TabsStack = TabsStack,
		makePage = makePage,
		makeButton = makeButton,
		makeToggle = makeToggle,
		makeSlider = makeSlider,
		makeDropdown = makeDropdown,
		makeColorPicker = makeColorPicker,
	}
	

	-- Search results page
	local SearchPage, SearchScroll = makePage("__Search")
	SearchPage.Name = "Page_Search"
	SearchScroll.Name = "Scroll_Search"
	self._searchPage = SearchPage
	self._searchScroll = SearchScroll

	--==========================================================
	-- Tabs: minimal defaults (you can add your own via ui:Tab)
	--==========================================================
    local defaultTabs = C.DefaultTabs
    if defaultTabs == nil then
        defaultTabs = {
            { Name = "Home", Icon = "☾" },
            { Name = "Showcase", Icon = "✦" },
            { Name = "Visual", Icon = "◐" },
            { Name = "Settings", Icon = "⚙" },
            { Name = "About", Icon = "i" },
        }
    end

    self._defaultTabs = defaultTabs

    if type(defaultTabs) == "table" and #defaultTabs > 0 then
        for i, def in ipairs(defaultTabs) do
            self:_createTab(def.Name, def.Icon, i, TabsStack, makePage, makeButton, makeToggle, makeSlider, makeDropdown, makeColorPicker)
        end
    end

	--==========================================================
	-- Sidebar collapse
	--==========================================================
    local function applySidebarLayout()
        local w = self._sidebarCollapsed and C.SidebarCollapsedWidth or C.SidebarWidth
        tween(SidebarHost, C.SoftTween, { Size = UDim2.new(0, w, 1, 0) })
        tween(ContentHost, C.SoftTween, {
            Position = UDim2.new(0, w + 14, 0, 0),
            Size = UDim2.new(1, -(w + 14), 1, 0),
        })
        for _, t in pairs(self._tabButtons) do
            local nameLabel = t.nameLabel
            if nameLabel and nameLabel:IsA("TextLabel") then
                tween(nameLabel, C.FastTween, { TextTransparency = self._sidebarCollapsed and 1 or 0 })
            end
        end
        tween(SideHeader, C.FastTween, { TextTransparency = self._sidebarCollapsed and 1 or 0 })
        tween(SideHeaderLine, C.FastTween, { BackgroundTransparency = self._sidebarCollapsed and 1 or 0.82 })
        task.delay(0.06, function()
            if self._tabButtons[self._selectedTab] then
                self:_moveIndicatorTo(self._tabButtons[self._selectedTab].outer, true)
            end
        end)
        self:Toast("Sidebar", self._sidebarCollapsed and "Collapsed" or "Expanded", THEME.ACCENT, 1.6)
    end

	BtnCollapse.Activated:Connect(function()
		self._sidebarCollapsed = not self._sidebarCollapsed
		applySidebarLayout()
	end)

	--==========================================================
	-- Modal (confirm)
	--==========================================================
	local Modal = mk("CanvasGroup", {
		Name = "Modal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 2500,
	})
	Modal.Parent = ScreenGui
	self.Modal = Modal

	local ModalHolder = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 230),
		BackgroundTransparency = 1,
		ZIndex = 2501,
	})
	ModalHolder.Parent = Modal
	makeSoftShadow(ModalHolder, 2490, 12)

	select(1, makeLunarPanel(ModalHolder, {
		Name = "ModalPanel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2501,
		Corner = 14,
		BaseColor = PALETTE.Glass,
		BaseTransparency = 0.06,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.52,
		InnerStrokeTransparency = 0.82,
		Glow = true,
		SafePadding = 16,
	}, THEME, PALETTE, ShimmerGradients))

	local ModalTitle = mk("TextLabel", {
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(1, -32, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = THEME.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Confirm",
		ZIndex = 2600,
	})
	ModalTitle.Parent = ModalHolder

	local ModalDesc = mk("TextLabel", {
		Position = UDim2.new(0, 16, 0, 50),
		Size = UDim2.new(1, -32, 0, 64),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
		ZIndex = 2600,
	})
	ModalDesc.Parent = ModalHolder

	self._modalTitle = ModalTitle
	self._modalDesc = ModalDesc

	local ModalBtns = mk("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(1, -32, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 2600,
	})
	ModalBtns.Parent = ModalHolder

	local btnList = addList(ModalBtns, 10)
	btnList.FillDirection = Enum.FillDirection.Horizontal
	btnList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	btnList.VerticalAlignment = Enum.VerticalAlignment.Center

	local function pill(text, col)
		local holder = mk("Frame", { Size = UDim2.new(0, 130, 1, 0), BackgroundTransparency = 1 })
		holder.Parent = ModalBtns

		local panel = select(1, makeLunarPanel(holder, {
			Name = "PillPanel",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2600,
			Corner = 12,
			BaseColor = PALETTE.Glass2,
			BaseTransparency = 0.08,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.60,
			InnerStrokeTransparency = 0.86,
			Glow = false,
			SafePadding = 0,
		}, THEME, PALETTE, ShimmerGradients))

		local b = mk("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = col or THEME.TEXT,
			Text = text,
			AutoButtonColor = false,
			ZIndex = 9999,
		})
		b.Parent = holder

		local st = panel:FindFirstChildOfClass("UIStroke")
		b.MouseEnter:Connect(function()
			tween(panel, C.FastTween, { BackgroundTransparency = 0.04 })
			if st then
				attachAccentStrokeGradient(st, THEME, AccentShimmers)
				tween(st, C.FastTween, { Transparency = 0.35 })
			end
		end)
		b.MouseLeave:Connect(function()
			tween(panel, C.FastTween, { BackgroundTransparency = 0.08 })
			if st then
				tween(st, C.FastTween, { Transparency = 0.60, Color = PALETTE.EdgeDark })
			end
		end)

		return b
	end

	local CancelBtn = pill("Keep open")
	local OkBtn = pill("Close", THEME.DANGER)

	self._modalYes = nil
	self._modalNo = nil

	function self:_showModal(v)
		if v then
			playSound(C.ModalSoundId, 0.55)
			Modal.Visible = true
			Modal.GroupTransparency = 1
			tween(Modal, C.SoftTween, { GroupTransparency = 0 })
		else
			tween(Modal, C.CloseTween, { GroupTransparency = 1 })
			task.delay(C.CloseTween.Time + 0.02, function()
				if Modal then Modal.Visible = false end
			end)
		end
	end

	CancelBtn.Activated:Connect(function()
		self:_showModal(false)
		if typeof(self._modalNo) == "function" then
			local f = self._modalNo
			self._modalNo, self._modalYes = nil, nil
			f()
		end
	end)

	OkBtn.Activated:Connect(function()
		self:_showModal(false)
		if typeof(self._modalYes) == "function" then
			local f = self._modalYes
			self._modalNo, self._modalYes = nil, nil
			f()
		end
	end)

	BtnClose.Activated:Connect(function()
		self:Confirm("Unload "..tostring(C.Name).."?", "This will remove the UI.\nRun again to reopen.", function()
			self:Destroy()
		end)
	end)

	--==========================================================
	-- Toasts
	--==========================================================
	local ToastLayer = mk("Frame", {
		Name = "ToastLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3000,
	})
	ToastLayer.Parent = ToastGui

	local toasts = {}
	self._toasts = toasts

	local TOAST_W, TOAST_H = 340, 78
	local TOAST_GAP, TOAST_MARGIN = 10, 18

	local function getViewport()
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize or Vector2.new(1920, 1080)
	end
	self._getViewport = getViewport

	local function layoutToasts()
		local vs = getViewport()
		for i, t in ipairs(toasts) do
			local targetX = vs.X - TOAST_MARGIN
			local targetY = vs.Y - TOAST_MARGIN - ((i - 1) * (TOAST_H + TOAST_GAP))
			tween(t.card, C.SoftTween, { Position = UDim2.fromOffset(targetX, targetY) })
		end
	end

	local function Toast(title, desc, color, duration)
		duration = duration or 2.6
		color = color or THEME.ACCENT
		playSound(C.ToastSoundId, 0.50)

		local holder = mk("CanvasGroup", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromOffset(99999, 99999),
			Size = UDim2.fromOffset(TOAST_W, TOAST_H),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			ZIndex = 3000,
		})
		holder.Parent = ToastLayer

		select(1, makeLunarPanel(holder, {
			Name = "ToastPanel",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3000,
			Corner = 12,
			BaseColor = PALETTE.Glass,
			BaseTransparency = 0.08,
			StrokeColor = PALETTE.EdgeDark,
			StrokeTransparency = 0.55,
			InnerStrokeTransparency = 0.82,
			Glow = false,
			SafePadding = 12,
		}, THEME, PALETTE, ShimmerGradients))

		local bar = mk("Frame", {
			Position = UDim2.new(0, 10, 0, 12),
			Size = UDim2.new(0, 4, 1, -40),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			ZIndex = 3010,
		})
		bar.Parent = holder
		addCornerRound(bar)
		addGradient(bar, 90,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, color),
				ColorSequenceKeypoint.new(1, lerpColor(color, THEME.ACCENT_2, 0.35)),
			}),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.10),
				NumberSequenceKeypoint.new(1, 0.24),
			})
		)

		local t1 = mk("TextLabel", {
			Position = UDim2.new(0, 22, 0, 12),
			Size = UDim2.new(1, -120, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = THEME.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(title),
			ZIndex = 3010,
		})
		t1.Parent = holder

		local t2 = mk("TextLabel", {
			Position = UDim2.new(0, 22, 0, 32),
			Size = UDim2.new(1, -34, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(desc),
			ZIndex = 3010,
		})
		t2.Parent = holder

		local timeLabel = mk("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.new(0, 86, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.18),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = string.format("%.1fs", duration),
			ZIndex = 3010,
		})
		timeLabel.Parent = holder

		local progRail = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -24, 0, 5),
			BackgroundColor3 = lerpColor(PALETTE.Glass2, THEME.PANEL_2, 0.20),
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			ZIndex = 3010,
		})
		progRail.Parent = holder
		addCornerRound(progRail)
		addStroke(progRail, 1, 0.82, PALETTE.EdgeDark)

		local progFill = mk("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.10,
			BorderSizePixel = 0,
			ZIndex = 3011,
		})
		progFill.Parent = progRail
		addCornerRound(progFill)
		addGradient(progFill, 0,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, color),
				ColorSequenceKeypoint.new(1, lerpColor(color, THEME.ACCENT_2, 0.40)),
			}),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.10),
				NumberSequenceKeypoint.new(1, 0.26),
			})
		)

		local obj = {
			card = holder,
			created = os.clock(),
			duration = duration,
			timeLabel = timeLabel,
			barFill = progFill,
		}
		table.insert(toasts, 1, obj)

		local vs = getViewport()
		holder.Position = UDim2.fromOffset(vs.X + TOAST_W + 60, vs.Y - TOAST_MARGIN)
		tween(holder, C.SoftTween, { GroupTransparency = 0 })
		layoutToasts()

		task.delay(duration, function()
			local idx = table.find(toasts, obj)
			if idx then
				tween(holder, C.CloseTween, { GroupTransparency = 1 })
				tween(holder, C.CloseTween, { Position = UDim2.fromOffset(vs.X + TOAST_W + 90, holder.Position.Y.Offset) })
				task.delay(C.CloseTween.Time + 0.05, function()
					if holder then holder:Destroy() end
				end)
				table.remove(toasts, idx)
				layoutToasts()
			end
		end)
	end

	self._toast = Toast

	--==========================================================
	-- Search logic (global)
	--==========================================================
	local function clearSearchResults()
		for _, ch in ipairs(SearchScroll:GetChildren()) do
			if ch:IsA("Frame") or ch:IsA("CanvasGroup") or ch:IsA("TextLabel") then
				if ch.Name ~= "UIListLayout" and ch.Name ~= "UIPadding" then
					ch:Destroy()
				end
			end
		end
	end

	local function matchAllTokens(hay, tokens)
		hay = toLower(hay)
		for _, t in ipairs(tokens) do
			if t ~= "" and not string.find(hay, t, 1, true) then
				return false
			end
		end
		return true
	end

	local function showOnlySearchPage(show)
		self._searchMode = show
		if show then
			-- remember the real current tab; fallback to first existing tab if none selected yet
			local fallback = nil
			for tabName in pairs(self._pages) do
				if tabName ~= "__Search" then
					fallback = tabName
					break
				end
			end
			self._lastTabBeforeSearch = self._selectedTab or self._lastTabBeforeSearch or fallback
			CurrentTabTitle.Text = "Search"
			SearchPage.Visible = true
			SearchPage.GroupTransparency = 1
			tween(SearchPage, C.SoftTween, { GroupTransparency = 0 })
			for _, p in pairs(self._pages) do
				if p.page.Visible then
					tween(p.page, C.FastTween, { GroupTransparency = 1 })
					task.delay(C.FastTween.Time, function()
						if p.page then p.page.Visible = false end
					end)
				end
			end
		else
			if SearchPage.Visible then
				tween(SearchPage, C.FastTween, { GroupTransparency = 1 })
				task.delay(C.FastTween.Time, function()
					if SearchPage then SearchPage.Visible = false end
				end)
			end
		end
	end

	local lastAppliedQuery = ""
	local function applySearchNow(q)
		q = trim(q)
		SearchPlaceholder.Visible = (q == "" and not SearchBox:IsFocused())
		ClearSearch.Visible = (q ~= "")

		if q == "" then
			lastAppliedQuery = ""
			showOnlySearchPage(false)

			local back = self._lastTabBeforeSearch or self._selectedTab
			if back and self._pages[back] then
				self:_setTab(back, true)
			else
				-- fallback to any existing tab
				for tabName in pairs(self._pages) do
					if tabName ~= "__Search" then
						self:_setTab(tabName, true)
						break
					end
				end
			end
			return
		end

		if q == lastAppliedQuery then return end
		lastAppliedQuery = q

		local tokens = {}
		for w in toLower(q):gmatch("%S+") do
			table.insert(tokens, w)
		end

		showOnlySearchPage(true)
		clearSearchResults()

		local headerOuter, _, headerSafe = makeCard(SearchScroll, 56, "search results")
		local header = mk("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.10),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = "Results for: " .. q,
			ZIndex = 180,
		})
		header.Parent = headerSafe

		local results = 0
		for _, entry in ipairs(self._searchIndex) do
			if results >= C.SearchMaxResults then break end
			if entry and entry.key and entry.tab and entry.node and entry.node.Parent then
				if matchAllTokens(entry.key, tokens) then
					results += 1
					local tabName = entry.tab
					local keyText = entry.key
					makeButton(SearchScroll, keyText, tabName, function()
						SearchBox.Text = ""
						showOnlySearchPage(false)
						self:_setTab(tabName, false)
						task.delay(0.06, function()
							local pageObj = self._pages[tabName]
							if not pageObj then return end
							local scroll = pageObj.scroll
							if not (scroll and entry.node and entry.node.Parent) then return end
							local y = (entry.node.AbsolutePosition.Y - scroll.AbsolutePosition.Y) + scroll.CanvasPosition.Y
							y = math.max(0, y - 24)
							pcall(function() scroll.CanvasPosition = Vector2.new(0, y) end)
						end)
					end, tabName)
				end
			end
		end

		if results == 0 then
			local _, _, s = makeCard(SearchScroll, 64, "no results")
			local t = mk("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.20),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = "No matches. Try different keywords.",
				ZIndex = 180,
			})
			t.Parent = s
		end
	end

	local searchDebounceToken = 0
	local function requestSearchUpdate()
		searchDebounceToken += 1
		local token = searchDebounceToken
		task.delay(C.SearchDebounce, function()
			if token ~= searchDebounceToken then return end
			applySearchNow(SearchBox.Text)
		end)
	end

	SearchBox:GetPropertyChangedSignal("Text"):Connect(requestSearchUpdate)
	SearchBox.Focused:Connect(function()
		SearchPlaceholder.Visible = (trim(SearchBox.Text) == "")
	end)
	SearchBox.FocusLost:Connect(function()
		SearchPlaceholder.Visible = (trim(SearchBox.Text) == "")
	end)
	ClearSearch.Activated:Connect(function()
		SearchBox.Text = ""
		SearchBox:ReleaseFocus()
	end)

	-- Ctrl+F focus
	self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.F then
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
				SearchBox:CaptureFocus()
			end
		end
	end))

	--==========================================================
	-- Hook minimize + keybinds
	--==========================================================
	BtnMin.Activated:Connect(function() self:Toggle() end)

	self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == C.KeybindPrimary or input.KeyCode == C.KeybindSecondary then
			self:Toggle()
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			if Modal.Visible then self:_showModal(false) end
			if SearchBox:IsFocused() and SearchBox.Text ~= "" then
				SearchBox.Text = ""
				SearchBox:ReleaseFocus()
			end
		end
	end))

	--==========================================================
	-- Drag spring
	--==========================================================
	self:_centerWindow()
	local pos = Vector2.new(self.Root.Position.X.Offset, self.Root.Position.Y.Offset)
	local vel = Vector2.new(0, 0)
	local target = pos
	local dragging = false
	local dragStartMouse = Vector2.new(0, 0)
	local dragStartTarget = Vector2.new(0, 0)

	DragHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not self.State.dragLocked then
			dragging = true
			dragStartMouse = UserInputService:GetMouseLocation()
			dragStartTarget = target
		end
	end)
	self._maid:Give(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	--==========================================================
	-- Render loop (sheen + toasts + drag + constellation)
	--==========================================================
	local lastLinesUpdate = 0
	local fpsSmoother = 0

	local function setLineGeometry(line, a, b)
		if not line then return end
		local diff = b - a
		local dist = diff.Magnitude
		if dist < 2 then
			line.Visible = false
			return
		end
		local mid = (a + b) * 0.5
		local rot = math.deg(math.atan2(diff.Y, diff.X))
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromOffset(mid.X, mid.Y)
		line.Rotation = rot
		line.Size = UDim2.new(0, dist, 0, 1)
	end

	self._maid:Give(RunService.RenderStepped:Connect(function(dt)
		-- fps
		local fps = 1 / math.max(dt, 1/240)
		fpsSmoother = fpsSmoother + (fps - fpsSmoother) * 0.08
		StatsText.Text = string.format("fps: %d", math.floor(fpsSmoother + 0.5))

		-- sheen
		if not self.State.reduceFX then
			for _, g in ipairs(ShimmerGradients) do
				if g and g.Parent then
					local ox = g.Offset.X + dt * C.SheenSpeed
					if ox > 1.0 then ox = -1.0 end
					g.Offset = Vector2.new(ox, 0)
				end
			end
			for _, g in ipairs(AccentShimmers) do
				if g and g.Parent then
					local ox = g.Offset.X + dt * C.AccentSheenSpeed
					if ox > 1.0 then ox = -1.0 end
					g.Offset = Vector2.new(ox, 0)
				end
			end
		end

		-- tab indicator shimmer
		do
			local oy = TabIndicatorGrad.Offset.Y + dt * 0.10
			if oy > 1.0 then oy = -1.0 end
			TabIndicatorGrad.Offset = Vector2.new(0, oy)
		end

		-- toast progress
		for i = #toasts, 1, -1 do
			local t = toasts[i]
			if t.card and t.card.Parent then
				local elapsed = os.clock() - t.created
				local remain = math.max(0, t.duration - elapsed)
				t.timeLabel.Text = string.format("%.1fs", remain)
				local ratio = (t.duration <= 0) and 0 or (remain / t.duration)
				t.barFill.Size = UDim2.new(ratio, 0, 1, 0)
			end
		end

		-- drag target
		if dragging and self._isOpen then
			local mouse = UserInputService:GetMouseLocation()
			local delta = mouse - dragStartMouse
			target = (dragStartTarget + delta)
		end

		-- spring integrate
		do
			local freq = C.DragFrequency
			local damping = C.DragDamping
			local w = freq * 2 * math.pi
			local x = target - pos
			vel = vel + (x * (w * w) * dt)
			vel = vel * math.exp(-damping * w * dt)
			pos = pos + vel * dt
			Root.Position = UDim2.fromOffset(pos.X, pos.Y)
		end

		if not ScreenGui.Enabled then return end
		if self.State.reduceFX then return end

		-- stars drift
		local vs = getViewport()
		for _, s in ipairs(stars) do
			local px = s.pos.X * vs.X
			local py = s.pos.Y * vs.Y
			px += s.vel.X * dt
			py += s.vel.Y * dt
			local margin = 24
			if px < margin then px = margin; s.vel = Vector2.new(math.abs(s.vel.X), s.vel.Y) end
			if py < margin then py = margin; s.vel = Vector2.new(s.vel.X, math.abs(s.vel.Y)) end
			if px > (vs.X - margin) then px = vs.X - margin; s.vel = Vector2.new(-math.abs(s.vel.X), s.vel.Y) end
			if py > (vs.Y - margin) then py = vs.Y - margin; s.vel = Vector2.new(s.vel.X, -math.abs(s.vel.Y)) end
			s.pos = Vector2.new(px / vs.X, py / vs.Y)
			s.dot.Position = UDim2.fromScale(s.pos.X, s.pos.Y)
			s.glow.Position = s.dot.Position
		end

		-- update lines
		lastLinesUpdate += dt
		if lastLinesUpdate >= C.LinesUpdateRate then
			lastLinesUpdate = 0
			local constAbs = Constellation.AbsolutePosition
			local points = table.create(#stars)
			for i, s in ipairs(stars) do
				local ap = s.dot.AbsolutePosition
				local asz = s.dot.AbsoluteSize
				points[i] = Vector2.new((ap.X - constAbs.X) + asz.X * 0.5, (ap.Y - constAbs.Y) + asz.Y * 0.5)
			end

			local edges = {}
			local edgeSet = {}
			for i = 1, #points do
				local best1, best2 = nil, nil
				local d1, d2 = 1e9, 1e9
				for j = 1, #points do
					if i ~= j then
						local d = (points[i] - points[j]).Magnitude
						if d < d1 then
							d2, best2 = d1, best1
							d1, best1 = d, j
						elseif d < d2 then
							d2, best2 = d, j
						end
					end
				end
				local function addEdge(j, dist)
					if not j then return end
					if dist > C.ConnectDistance then return end
					local a, b = i, j
					if a > b then a, b = b, a end
					local key = tostring(a) .. ":" .. tostring(b)
					if not edgeSet[key] then
						edgeSet[key] = true
						table.insert(edges, { a = a, b = b, dist = dist })
					end
				end
				addEdge(best1, d1)
				addEdge(best2, d2)
			end

			table.sort(edges, function(e1, e2) return e1.dist < e2.dist end)

			for idx = 1, #lines do
				local ln = lines[idx]
				local e = edges[idx]
				if e then
					local alpha = 1 - clamp01(e.dist / C.ConnectDistance)
					ln.target = alpha
					setLineGeometry(ln.line, points[e.a], points[e.b])
				else
					ln.target = 0
				end
			end
		end

		-- smooth line fade
		for _, ln in ipairs(lines) do
			ln.alpha = ln.alpha + (ln.target - ln.alpha) * (1 - math.pow(0.001, dt)) * 0.20
			ln.alpha = math.clamp(ln.alpha, 0, 1)
			if ln.alpha > 0.02 then
				ln.line.Visible = true
				local tr = 0.97 - (ln.alpha * 0.55)
				ln.line.BackgroundTransparency = math.clamp(tr, 0.30, 0.97)
			else
				ln.line.Visible = false
				ln.line.BackgroundTransparency = 1
			end
		end
	end))

	--==========================================================
	-- Start open + hello toast
	--==========================================================
    if C.AutoOpen ~= false then
        self:Open()
    end
    if C.AutoHelloToast ~= false then
        self:Toast(tostring(C.Name), greeting, THEME.ACCENT, 2.6)
    end
end

--==============================================================
-- Tab creation (internal)
--==============================================================
function SignatureUI:_createTab(name, icon, order, TabsStack, makePage, makeButton, makeToggle, makeSlider, makeDropdown, makeColorPicker)
	local C = self.Config
	local THEME = self.Theme
	local PALETTE = self.Palette
	local shimmerGradients = self._shimmer
	local accentShimmers = self._accentShimmer

	order = order or (#self._tabs + 1)

	local function setStrokeActive(stroke, active)
		if not stroke then return end
		local g = stroke:FindFirstChildOfClass("UIGradient")
		if active then
			if not g then
				local grad = attachAccentStrokeGradient(stroke, THEME, accentShimmers)
				grad.Offset = Vector2.new(0, 0)
			end
		else
			if g then g:Destroy() end
		end
	end

	local outer = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		LayoutOrder = order,
		ZIndex = 170,
	})
	addPadding(outer, 2, 2, 2, 2)
	outer.Parent = TabsStack

	local panel, _, _, safe = makeLunarPanel(outer, {
		Name = "TabPanel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 171,
		Corner = 12,
		BaseColor = PALETTE.Glass2,
		BaseTransparency = 0.12,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.70,
		InnerStrokeTransparency = 0.90,
		Glow = false,
		SafePadding = 12,
	}, THEME, PALETTE, shimmerGradients)

	local rail = mk("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.new(0, 2, 0, 22),
		BackgroundColor3 = THEME.STROKE,
		BackgroundTransparency = 0.80,
		BorderSizePixel = 0,
		ZIndex = 175,
	})
	rail.Parent = panel
	addCornerRound(rail)

	local btn = mk("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 9999,
	})
	btn.Parent = panel

	local iconLabel = mk("TextLabel", {
		Name = "Icon",
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 26, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.10),
		Text = icon or "•",
		ZIndex = 181,
	})
	iconLabel.Parent = safe

	local nameLabel = mk("TextLabel", {
		Name = "Name",
		Position = UDim2.new(0, 30, 0, 0),
		Size = UDim2.new(1, -30, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = THEME.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = name,
		ZIndex = 181,
	})
	nameLabel.Parent = safe

	local stroke = panel:FindFirstChildOfClass("UIStroke")

	local function setActive(active, instant)
		local targetBg = active and 0.06 or 0.12
		local targetStrokeTr = active and 0.40 or 0.70
		local targetRailTr = active and 0.20 or 0.80
		local targetIcon = active and THEME.ACCENT_3 or lerpColor(THEME.MUTED, THEME.SOFT, 0.10)

		setStrokeActive(stroke, active)

		if instant then
			panel.BackgroundTransparency = targetBg
			if stroke then stroke.Transparency = targetStrokeTr end
			rail.BackgroundTransparency = targetRailTr
			iconLabel.TextColor3 = targetIcon
		else
			tween(panel, C.FastTween, { BackgroundTransparency = targetBg })
			if stroke then tween(stroke, C.FastTween, { Transparency = targetStrokeTr }) end
			tween(rail, C.FastTween, { BackgroundTransparency = targetRailTr })
			tween(iconLabel, C.FastTween, { TextColor3 = targetIcon })
		end
	end

	btn.MouseEnter:Connect(function()
		if name ~= self._selectedTab then
			tween(panel, C.FastTween, { BackgroundTransparency = 0.09 })
			if stroke then
				attachAccentStrokeGradient(stroke, THEME, accentShimmers)
				tween(stroke, C.FastTween, { Transparency = 0.52 })
			end
		end
	end)
	btn.MouseLeave:Connect(function()
		if name ~= self._selectedTab then
			tween(panel, C.FastTween, { BackgroundTransparency = 0.12 })
			if stroke then
				tween(stroke, C.FastTween, { Transparency = 0.70, Color = PALETTE.EdgeDark })
			end
		end
	end)

	local page, scroll = makePage(name)
	self._pages[name] = { page = page, scroll = scroll }
	self._tabButtons[name] = { outer = outer, btn = btn, setActive = setActive, nameLabel = nameLabel }

	-- Tab API
	local tabObj = setmetatable({}, Tab)
	tabObj._ui = self
	tabObj.Name = name
	tabObj.Scroll = scroll

	-- Tab methods (simple)
	function tabObj:Label(text)
		self._ui._buildTabName = self.Name
		local o, _, s = self._ui:_makeCard(self.Scroll, 38, tostring(text), true)
		local t = mk("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.10),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(text),
			ZIndex = 180,
		})
		t.Parent = s
		self._ui._buildTabName = ""
		return o
	end

	function tabObj:Paragraph(text)
		self._ui._buildTabName = self.Name
		local o, _, s = self._ui:_makeCard(self.Scroll, 100, tostring(text), true)
		local t = mk("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = lerpColor(THEME.MUTED, THEME.SOFT, 0.18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Text = tostring(text),
			ZIndex = 180,
		})
		t.Parent = s
		self._ui._buildTabName = ""
		return o
	end

	function tabObj:Divider()
		self._ui._buildTabName = self.Name
		local holder = mk("Frame", { Size = UDim2.new(1,0,0,8), BackgroundTransparency = 1 })
		holder.Parent = self.Scroll
		local line = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, -10, 0, 1),
			BackgroundColor3 = PALETTE.EdgeLite,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
		})
		line.Parent = holder
		addGradient(line, 0,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, THEME.STROKE),
				ColorSequenceKeypoint.new(0.5, THEME.ACCENT_3),
				ColorSequenceKeypoint.new(1, THEME.STROKE),
			}),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.86),
				NumberSequenceKeypoint.new(0.5, 0.72),
				NumberSequenceKeypoint.new(1, 0.86),
			})
		)
		self._ui._buildTabName = ""
		return holder
	end

	function tabObj:Section(title)
		self._ui._buildTabName = self.Name
		local o, _, s = self._ui:_makeCard(self.Scroll, 46, tostring(title), true)
		local t = mk("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = THEME.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(title),
			ZIndex = 180,
		})
		t.Parent = s
		self._ui._buildTabName = ""
		return o
	end

	function tabObj:Button(text, callback, hint)
		self._ui._buildTabName = self.Name
		local node = makeButton(self.Scroll, tostring(text), hint, callback)
		self._ui._buildTabName = ""
		return node
	end

	function tabObj:Toggle(text, default, callback)
		self._ui._buildTabName = self.Name
		local node, getFn, setFn = makeToggle(self.Scroll, tostring(text), default == true, callback)
		self._ui._buildTabName = ""
		return {
			Node = node,
			Get = getFn,
			Set = setFn,
		}
	end

	function tabObj:Slider(text, opts, callback)
		self._ui._buildTabName = self.Name
		local node, getFn, setFn = makeSlider(self.Scroll, tostring(text), opts, callback)
		self._ui._buildTabName = ""
		return {
			Node = node,
			Get = getFn,
			Set = setFn,
		}
	end

	function tabObj:Dropdown(text, items, opts, callback)
		self._ui._buildTabName = self.Name
		local node, getFn = makeDropdown(self.Scroll, tostring(text), items, opts, callback)
		self._ui._buildTabName = ""
		return {
			Node = node,
			Get = getFn,
		}
	end

	function tabObj:ColorPicker(text, defaultColor, callback)
		self._ui._buildTabName = self.Name
		local node, getFn = makeColorPicker(self.Scroll, tostring(text), defaultColor, callback)
		self._ui._buildTabName = ""
		return {
			Node = node,
			Get = getFn,
		}
	end

	self._tabs[name] = { api = tabObj }
	btn.Activated:Connect(function()
		if self._searchBox.Text ~= "" then
			self._searchBox.Text = ""
			self._searchMode = false
		end
		self:_setTab(name, false)
	end)

	-- default tab content (only for initial default tabs)
	if name == "Home" then
		self._buildTabName = "Home"
		tabObj:Button("Self-check", function()
			self:Toast("Self-check", tostring(C.Name)..": ok", THEME.SUCCESS, 2.2)
			print("["..tostring(C.Name).."] ok")
		end, "run")

		tabObj:Toggle("Performance mode", false, function(v)
			self:Toast("Performance", v and "Enabled" or "Disabled", v and THEME.SUCCESS or THEME.ACCENT, 2.3)
		end)

		tabObj:Paragraph(string.format("• %s %s\n• %s/%s — toggle UI\n• Ctrl+F — search\n",
			tostring(C.Name), tostring(C.Version),
			tostring(C.KeybindPrimary.Name), tostring(C.KeybindSecondary.Name)
		))
		self._buildTabName = ""
	elseif name == "Settings" then
		self._buildTabName = "Settings"
		tabObj:Toggle("Lock window drag", false, function(v)
			self.State.dragLocked = v
			self:Toast("Window", v and "Drag locked" or "Drag unlocked", THEME.ACCENT, 1.8)
		end)

		tabObj:Toggle("Reduce effects", false, function(v)
			self.State.reduceFX = v
			self:Toast("Effects", v and "Reduced" or "Normal", THEME.ACCENT, 1.8)
		end)

		tabObj:Button("Center window", function()
			self:Center()
			self:Toast("Window", "Centered", THEME.SUCCESS, 1.8)
		end, "position")

		tabObj:Button("Unload (confirm)", function()
			self:Confirm("Unload "..tostring(C.Name).."?", "This will fully remove the UI and disable all effects.", function()
				self:Destroy()
			end)
		end, "danger")
		self._buildTabName = ""
	end

	-- select first tab
	if not self._selectedTab then
		self:_setTab(name, true)
	end

	return tabObj
end

--==============================================================
-- Internal: makeCard helper for tab API
--==============================================================
function SignatureUI:_makeCard(parent, height, searchKey, registerIt)
	local THEME = self.Theme
	local PALETTE = self.Palette
	local shimmer = self._shimmer

	local outer = mk("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 170,
	})
	outer.Parent = parent

	local panel, _, _, safe = makeLunarPanel(outer, {
		Name = "Card",
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 170,
		Corner = 12,
		BaseColor = PALETTE.Glass2,
		BaseTransparency = 0.10,
		StrokeColor = PALETTE.EdgeDark,
		StrokeTransparency = 0.62,
		InnerStrokeTransparency = 0.86,
		Glow = false,
		SafePadding = 12,
	}, THEME, PALETTE, shimmer)

	if registerIt then
		self:_registerSearch(outer, tostring(searchKey or ""))
	end
	return outer, panel, safe
end

--==============================================================
-- Internal: tab switching + indicator
--==============================================================
function SignatureUI:_moveIndicatorTo(tabOuter, instant)
	local TabsArea = self._tabsArea
	if not (TabsArea and tabOuter) then return end
	local absY = tabOuter.AbsolutePosition.Y + tabOuter.AbsoluteSize.Y * 0.5
	local baseY = TabsArea.AbsolutePosition.Y
	local localY = absY - baseY

	self._indicatorY = self._indicatorY or 26
	local indicatorY = self._indicatorY

	local delta = math.abs(localY - indicatorY)
	local extra = math.clamp(delta * 0.11, 0, 18)

	local targetH = 22
	local stretchH = targetH + extra

	if instant then
		self._tabIndicator.Position = UDim2.new(0, 6, 0, localY)
		self._tabIndicator.Size = UDim2.new(0, 4, 0, targetH)
		self._indicatorY = localY
		return
	end

	tween(self._tabIndicator, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 4, 0, stretchH),
		Position = UDim2.new(0, 6, 0, (indicatorY + localY) * 0.5),
	})
	task.delay(0.12, function()
		if self._tabIndicator then
			tween(self._tabIndicator, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 4, 0, targetH),
				Position = UDim2.new(0, 6, 0, localY),
			})
		end
	end)

	self._indicatorY = localY
end

function SignatureUI:_setTab(name, instant)
	if not self._pages[name] then return end
	self._selectedTab = name
	if not self._searchMode then
		self._tabTitle.Text = name
	end

	for tabName, tdata in pairs(self._tabButtons) do
		tdata.setActive(tabName == name, instant)
	end
	self:_moveIndicatorTo(self._tabButtons[name].outer, instant)

	-- while in search, do not show pages
	if self._searchMode then
		for _, p in pairs(self._pages) do
			if p.page.Visible then
				if instant then
					p.page.Visible = false
				else
					tween(p.page, self.Config.FastTween, { GroupTransparency = 1 })
					task.delay(self.Config.FastTween.Time, function()
						if p.page then p.page.Visible = false end
					end)
				end
			end
		end
		return
	end

	for tabName, p in pairs(self._pages) do
		if tabName == name then
			p.page.Visible = true
			if instant then
				p.page.GroupTransparency = 0
			else
				p.page.GroupTransparency = 1
				tween(p.page, self.Config.SoftTween, { GroupTransparency = 0 })
			end
		else
			if p.page.Visible then
				if instant then
					p.page.Visible = false
				else
					tween(p.page, self.Config.FastTween, { GroupTransparency = 1 })
					task.delay(self.Config.FastTween.Time, function()
						if p.page then p.page.Visible = false end
					end)
				end
			end
		end
	end
end

--==============================================================
-- Internal: open / close with token (no desync)
--==============================================================
function SignatureUI:_openUI()
	local C = self.Config
	if self._isOpen then return end
	self._isOpen = true
	self._uiAnimToken = (self._uiAnimToken or 0) + 1
	local token = self._uiAnimToken

	self.ScreenGui.Enabled = true
	self.BackdropGroup.GroupTransparency = 1
	self.Root.GroupTransparency = 1

	tween(self.BackdropGroup, C.OpenTween, { GroupTransparency = 0 })
	tween(self.Dim, C.OpenTween, { BackgroundTransparency = 1 - C.DimAlpha })
	tween(self._blur, C.OpenTween, { Size = C.BlurSize })

	task.delay(0.10, function()
		if token ~= self._uiAnimToken then return end
		if not self._isOpen then return end
		tween(self.Root, C.OpenTween, { GroupTransparency = 0 })
	end)
end

function SignatureUI:_closeUI()
	local C = self.Config
	if not self._isOpen then return end
	self._isOpen = false
	self._uiAnimToken = (self._uiAnimToken or 0) + 1
	local token = self._uiAnimToken

	tween(self.Root, C.CloseTween, { GroupTransparency = 1 })

	task.delay(C.CloseTween.Time * 0.85, function()
		if token ~= self._uiAnimToken then return end
		if self._isOpen then return end

		tween(self.BackdropGroup, C.CloseTween, { GroupTransparency = 1 })
		tween(self.Dim, C.CloseTween, { BackgroundTransparency = 1 })
		tween(self._blur, C.CloseTween, { Size = 0 })

		task.delay(C.CloseTween.Time + 0.04, function()
			if token ~= self._uiAnimToken then return end
			if not self._isOpen then
				self.ScreenGui.Enabled = false
			end
		end)
	end)
end

function SignatureUI:_centerWindow()
	local vs = self._getViewport and self:_getViewport() or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920,1080)
	local x = math.floor((vs.X - self.Root.AbsoluteSize.X) * 0.5)
	local y = math.floor((vs.Y - self.Root.AbsoluteSize.Y) * 0.5)
	self.Root.Position = UDim2.fromOffset(x, y)
end

--==============================================================
-- Internal: unload
--==============================================================
function SignatureUI:_unload()
	self._maid:Cleanup()

	pcall(function()
		if self._createdBlur then
			local b = Lighting:FindFirstChild(self._blurName)
			if b then b:Destroy() end
		else
			local b = Lighting:FindFirstChild(self._blurName)
			if b then b.Size = 0 end
		end
	end)

	pcall(function()
		if self.ScreenGui then self.ScreenGui:Destroy() end
	end)

	pcall(function()
		if self.ToastGui then self.ToastGui:Destroy() end
	end)

	pcall(function()
		if self._soundHost then self._soundHost:Destroy() end
	end)
end

return SignatureUI
