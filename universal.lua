--// start esp
if getgenv().Destroy then Destroy() end
local startTime = tick()
local unloaded, window = false

local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local mouse = localPlayer:GetMouse()

local runService = game:GetService("RunService")

local camera = game:GetService("Workspace").CurrentCamera
local viewportSize = camera.ViewportSize

local highlightFolder = Instance.new("Folder"); highlightFolder.Name = syn.crypto.random(math.random(12, 16)); highlightFolder.Parent = gethui()

local textFont, fontSize = nil, 13; do
	if not isfolder("x_up/fonts") then
		makefolder("x_up/fonts")
	end
	local function getFont(fontName)
		local filePath, font = "x_up/fonts/"..fontName..".otf", nil
		if not isfile(filePath) then
			font = game:HttpGet("http://phantomgui.xyz/dev/espfonts/"..fontName..".otf")
			writefile(filePath, font)
		else
			font = readfile(filePath)
		end
		return font
	end

	textFont = DrawFont.Register(getFont("Montserrat-Medium"), {
		Scale = false;
		Bold = false;
		UseStb = false;
		PixelSize = fontSize
	})
end

local defaultProperties = {
	Box = {
		Thickness = 2;
		Color = Color3.new(1,1,1); 
		Outlined = true;
		Rounding = 4;
		Visible = false;
	};
	Text = {
		Size = fontSize;
		Color = Color3.new(1, 1, 1);
		Visible = false;
		YAlignment = YAlignment.Bottom;
		Font = textFont;
	};
	Highlight = {
		Enabled = false;
		FillColor = Color3.new(1,1,1);
		OutlineColor = Color3.new();
		OutlineTransparency = 0.5;
		FillTransparency = 0.25;
	};
	Line = {
		Thickness = 2;
		Visible = false;
		Color = Color3.new(1,1,1);
		Outlined = false;
	}
}

local playerList, connects, colors, games, espSettings, aimbotSettings = {}, {}, {
	HealthMax = Color3.new(0, 1, 0);
	HealthMin = Color3.new(1, 0, 0);
	White = Color3.new(1,1,1)
}, {
	Rogue = game.GameId == 1087859240;
	FightingGame = game.GameId == 1277659167;
	Deepwoken = game.GameId == 1359573625;
	PF = game.GameId == 113491250;
	BB = game.GameId == 1168263273;
}, {
	Enabled = true;
	TeamColor = true;
	Chams = false;
	Tracers = false;
	Skeleton = true;
	Boxes = false;

	TransparencyRolloff = 350;
	MouseDistanceRolloff = 150;
},
{
	Enabled = false;
	TargetAll = false;
	TeamCheck = true;
	
	Smoothing = 1;
}
getgenv().Destroy = function()
	espSettings.Enabled = false;
	runService:UnbindFromRenderStep("x_upESP")

	for _,v in connects do v:Disconnect() end table.clear(connects) connects = nil
	for _,v in playerList do v:Destroy() end table.clear(playerList) playerList = nil

	highlightFolder:Destroy()

	getgenv().Destroy = nil

	if games.PF then
		actorEvent:Fire(nil, "Destroy")
	end

	if window then window:Remove() end
	unloaded = true
end

local function onScreen(vec2) return vec2.X > 0 and vec2.X < viewportSize.X and vec2.Y > 0 and vec2.Y < viewportSize.Y end
local function wts(part)
	local screenPoint = worldtoscreen({part.Position})[1]
	return screenPoint, onScreen(screenPoint)
end

local function getClosestPlayer(mindis)
	local closestDistance, closestPlayer = mindis or 9e9, nil

   	for i,v in playerList do
		if v.Player and v.RootPart then
			local screenPos, vis = wts(v.RootPart)
			local distanceFromMouse = (Vector2.new(mouse.X, mouse.Y + 36) - Vector2.new(screenPos.X, screenPos.Y + 36)).Magnitude
			if distanceFromMouse <= closestDistance and vis then
				closestPlayer = v
				closestDistance = Vec2Distance
			end
		end
	end
	
	return closestPlayer
end

local actor, actorEvent; if games.PF then
	for i,v in getactors() do if v.Name == "lol" then actor = v break end end; if not actor then return end
	actorEvent = getluastate(actor).Event
end

if games.PF and not actor then return error("no actor, pf no workie :(") end

local pfPlayers = {}
if games.PF then do
	connects["pfActorEvent"] = actorEvent:Connect(function(plr, event, char, health)
		local first = false; if not pfPlayers[plr.Name] then first = true pfPlayers[plr.Name] = {Character = nil, Health = nil} end
		if event == "inGame" then
			if health then 
				pfPlayers[plr.Name].Health = health 
			end
			if char then 
				pfPlayers[plr.Name].Character = char
			end
		elseif event == "leftGame" then
			pfPlayers[plr.Name] = nil
		end
	end)
	
	do
		syn.run_on_actor(actor, [[
			local connects = {}

			local req = getrenv().shared.require
			local playerStatusEvents = req("PlayerStatusEvents")
			local repInterface = req("ReplicationInterface")
			local repEvents = req("ReplicationEvents")

			local actorEvent = getluastate(actor).Event
			local function getCharacterModel(plr)
				local plrEntry = repInterface.getEntry(plr)
				if not plrEntry then return end
				return (plrEntry:isAlive() and plrEntry:getThirdPersonObject():getCharacterModel().Name ~= "Dead") and plrEntry:getThirdPersonObject():getCharacterModel()
			end

			local function getPlayerHealth(plr)
				local plrEntry = repInterface.getEntry(plr)
				if not plrEntry then return end
				return plrEntry:isAlive() and plrEntry:getHealth() or nil
			end

			connects["pfActorEvent"] = actorEvent:Connect(function(plr, ret)
				local plrEntry = repInterface.getEntry(plr)
				if ret == "Health" then
					actorEvent:Fire(plr, "inGame", nil, getPlayerHealth(plr))
				elseif ret == "Character" then
					actorEvent:Fire(plr, "inGame", getCharacterModel(plr), nil)
				elseif ret == "Destroy" then
					for i,v in connects do v:Disconnect() end table.clear(connects) connects = nil
				end
			end)

			connects["pfPlayerSpawned"] = playerStatusEvents.onPlayerSpawned:Connect(function(plr)
				actorEvent:Fire(plr, "inGame", getCharacterModel(plr), getPlayerHealth(plr))
			end)

			connects["pfPlayerDied"] = playerStatusEvents.onPlayerDied:Connect(function(plr)
				actorEvent:Fire(plr, "inGame", nil, nil)
			end)

			connects["pfPlayerDied"] = repEvents.onEntryRemoved:Connect(function(plr)
				actorEvent:Fire(plr, "leftGame")
			end)

			repInterface.operateOnAllEntries(function(plr, plrEntry) 
				if plrEntry:isAlive() then
					actorEvent:Fire(plr, "inGame", getCharacterModel(plr), getPlayerHealth(plr))
				else
					actorEvent:Fire(plr, "inGame", nil, nil)
				end
			end)
		]])
	end

	for i,v in players:GetPlayers() do if v == Player then continue end actorEvent:Fire(v, "Character") end
end end


local bbFuncs = { ["characterAdded"] = nil; ["characterRemoving"] = nil; ["getCharacter"] = nil; ["getTeam"] = nil; }
if games.BB then
	local TS = require(game:GetService("ReplicatedStorage").TS) if typeof(TS) == "function" then TS = debug.getupvalue(TS, 2) end
	TS = getupvalue(getrawmetatable(TS).__index, 1); if typeof(TS) ~= "table" then return error"TS not table" end

	local getCharacterFunc = rawget(rawget(TS, "Characters"), "GetCharacter"); if not getCharacterFunc then return error"GetCharacter not found" end
	local playerTable = debug.getupvalue(getCharacterFunc, 1); if not playerTable then return error"playerTable not found" end

	local function getCharacter(player)
		local char = playerTable[player]; if not char then return end
		return char
	end

	local function getTeam(player)
		for i,v in game:GetService("Teams"):GetChildren() do
			if not v.Players:FindFirstChild(player.Name) then continue end
			return v;
		end
	end

	bbFuncs.characterAdded = TS.Characters.CharacterAdded
	bbFuncs.characterRemoving = TS.Damage.CharacterKilled
	bbFuncs.getTeam = getTeam
	bbFuncs.getCharacter = getCharacter
end

local Player = {}; do
	Player.__index = Player

	function Player.new(player)
		if player == localPlayer then return end

		local self = {}; setmetatable(self, Player)

		self.Player = player
		self.Character = self:GetCharacter()
		self.Humanoid = nil
		self.RigType = nil
		self.RootPart = nil
		self.HPP = nil
		self.Health = nil
		self.MaxHealth = nil
		self.Distance = 0
		self.DistanceFromMouse = 9e9
		self.Name = player.Name
		self.Team = self:GetTeam()
		self.Highlight = Instance.new("Highlight", highlightFolder)
		self.Drawings = {}
		self.SkeletonDrawings = {}
		self.Connects = {}
		self.Points = {}

		if games.PF then
			self.Connects["CharacterUpdate"] = actorEvent:Connect(function(plr, event, char, health)
				if player ~= plr then return end
				if char ~= nil then
					self.Character = char
					self:SetupCharacter(self.Character)
				elseif char and char.Parent ~= nil then
					for i,v in {"Character", "RootPart", "Humanoid"} do self[v] = nil end
				end
			end)
		elseif games.BB then
			self.Connects["CharacterAdded"] = bbFuncs.characterAdded:Connect(function(plr, char) if plr == player then self:SetupCharacter(char) end end)

			self.Connects["CharacterRemoving"] = bbFuncs.characterRemoving:Connect(function(character, _, plr)
				if plr == player then
					for i,v in {"Character", "RootPart", "Humanoid"} do self[v] = nil end
				end
			end)
		else
			self.Connects["CharacterAdded"] = player.CharacterAdded:Connect(function(char) self:SetupCharacter(player.Character) end)
			self.Connects["CharacterRemoving"] = player.CharacterRemoving:Connect(function() 
				for i,v in {"Character", "RootPart", "Humanoid"} do
					self[v] = nil
				end
			end)
		end
		self.Connects["TeamChanged"] = player:GetPropertyChangedSignal("Team"):Connect(function()
			self.Team = player.Team ~= nil and player.Team.Name or nil
		end)

		self:SetupCharacter(self.Character)

		playerList[self.Name] = self

		return self
	end

	function Player:GetCharacter()
		if games.PF and pfPlayers[self.Player.Name] then
			return pfPlayers[self.Player.Name].Character
		elseif games.BB then
			return bbFuncs.getCharacter(self.Player)
		else
			return self.Player.Character
		end
	end

	function Player:GetRootPart()
		if self.Character then
			if games.PF then
				return self.Character:WaitForChild("Torso", 3)
			elseif games.BB then
				return self.Character:WaitForChild("Root", 3)
			else
				return self.Character:WaitForChild("HumanoidRootPart", 3) 
			end
		end
		return nil
	end

	function Player:GetHealth()
		if games.PF then
			local hp = pfPlayers[self.Name] and pfPlayers[self.Name].Health or 0
			return math.floor(hp + 0.5), 100
		elseif games.BB then
			local hp = self.Character and self.Character:WaitForChild("Health", 1); if not hp then return 100,100 end
			local maxHP = hp:FindFirstChild("MaxHealth"); if not maxHP then return 100,100 end
			return math.floor(hp.Value + 0.5), math.floor(maxHP.Value + 0.5)
		elseif self.Humanoid then
			return self.Humanoid.Health, self.Humanoid.MaxHealth
		end
		return 100,100
	end

	function Player:GetTeam()
		if games.BB then
			return bbFuncs.getTeam(self.Player)
		end
		return self.Player.Team ~= nil and self.Player.Team.Name or nil
	end

	function Player:GetHeldTool()
		if self.Character then
			local t = game.FindFirstChildOfClass(self.Character, "Tool")
			return t and t.Name or "N/A"
		end
		return ""
	end

	function Player:UpdateHealth()
		local Health, MaxHealth = self:GetHealth()

		self.HPP = Health / MaxHealth
		
		self.Points.TopLeftHealth.Point.Offset = CFrame.new(-2, (self.HPP * 5.5) - 3, 0)

		self.Drawings.HealthBar.Color = colors.HealthMax:Lerp(colors.HealthMin, math.clamp(1 - self.HPP, 0, 1)) --// thx ic3 
	end

	function Player:UpdateTracerLine()
		self.Drawings.Line.Visible = false
		self.Drawings.Line = LineDynamic.new(Point2D.new(viewportSize.X / 2, viewportSize.Y), self.Points.RootPart); for i,v in defaultProperties.Line do self.Drawings.Line[i] = v end
		self.Drawings.Line.ZIndex = 0
	end

	function Player:SetupCharacter(Character)
		if Character then
			self.Character = Character
			self.RootPart = self:GetRootPart()

			local health, maxHealth = self:GetHealth()
			self.Health = health
			self.MaxHealth = maxHealth
			if not games.PF and not games.BB then
				self.Humanoid = Character:WaitForChild("Humanoid", 5)
			end
			if self.Humanoid then
				self.RigType = self.Humanoid.RigType
			elseif games.PF then
				self.RigType = Enum.HumanoidRigType.R6
			end
			self.HPP = self.Health / self.MaxHealth
			self.Highlight.Adornee = self.Character

			if workspace.StreamingEnabled and self.Character and not self.RootPart then
				self.Connects["ChildAdded"] = self.Character.ChildAdded:Connect(function(part)
					if part.Name == "HumanoidRootPart" and part:WaitForChild("RootRigAttachment", 3) then
						self.RootPart = part
						self:SetupESP()
					end
				end)
			end

			if self.RootPart then
				self:SetupESP()
			end
		end
	end

	function Player:SetupESP()
		--// create points
		local rootPartPoint = PointInstance.new(self.RootPart)

		local topLeftBoxPoint = PointInstance.new(self.RootPart, CFrame.new(-2, 2.5, 0))
		local bottomLeftBoxPoint = PointInstance.new(self.RootPart, CFrame.new(-2, -3, 0))
		local bottomRightBoxPoint = PointInstance.new(self.RootPart, CFrame.new(2, -3, 0))
		
		local middleHealthPoint = PointInstance.new(self.RootPart, CFrame.new(-2, 2.5, 0))
		local topLeftHealthPoint = PointOffset.new(PointInstance.new(self.RootPart, CFrame.new(-2, 2.5, 0)), -4, 0)
		local bottomRightHealthPoint = PointOffset.new(bottomLeftBoxPoint, -3, 0)

		local textPoint = PointInstance.new(self.RootPart, CFrame.new(0, -3, 0))
		
		if self.Humanoid then
			if self.RigType == Enum.HumanoidRigType.R15 then
				for i, part in self.Character:GetChildren() do
					local limb = part and self.Humanoid:GetLimb(part)
					if limb and limb ~= Enum.Limb.Unknown then
						local motor6D = game.FindFirstChildOfClass(part, "Motor6D")
						if motor6D and motor6D.Part0 and motor6D.Part1 and motor6D.Part0 ~= self.RootPart then
							self.Points[part.Name.."1"] = PointInstance.new(motor6D.Part0)
							self.Points[part.Name.."2"] = PointInstance.new(motor6D.Part1)

							local skeletonLine = LineDynamic.new(self.Points[part.Name.."1"], self.Points[part.Name.."2"])
							skeletonLine.Thickness = 2
							skeletonLine.Outlined = true
							skeletonLine.Visible = false
							
							self.SkeletonDrawings[part.Name] = skeletonLine
						end
					end
				end
			elseif self.RigType == Enum.HumanoidRigType.R6 then
				local limbs = {"Left Arm", "Right Arm", "Left Leg", "Right Leg"}
				for i,v in self.Character:GetChildren() do
					if v:IsA("Part") and game.FindFirstChildOfClass(v, "Attachment") and table.find(limbs, v.Name) then
						local limbName = v.Name:gsub(" ", "")
						
						local point1, point2 = PointInstance.new(v, CFrame.new(0, 0.75, 0)), PointInstance.new(v, CFrame.new(0, -0.75, 0)); point1.RotationType = CFrameRotationType.TargetRelative; point2.RotationType = CFrameRotationType.TargetRelative
						local skeletonLine = LineDynamic.new(point1, point2) skeletonLine.Thickness = 2 skeletonLine.Color = Color3.new(1,1,1) skeletonLine.Outlined = true

						self.Points[limbName.."Top"] = point1
						self.Points[limbName.."Bottom"] = point2
						self.SkeletonDrawings[limbName] = skeletonLine
					end
				end
				local headPoint, topTorsoPoint, bottomTorsoPoint = PointInstance.new(self.Character.Head), PointInstance.new(self.Character.Torso, CFrame.new(0, 0.75, 0)), PointInstance.new(self.Character.Torso, CFrame.new(0, -0.75, 0))
				for i,v in {headPoint, topTorsoPoint, bottomTorsoPoint} do v.RotationType = CFrameRotationType.TargetRelative end

				local headtoTorso = LineDynamic.new(headPoint, topTorsoPoint) headtoTorso.Thickness = 2 headtoTorso.Color = Color3.new(1,1,1); self.SkeletonDrawings["headtoTorso"] = headtoTorso
				local torsotoLeftArm = LineDynamic.new(topTorsoPoint, self.Points["LeftArmTop"]) torsotoLeftArm.Thickness = 2 torsotoLeftArm.Color = Color3.new(1,1,1); self.SkeletonDrawings["torsotoLeftArm"] = torsotoLeftArm
				local torsotoRightArm = LineDynamic.new(topTorsoPoint, self.Points["RightArmTop"]) torsotoRightArm.Thickness = 2 torsotoRightArm.Color = Color3.new(1,1,1); self.SkeletonDrawings["torsotoRightArm"] = torsotoRightArm
				local torsotoLeftLeg = LineDynamic.new(bottomTorsoPoint, self.Points["LeftLegTop"]) torsotoLeftLeg.Thickness = 2 torsotoLeftLeg.Color = Color3.new(1,1,1); self.SkeletonDrawings["torsotoLeftLeg"] = torsotoLeftLeg
				local torsotoRightLeg = LineDynamic.new(bottomTorsoPoint, self.Points["RightLegTop"]) torsotoRightLeg.Thickness = 2 torsotoRightLeg.Color = Color3.new(1,1,1); self.SkeletonDrawings["torsotoRightLeg"] = torsotoRightLeg
				local torsoLine = LineDynamic.new(topTorsoPoint, bottomTorsoPoint) torsoLine.Thickness = 2 torsoLine.Color = Color3.new(1,1,1); self.SkeletonDrawings["torsoLine"] = torsoLine
				for i,v in {headtoTorso, torsotoLeftArm, torsotoRightArm, torsotoLeftLeg, torsotoRightLeg, torsoLine} do v.Outlined = true end
			end
		elseif games.BB then
			for i, part in self.Character.Body:GetChildren() do
				local motor6D = game.FindFirstChildOfClass(part, "Motor6D")
				if motor6D and motor6D.Part0 and motor6D.Part1 and motor6D.Part0 ~= self.RootPart then
					self.Points[part.Name.."1"] = PointInstance.new(motor6D.Part0)
					self.Points[part.Name.."2"] = PointInstance.new(motor6D.Part1)

					local skeletonLine = LineDynamic.new(self.Points[part.Name.."1"], self.Points[part.Name.."2"])
					skeletonLine.Thickness = 2
					skeletonLine.Outlined = true
					skeletonLine.Visible = false
					
					self.SkeletonDrawings[part.Name] = skeletonLine
				end
			end
		end

		for i,v in defaultProperties.Highlight do self.Highlight[i] = v end
		
		--// create drawings
		local PrimaryBox = RectDynamic.new(topLeftBoxPoint, bottomRightBoxPoint); for i,v in defaultProperties.Box do PrimaryBox[i] = v end
		PrimaryBox.ZIndex = 3

		local PrimaryText = TextDynamic.new(textPoint); for i,v in defaultProperties.Text do PrimaryText[i] = v end
		PrimaryText.Text = self.Name
		PrimaryText.ZIndex = 2

		local TextShadow = TextDynamic.new(PointOffset.new(textPoint, 1, 1)); for i,v in defaultProperties.Text do TextShadow[i] = v end
		TextShadow.Text = self.Name
		TextShadow.Color = Color3.new()
		TextShadow.ZIndex = 1
		
		local HealthBox = RectDynamic.new(topLeftHealthPoint, bottomRightHealthPoint); for i,v in defaultProperties.Box do HealthBox[i] = v end
		HealthBox.Filled = true
		HealthBox.Color = colors.HealthMax
		HealthBox.Rounding = 0
		HealthBox.ZIndex = 3

		local TracerLine = LineDynamic.new(Point2D.new(viewportSize.X / 2, viewportSize.Y), rootPartPoint); for i,v in defaultProperties.Line do TracerLine[i] = v end
		TracerLine.ZIndex = 0

		--// add to table for updates
		self.Drawings.Box = PrimaryBox
		self.Drawings.Text = PrimaryText
		self.Drawings.TextShadow = TextShadow
		self.Drawings.HealthBar = HealthBox
		self.Drawings.Line = TracerLine

		self.Points.TopLeftBox = topLeftBoxPoint
		self.Points.BottomLeftBox = bottomLeftBoxPoint
		self.Points.BottomRightBox = bottomRightBoxPoint

		self.Points.MiddleHealth = middleHealthPoint 
		self.Points.TopLeftHealth = topLeftHealthPoint
		self.Points.BottomRightHealth = bottomRightHealthPoint

		self.Points.RootPart = rootPartPoint

		self:UpdateHealth()
		if self.Humanoid then
			self.Connects["HealthChanged"] = self.Humanoid.HealthChanged:Connect(function()
				local Health, MaxHealth = self:GetHealth()
				self.Health = Health
				self.MaxHealth = MaxHealth
				self:UpdateHealth()
			end)
		elseif games.BB then
			self.Connects["HealthChanged"] = self.Character.Health:GetPropertyChangedSignal("Value"):Connect(function()
				local Health, MaxHealth = self:GetHealth()
				self.Health = Health
				self.MaxHealth = MaxHealth
				self:UpdateHealth()
			end)
		end
	end

	function Player:Update()
		if not self.Player then self:Destroy() return end
		local Box = self.Drawings.Box
		local Text, TextShadow = self.Drawings.Text, self.Drawings.TextShadow
		local HealthBar = self.Drawings.HealthBar
		local Line = self.Drawings.Line
		local SkeletonDrawings = self.SkeletonDrawings

		if not Box or not Text or not Line or not self.Character or not self.RootPart then return end

		for i,v in {Text, HealthBar, TextShadow} do v.Visible = espSettings.Enabled end 
		for i,v in SkeletonDrawings do v.Visible = espSettings.Enabled and espSettings.Skeleton end
		Box.Visible = espSettings.Enabled and espSettings.Boxes
		Line.Visible = espSettings.Enabled and espSettings.Tracers
		self.Highlight.Enabled = espSettings.Enabled and espSettings.Chams

		--// set vars
		local Health, MaxHealth = self:GetHealth()

		--// var updates
		if games.PF then
			self:UpdateHealth()
		end

		self.Health = Health
		self.MaxHealth = MaxHealth

		if not self.RootPart then
			self.RootPart = self:GetRootPart()
			if not self.RootPart then for i,v in {"Character", "RootPart", "Humanoid"} do self[v] = nil end return end
		end
		self.Distance = (self.RootPart.Position - camera.CFrame.Position).Magnitude

		--// get display name | todo: function for getting display name to support other games easier?
		local InGameName;
		if games.Deepwoken and self.Humanoid and self.Humanoid.DisplayName then 
			local displayName = self.Humanoid.DisplayName:split("\n")[1]
			InGameName = displayName
		end

		--// update text
		local newText = self.Name..((games.Deepwoken and InGameName) and " ["..InGameName.."]" or "").."\n["..math.floor((camera.CFrame.p - self.RootPart.Position).Magnitude).."] ["..math.floor(self.Health).."/"..math.floor(self.MaxHealth).."]\n["..self:GetHeldTool().."]"
		Text.Text = newText
		TextShadow.Text = newText

		--// update box transparency
		local newOpacity = math.clamp(1 - self.Distance / espSettings.TransparencyRolloff, 0.2, 1)

		self.DistanceFromMouse = (Vector2.new(mouse.X, mouse.Y + 36) - self.Points.RootPart.ScreenPos).Magnitude
		if espSettings.MouseDistanceRolloff <= 200 then
			newOpacity = math.clamp(1 - self.DistanceFromMouse / espSettings.MouseDistanceRolloff, newOpacity, 1)
		end

		for i,v in {HealthBar, Text, Box, Line} do v.Opacity = newOpacity v.OutlineOpacity = newOpacity end
		for i,v in SkeletonDrawings do v.Opacity = newOpacity v.OutlineOpacity = newOpacity end
		TextShadow.Opacity = math.clamp(Text.Opacity - 0.1, 0.2, 1)


		--// update colors
		if games.BB then
			self.Team = self:GetTeam()
		end

		if espSettings.TeamColor and self.Player.TeamColor ~= nil then
			local newColor = self.Player.TeamColor.Color;
			if games.BB and self.Team then
				newColor = self.Team.Color.Value
			end
			for i,v in {Text, Box, Line} do v.Color = newColor end
			for i,v in SkeletonDrawings do v.Color = newColor end
			self.Highlight.FillColor = newColor
		elseif not espSettings.TeamColor and Text.Color ~= colors.White then
			for i,v in {Text, Box, Line} do v.Color = colors.White end
			for i,v in SkeletonDrawings do v.Color = colors.White end
			self.Highlight.FillColor = Color3.new(1,1,1)
		end
	end

	function Player:Destroy()
		playerList[self.Name] = nil
		for i,v in self.Connects do v:Disconnect() end
		for i,v in {unpack(self.Drawings), unpack(self.SkeletonDrawings)} do v.Visible = false v:Remove() end
		self.Highlight:Destroy()
	end
end

table.insert(connects, players.PlayerAdded:Connect(Player.new)); for _,v in players:GetPlayers() do task.spawn(Player.new, v) end
table.insert(connects, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	viewportSize = camera.ViewportSize
	for i,v in playerList do
		v:UpdateTracerLine()
	end
end))

runService:BindToRenderStep("x_upESP", 200, function()
	for i,v in playerList do
		v:Update()
	end
end)
--// end esp


local Aimbot = {}; do 
	Aimbot.__index = Aimbot

	function Aimbot.new()
		self.ClosestPlayer = nil;
		
	end
end



--// start ui
local UI = {}; do
	UI.__index = UI

	function UI.new(name)
		local self = {}; setmetatable(self, UI)

		self.Name = name
		self.Window = RenderWindow.new(name)
		self.TabMenu = self.Window:TabMenu()
		self.Tabs = {"ESP", "Aimbot"} -- comment this line if you only want a single window
		self.Objects = {}
		self.Separators = {}

		self.Colors = {
			Background = {
				Color = Color3.new(0,0,0);
				Alpha = 1;

				ColorOptions = {
					"TitleBg";
					"TitleBgActive";
					"TitleBgCollapsed";
					"Button";
					"ChildBg";
					"FrameBg";
					"Header";
				};
			};
			Hover = {
				Color = Color3.new(1,0,0);
				Alpha = 0.5;

				ColorOptions = {
					"ButtonHovered";
					"SliderGrab";
					"ResizeGripHovered";
					"HeaderHovered";
					"SeparatorHovered";
					"FrameBgHovered";
				};
			};
			Active = {
				Color = Color3.new(1,0,0);
				Alpha = 1;

				ColorOptions = {
					"CheckMark";
					"ButtonActive";
					"ResizeGripActive";
					"SliderGrabActive";
					"TextSelectedBg";
					"HeaderActive";
					"SeparatorActive";
				};
			};
		}

		self.Window.CanResize = true
		self.Window.DefaultSize = Vector2.new(465, 600)

		for _, styleOption in {"WindowRounding", "ChildRounding", "GrabRounding", "FrameRounding"} do 
			self:SetStyle(styleOption, 6) 
		end
		self:SetBackgroundColor();
		self:SetHoverColor()
		self:SetActiveColor()
		self:SetColor(RenderColorOption["WindowBG"], Color3.new(0.05, 0.05, 0.05), 1)
		self:SetStyle("WindowBorderSize", 1)
		
		return self
	end

	function UI:CreateTabs()
		local tabsTable = {}; for i,v in self.Tabs do tabsTable[i] = v end; table.clear(self.Tabs)
		for i,v in tabsTable do
			local tab = self.TabMenu:Add(v)
			self.Tabs[v] = tab 
		end
	end

	function UI:SetColor(colorOption, color, alpha)
		self.Window:SetColor(RenderColorOption[colorOption], color, alpha)
	end

	function UI:SetStyle(styleOption, value)
		self.Window:SetStyle(RenderStyleOption[styleOption], value)
	end

	function UI:SetBackgroundColor(colorTable, color, alpha)
		colorTable = colorTable or self.Colors.Background
		for _, colorOption in self.Colors.Active.ColorOptions do 
			self:SetColor(colorOption, color or colorTable.Color, alpha or colorTable.Alpha)
		end
	end

	function UI:SetHoverColor(colorTable, color, alpha)
		colorTable = colorTable or self.Colors.Hover
		for _, colorOption in self.Colors.Active.ColorOptions do 
			self:SetColor(colorOption, color or colorTable.Color, alpha or colorTable.Alpha)
		end
	end

	function UI:SetActiveColor(colorTable, color, alpha)
		colorTable = colorTable or self.Colors.Active
		for _, colorOption in self.Colors.Active.ColorOptions do 
			self:SetColor(colorOption, color or colorTable.Color, alpha or colorTable.Alpha)
		end
	end

	function UI:CreateObject(objProperties)
		if objProperties.Name and (self.Tabs and self.Objects[objProperties.Tab][objProperties.Name] or self.Objects[objProperties.Name]) then return error("object with name already created") end
		
		local tab = self.Tabs and self.Tabs[objProperties.Tab] or self.Window
		local object = tab[objProperties.Type](tab)

		if objProperties.Name then
			object.Label = objProperties.Name
		end
		
		if objProperties.Callback then
			object.OnUpdated:Connect(objProperties.Callback)
		end

		if objProperties.Properties and typeof(objProperties) == "table" then
			for i,v in pairs(objProperties.Properties) do object[i] = v end
			if objProperties.Properties.Checked then
				objProperties.Callback(true)
			end
		end
		
		local fakeObject = setmetatable({}, {
			__index = function(self, idx)
				return object[idx] or objProperties[idx]
			end,
			__newindex = function(self, idx, key)
				object[idx] = key
				if idx == "Checked" or idx == "Value" or idx == "Text" or idx == "Color" then
					objProperties.Callback(key)
				end
			end,
		})

		local table = {Real = object; Fake = fakeObject}
		if self.Tabs then
			self.Objects[objProperties.Tab][objProperties.Name] = table
		else
			self.Objects[objProperties.Name] = table
		end
		
		return fakeObject
	end

	function UI:CreateLabel(name, tab)
		local obj = self:CreateObject({Tab = tab; Name = name; Type = "Label"})
		table.insert(self.Separators, self.Window:Separator())
	end

	function UI:Destroy()
		for i,v in self.Objects do v:Remove() end
		for i,v in self.Separators do v:Remove() end
		self.Window:Remove()
		for i,v in self do v = nil end
	end
end

uiObject = UI.new("x_up Universal")

--// ui toggles
uiObject:CreateLabel("Toggles", "ESP")
uiObject:CreateObject({
	Tab = "ESP";
	Name = "Enabled";
	Type = "CheckBox";
	Properties = { Value = espSettings.Enabled };
	Callback = function(value)
		espSettings.Enabled = value
	end;
})
local teamColorToggle = uiObject:CreateObject({
	Tab = "ESP";
	Name = "Team Color";
	Type = "CheckBox";
	Properties = { Value = espSettings.TeamColor };
	Callback = function(value)
		espSettings.TeamColor = value
	end;
})
local chamsToggle = uiObject:CreateObject({
	Tab = "ESP";
	Name = "Chams";
	Type = "CheckBox";
	Properties = { Value = espSettings.Chams };
	Callback = function(value)
		espSettings.Chams = value
	end;
})
local tracersToggle = uiObject:CreateObject({
	Tab = "ESP";
	Name = "Tracers";
	Type = "CheckBox";
	Properties = { Value = espSettings.Tracers };
	Callback = function(value)
		espSettings.Tracers = value
	end;
})
local skeletonToggle = uiObject:CreateObject({
	Tab = "ESP";
	Name = "Skeleton";
	Type = "CheckBox";
	Properties = { Value = espSettings.Skeleton };
	Callback = function(value)
		espSettings.Skeleton = value
	end;
})
local boxesToggle = uiObject:CreateObject({
	Tab = "ESP";
	Name = "Box";
	Type = "CheckBox";
	Properties = { Value = espSettings.Boxes };
	Callback = function(value)
		espSettings.Boxes = value
	end;
})

--// ui sliders
uiObject:CreateLabel("Sliders", "ESP")
local transparencyRolloffSlider = uiObject:CreateObject({ 
	Tab = "ESP";
	Name = "Transparency Rolloff";
	Type = "IntSlider";
	Properties = {
		Min = 10;
		Max = 500;
		Value = espSettings.TransparencyRolloff;
		Clamped = true;
	};
	Callback = function(value)
		espSettings.TransparencyRolloff = value
	end;
})

local mouseDistanceRolloffSlider = uiObject:CreateObject({ 
	Tab = "ESP";
	Name = "Mouse Distance Rolloff";
	Type = "IntSlider";
	Properties = {
		Min = 50;
		Max = 200;
		Value = espSettings.MouseDistanceRolloff;
		Clamped = true;
	};
	Callback = function(value)
		espSettings.MouseDistanceRolloff = value
	end;
})
uiObject.Tabs["ESP"]:Separator()

--// settings
local fileList = {}
local function setupFileList() fileList = listfiles("x_up/settings/esp/") for i,v in pairs(fileList) do fileList[i] = v:split("\\")[4]:gsub(".json", "") end end
if not isfolder("x_up/settings/esp/") then makefolder("x_up/settings/esp/") end
if not isfile("x_up/settings/esp/Default.json") then writefile("x_up/settings/esp/Default.json", game:GetService("HttpService"):JSONEncode(espSettings)) end

setupFileList()

local selectedSettings, newName, textBox = 1, "", nil
uiObject:CreateLabel("Settings", "ESP")
local combo = uiObject:CreateObject({
	Tab = "ESP";
	Name = "Settings";
	Type = "Combo";
	Properties = {
		Items = fileList
	};
	Callback = function(item)
		selectedSettings = item
		textBox.Value = fileList[item]
	end
})
textBox = uiObject:CreateObject({
	Tab = "ESP";
	Name = "Name";
	Type = "TextBox";
	Properties = {
		MaxTextLength = 16;
		Value = "Default";
	};
	Callback = function(name)
		newName = name
	end
})
uiObject:CreateObject({
	Tab = "ESP";
	Name = "Save Settings";
	Type = "Button";
	Callback = function()
		local success, err = pcall(function()
			writefile("x_up/settings/esp/"..textBox.Value..".json", game:GetService("HttpService"):JSONEncode(espSettings))
		end)
		if not success then 
			syn.toast_notification({
				Type = ToastType.Warning;
				Duration = 3;
				Title = "x_up ESP";
				Content = "Something went wrong when creating/writing file\n(you cannot use special characters)";
				IconColor = true;
			})
		else
			setupFileList()
			combo.Items = fileList
		end
	end
})
uiObject:CreateObject({
	Tab = "ESP";
	Name = "Load Settings";
	Type = "Button";
	Callback = function()
		local newSettings = game:GetService("HttpService"):JSONDecode(readfile("x_up/settings/esp/"..fileList[selectedSettings]..".json"))
		enabledToggle.Value = newSettings.Enabled
		teamColorToggle.Value = newSettings.TeamColor
		chamsToggle.Value = newSettings.Chams
		boxesToggle.Value = newSettings.Boxes
		tracersToggle.Value = newSettings.Tracers
		skeletonToggle.Value = newSettings.Skeleton

		mouseDistanceRolloffSlider.Value = newSettings.MouseDistanceRolloff
		transparencyRolloffSlider.Value = newSettings.TransparencyRolloff
	end
})
uiObject:CreateObject({
	Tab = "ESP";
	Name = "Delete Settings";
	Type = "Button";
	Callback = function()
		delfile("x_up/settings/esp/"..fileList[selectedSettings]..".json")
		setupFileList()
		combo.Items = fileList
	end
})
--// end settings
uiObject.Tabs["ESP"]:Separator()
uiObject:CreateObject({
	Tab = "ESP";
	Name = "Unload ESP";
	Type = "Button";
	Callback = Destroy
})


--// keybinds
local binds = {
	[Enum.KeyCode.F3] = enabledToggle;
	[Enum.KeyCode.F4] = teamColorToggle;
	[Enum.KeyCode.F5] = chamsToggle;
	[Enum.KeyCode.F6] = teamColorToggle;
	[Enum.KeyCode.F8] = skeletonToggle;
	[Enum.KeyCode.F10] = boxesToggle;
}
table.insert(connects, game:GetService("UserInputService").InputBegan:Connect(function(inputObject, gp)
	if gp then return end
	if inputObject.KeyCode and binds[inputObject.KeyCode] ~= nil then
		binds[inputObject.KeyCode].Value = not binds[inputObject.KeyCode].Value
	end
end))
--// end keybinds

--// end ui


syn.toast_notification({
	Type = ToastType.Success;
	Duration = 3;
	Title = "x_up Universal";
	Content = ("Successfully loaded x_up Universal in %s seconds"):format(((tick() - startTime)..("")):sub(1, 5));
	IconColor = true;
})

while true do if unloaded then break end task.wait() end