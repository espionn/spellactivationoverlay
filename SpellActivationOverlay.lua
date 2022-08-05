local AddonName, SAO = ...

local sizeScale = 0.8;
local longSide = 256 * sizeScale;
local shortSide = 128 * sizeScale;

function SpellActivationOverlay_OnLoad(self)
	local class = SAO.Class[select(2, UnitClass("player"))];
	if class then
		class.Register(SAO);
		SAO.CurrentClass = class;
	else
		print("Class unknown or not converted yet: "..select(1, UnitClass("player")));
	end
	SAO.Frame = self;
	SAO.ShowAllOverlays = SpellActivationOverlay_ShowAllOverlays;
	SAO.HideOverlays = SpellActivationOverlay_HideOverlays;
	SAO.HideAllOverlays = SpellActivationOverlay_HideAllOverlays;

	self.overlaysInUse = {};
	self.unusedOverlays = {};
	
	-- These events do not exist in Classic Era, BC Classic, nor Wrath Classic
--	self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW");
--	self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE");
--	self:RegisterUnitEvent("UNIT_AURA", "player");
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	
	self:SetSize(longSide, longSide)
end

function SpellActivationOverlay_OnEvent(self, event, ...)
--[[ 
	Dead code because these events do not exist in Classic Era, BC Classic, nor Wrath Classic
	Also, the "displaySpellActivationOverlays" console variable does not exist
]]
--[[
	if ( event == "SPELL_ACTIVATION_OVERLAY_SHOW" ) then
		local spellID, texture, positions, scale, r, g, b = ...;
		if ( GetCVarBool("displaySpellActivationOverlays") ) then 
			SpellActivationOverlay_ShowAllOverlays(self, spellID, texture, positions, scale, r, g, b, true)
		end
	elseif ( event == "SPELL_ACTIVATION_OVERLAY_HIDE" ) then
		local spellID = ...;
		if spellID then
			SpellActivationOverlay_HideOverlays(self, spellID);
		else
			SpellActivationOverlay_HideAllOverlays(self);
		end
	end]]
	if ( event == "PLAYER_REGEN_DISABLED" ) then
		self.combatAnimIn:Play();
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		self.combatAnimOut:Play();
	end
	if ( event ) then
		SAO:OnEvent(event, ...);
	end
end

local complexLocationTable = {
	["RIGHT (FLIPPED)"] = {
		RIGHT = {	hFlip = true },
	},
	["BOTTOM (FLIPPED)"] = {
		BOTTOM = { vFlip = true },
	},
	["LEFT + RIGHT (FLIPPED)"] = {
		LEFT = {},
		RIGHT = { hFlip = true },
	},
	["TOP + BOTTOM (FLIPPED)"] = {
		TOP = {},
		BOTTOM = { vFlip = true },
	},
}

function SpellActivationOverlay_ShowAllOverlays(self, spellID, texturePath, positions, scale, r, g, b, autoPulse, forcePulsePlay)
	positions = strupper(positions);
	if ( complexLocationTable[positions] ) then
		for location, info in pairs(complexLocationTable[positions]) do
			SpellActivationOverlay_ShowOverlay(self, spellID, texturePath, location, scale, r, g, b, info.vFlip, info.hFlip, autoPulse, forcePulsePlay);
		end
	else
		SpellActivationOverlay_ShowOverlay(self, spellID, texturePath, positions, scale, r, g, b, false, false, autoPulse, forcePulsePlay);
	end
end

function SpellActivationOverlay_ShowOverlay(self, spellID, texturePath, position, scale, r, g, b, vFlip, hFlip, autoPulse, forcePulsePlay)
	local overlay = SpellActivationOverlay_GetOverlay(self, spellID, position);
	overlay.spellID = spellID;
	overlay.position = position;
	
	overlay:ClearAllPoints();
	
	local texLeft, texRight, texTop, texBottom = 0, 1, 0, 1;
	if ( vFlip ) then
		texTop, texBottom = 1, 0;
	end
	if ( hFlip ) then
		texLeft, texRight = 1, 0;
	end
	overlay.texture:SetTexCoord(texLeft, texRight, texTop, texBottom);
	
	local width, height;
	if ( position == "CENTER" ) then
		width, height = longSide, longSide;
		overlay:SetPoint("CENTER", self, "CENTER", 0, 0);
	elseif ( position == "LEFT" ) then
		width, height = shortSide, longSide;
		overlay:SetPoint("RIGHT", self, "LEFT", 0, 0);
	elseif ( position == "RIGHT" ) then
		width, height = shortSide, longSide;
		overlay:SetPoint("LEFT", self, "RIGHT", 0, 0);
	elseif ( position == "TOP" ) then
		width, height = longSide, shortSide;
		overlay:SetPoint("BOTTOM", self, "TOP");
	elseif ( position == "BOTTOM" ) then
		width, height = longSide, shortSide;
		overlay:SetPoint("TOP", self, "BOTTOM");
	elseif ( position == "TOPRIGHT" ) then
		width, height = shortSide, shortSide;
		overlay:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, 0);
	elseif ( position == "TOPLEFT" ) then
		width, height = shortSide, shortSide;
		overlay:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 0, 0);
	elseif ( position == "BOTTOMRIGHT" ) then
		width, height = shortSide, shortSide;
		overlay:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", 0, 0);
	elseif ( position == "BOTTOMLEFT" ) then
		width, height = shortSide, shortSide;
		overlay:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", 0, 0);
	else
		--GMError("Unknown SpellActivationOverlay position: "..tostring(position));
		return;
	end
	
	overlay:SetSize(width * scale, height * scale);
	
	overlay.texture:SetTexture(texturePath);
	overlay.texture:SetVertexColor(r / 255, g / 255, b / 255);
	
	overlay.animOut:Stop();	--In case we're in the process of animating this out.
	PlaySound(SOUNDKIT.UI_POWER_AURA_GENERIC);
	overlay:Show();
	if ( forcePulsePlay ) then
		overlay.pulse:Play();
	end
	overlay.pulse.autoPlay = autoPulse;
end

function SpellActivationOverlay_GetOverlay(self, spellID, position)
	local overlayList = self.overlaysInUse[spellID];
	local overlay;
	if ( overlayList ) then
		for i=1, #overlayList do
			if ( overlayList[i].position == position ) then
				overlay = overlayList[i];
			end
		end
	end
	
	if ( not overlay ) then
		overlay = SpellActivationOverlay_GetUnusedOverlay(self);
		if ( overlayList ) then
			tinsert(overlayList, overlay);
		else
			self.overlaysInUse[spellID] = { overlay };
		end
	end
	
	return overlay;
end

function SpellActivationOverlay_HideOverlays(self, spellID)
	local overlayList = self.overlaysInUse[spellID];
	if ( overlayList ) then
		for i=1, #overlayList do
			local overlay = overlayList[i];
			overlay.pulse:Pause();
			overlay.animOut:Play();
		end
	end
end

function SpellActivationOverlay_HideAllOverlays(self)
	for spellID, overlayList in pairs(self.overlaysInUse) do
		SpellActivationOverlay_HideOverlays(self, spellID);
	end
end

function SpellActivationOverlay_GetUnusedOverlay(self)
	local overlay = tremove(self.unusedOverlays, #self.unusedOverlays);
	if ( not overlay ) then
		overlay = SpellActivationOverlay_CreateOverlay(self);
	end
	return overlay;
end

function SpellActivationOverlay_CreateOverlay(self)
	return CreateFrame("Frame", nil, self, "SpellActivationOverlayTemplate");
end

function SpellActivationOverlayTexture_OnShow(self)
	self.animIn:Play();
end

function SpellActivationOverlayTexture_OnFadeInPlay(animGroup)
	animGroup:GetParent():SetAlpha(0);
end

function SpellActivationOverlayTexture_OnFadeInFinished(animGroup)
	local overlay = animGroup:GetParent();
	overlay:SetAlpha(1);
	if ( overlay.pulse.autoPlay ) then
		overlay.pulse:Play();
	end
end

function SpellActivationOverlayTexture_OnFadeOutFinished(anim)
	local overlay = anim:GetRegionParent();
	local overlayParent = overlay:GetParent();
	overlay.pulse:Stop();
	overlay:Hide();
	tDeleteItem(overlayParent.overlaysInUse[overlay.spellID], overlay)
	tinsert(overlayParent.unusedOverlays, overlay);
end

function SpellActivationOverlayFrame_OnFadeInFinished(anim)
	local frame = anim:GetParent();
	frame:SetAlpha(1);
end

function SpellActivationOverlayFrame_OnFadeOutFinished(anim)
	local frame = anim:GetParent();
	frame:SetAlpha(0.5);
end
