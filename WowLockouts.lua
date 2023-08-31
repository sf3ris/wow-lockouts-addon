WowLockouts = LibStub("AceAddon-3.0"):NewAddon("WowLockouts", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

LibStub("AceComm-3.0"):Embed(WowLockouts)

local AceComm = LibStub("AceComm-3.0")

local addonName, NS = ...

local options = { 
	name = "WowLockouts",
	handler = WowLockouts,
	type = "group",
	args = {
		msg = {
			type = "input",
			name = "Message",
			desc = "The message to be displayed when you get home.",
			usage = "<Your message>",
			get = "GetMessage",
			set = "SetMessage",
		},
        showOnScreen = {
			type = "toggle",
			name = "Public lockouts",
			desc = "Your lockouts are shared with guildies and groups",
			get = "AreLockoutsPublic",
			set = "TogglePublicLockouts"
		},
	},
}

function WowLockouts:GetMessage(info)
	return self.message
end

function WowLockouts:SetMessage(info, value)
	self.message = value
end

function WowLockouts:AreLockoutsPublic(info)
	return self.areLockoutsPublic
end

function WowLockouts:TogglePublicLockouts(info, value)
	self.areLockoutsPublic = value
end

function WowLockouts:OnInitialize()
	-- Called when the addon is loaded
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WowLockouts", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WowLockouts", "WowLockouts")
	self:Print("WowLockouts Loaded")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterChatCommand("wl", "OpenOptions")
    WowLockouts:RegisterComm("WowLockouts")
    self.message = "WowLockouts"
    self.areLockoutsPublic = true
end

function WowLockouts:OpenOptions()
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

function WowLockouts:ADDON_LOADED()
    if type(AccountCharactersLockout) == "string" then
        AccountCharactersLockout = NS.json.decode(AccountCharactersLockout, 1, nil)
    end
    local characterLockouts = self:getCharacterLockout()
    AccountCharactersLockout = {}
    AccountCharactersLockout[characterLockouts.character.name.."-"..characterLockouts.character.realm] = characterLockouts

    -- Share the player lockouts with guildies
    self:sendLockout("GUILD")
end

function WowLockouts:getCharacterLockout()
    local characterName, _ = UnitName("player")
    local realmName = GetRealmName()
    local characterLockouts = {
        character = {
            name = characterName,
            realm = realmName
        },
        lockouts = {}
    }

    for i=1, GetNumSavedInstances() do 
        now=time()
        name, id, reset, difficulty, locked, extended, sig, raid, num, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i); 

        if raid == true and locked == true then 
            local bosses = {}
            for j=1, numEncounters do
                local bossName, _, killed = GetSavedInstanceEncounterInfo(i, j)
                table.insert(bosses, {
                    boss = bossName,
                    killed = killed
                })
            end

            resetAt = now+reset
            table.insert(characterLockouts.lockouts, {
                raid_name = name, 
                difficulty = difficultyName,
                lockout_id = id, 
                reset_at = resetAt, 
                encounters_in_instance = numEncounters, 
                boss_killed = encounterProgress,
                bosses = bosses
            })
        end 
    end
    
    return characterLockouts
end

function WowLockouts:AddPlayerLockout(playerLockouts)
    AccountCharactersLockout[playerLockouts.character.name.."-"..playerLockouts.character.realm] = playerLockouts
end

function WowLockouts:PLAYER_LOGOUT()
    local characterLockouts = self:getCharacterLockout()
    AccountCharactersLockout[characterLockouts.character.name.."-"..characterLockouts.character.realm] = characterLockouts
    AccountCharactersLockout = NS.json.encode(AccountCharactersLockout, { indent = true })
end

function WowLockouts:GROUP_ROSTER_UPDATE()
    self:sendLockout("PARTY")
    self:sendLockout("RAID")
end


-- Communication

function WowLockouts:sendLockout(channel)
    -- we dont want to decay combat performances so we are not sending packets in combat
    if not UnitAffectingCombat("player") then
        local message = WowLockouts:Serialize(self:getCharacterLockout())
        local target = nil
        -- mostly used for debug
        if channel == "WHISPER" then
           target = UnitName("target") 
        end
        WowLockouts:SendCommMessage("WowLockouts", message, channel, target) 
    end
end

function WowLockouts:OnCommReceived(prefix, message, distribution, sender)
    local success, deserializedMessage = WowLockouts:Deserialize(message)
    if success then
        self:AddPlayerLockout(deserializedMessage)
    end
end