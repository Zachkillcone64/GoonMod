----------
-- Payday 2 GoonMod, Weapon Customizer Beta, built on 12/30/2014 6:10:13 PM
-- Copyright 2014, James Wilkinson, Overkill Software
----------

-- Mod Definition
local Mod = class( BaseMod )
Mod.id = "ExtendedInventory"
Mod.Name = "Extended Inventory"
Mod.Desc = "Allows mods to add special items to your inventory"
Mod.Requirements = {}
Mod.Incompatibilities = {}

Hooks:Add("GoonBaseRegisterMods", "GoonBaseRegisterMutators_" .. Mod.id, function()
	GoonBase.Mods:RegisterMod( Mod )
end)

if not Mod:IsEnabled() then
	return
end

-- Extended Inventory
_G.GoonBase.ExtendedInventory = _G.GoonBase.ExtendedInventory or {}
local ExtendedInv = _G.GoonBase.ExtendedInventory

-- Localization
local Localization = GoonBase.Localization
Localization.bm_menu_extended_inv = "Special"
Localization.DefaultReserveText = "IN RESERVE"

ExtendedInv.InitialLoadComplete = false
ExtendedInv.RegisteredItems = {}
ExtendedInv.Items = {}
ExtendedInv.SaveFile = GoonBase.Path .. "inventory.ini"

-- Initialize
Hooks:RegisterHook("ExtendedInventoryInitialized")
Hooks:Add("GoonBasePostLoadedMods", "GoonBasePostLoadedMods_ExtendedInv", function()
	Hooks:Call("ExtendedInventoryInitialized")
end)

function ExtendedInv:_MissingItemError(item)
	Print("[Error] Could not find item '" .. item .. "' in Extended Inventory!")
end

function ExtendedInv:ItemIsRegistered(id)
	return ExtendedInv.RegisteredItems[id] == true
end

function ExtendedInv:RegisterItem(data)

	if not ExtendedInv.InitialLoadComplete then
		ExtendedInv:Load()
		ExtendedInv.InitialLoadComplete = true
	end

	ExtendedInv.RegisteredItems[data.id] = true
	ExtendedInv.Items[data.id] = ExtendedInv.Items[data.id] or {}
	for k, v in pairs( data ) do
		ExtendedInv.Items[data.id][k] = v
	end
	ExtendedInv.Items[data.id].amount = ExtendedInv.Items[data.id].amount or 0

end

function ExtendedInv:AddItem(item, amount)
	if ExtendedInv.Items[item] ~= nil then
		ExtendedInv.Items[item].amount = ExtendedInv.Items[item].amount + amount
		ExtendedInv:Save()
	else
		ExtendedInv:_MissingItemError(item)
	end
end

function ExtendedInv:TakeItem(item, amount)
	if ExtendedInv.Items[item] ~= nil then
		ExtendedInv.Items[item].amount = ExtendedInv.Items[item].amount - amount
		ExtendedInv:Save()
	else
		ExtendedInv:_MissingItemError(item)
	end
end

function ExtendedInv:SetItemAmount(item, amount)
	if ExtendedInv.Items[item] ~= nil then
		ExtendedInv.Items[item].amount = amount
		ExtendedInv:Save()
	else
		ExtendedInv:_MissingItemError(item)
	end
end


function ExtendedInv:GetItem(item)
	return ExtendedInv.Items[item] or nil
end

function ExtendedInv:HasItem(item)
	if ExtendedInv.Items[item] == nil then
		return false
	end
	return ExtendedInv.Items[item].amount > 0 or nil
end

function ExtendedInv:GetAllItems()
	return ExtendedInv.Items
end

function ExtendedInv:GetReserveText(item)
	return item.reserve_text or Localization.DefaultReserveText
end

Hooks:Add("BlackMarketGUIPostSetup", "BlackMarketGUIPostSetup_ExtendedInventory", function(gui, is_start_page, component_data)
	gui.identifiers.extended_inv = Idstring("extended_inv")
end)

function ExtendedInv.do_populate_extended_inventory(self, data)

	local psuccess, perror = pcall(function()
		
	local new_data = {}
	local guis_catalog = "guis/"
	local index = 0

	for i, item_data in pairs( ExtendedInv:GetAllItems() ) do

		local hide = item_data.hide_when_none_in_stock or false
		if ExtendedInv:ItemIsRegistered(i) and (hide == false or (hide == true and item_data.amount > 0)) then

			local item_id = item_data.id
			local name_id = item_data.name
			local desc_id = item_data.desc
			local texture_id = item_data.texture

			index = index + 1
			new_data = {}
			new_data.name = item_id
			new_data.name_localized = managers.localization:text( name_id )
			new_data.desc_localized = managers.localization:text( desc_id )
			new_data.category = "extended_inv"
			new_data.slot = index
			new_data.amount = item_data.amount
			new_data.unlocked = (new_data.amount or 0) > 0
			new_data.level = item_data.level or 0
			new_data.skill_based = new_data.level == 0
			new_data.skill_name = new_data.level == 0 and "bm_menu_skill_locked_" .. new_data.name
			new_data.bitmap_texture = texture_id
			new_data.lock_texture = self:get_lock_icon(new_data)
			data[index] = new_data

		end

	end

	-- Fill empty slots
	local max_items = data.override_slots[1] * data.override_slots[2]
	for i = 1, max_items do
		if not data[i] then
			new_data = {}
			new_data.name = "empty"
			new_data.name_localized = ""
			new_data.desc_localized = ""
			new_data.category = "extended_inv"
			new_data.slot = i
			new_data.unlocked = true
			new_data.equipped = false
			data[i] = new_data
		end
	end

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end

Hooks:Add("BlackMarketGUIStartPageData", "BlackMarketGUIStartPageData_ExtendedInventory", function(gui, data)

	local psuccess, perror = pcall(function()
		
		local should_hide_tab = true
		for k, v in pairs( ExtendedInv:GetAllItems() ) do
			if v.hide_when_none_in_stock == false or (v.hide_when_none_in_stock == true and v.amount > 0) then
				should_hide_tab = false
			end
		end
		if should_hide_tab then
			return
		end

		gui.populate_extended_inventory = ExtendedInv.do_populate_extended_inventory

		table.insert(data, {
			name = "bm_menu_extended_inv",
			category = "extended_inv",
			on_create_func_name = "populate_extended_inventory",
			identifier = gui.identifiers.extended_inv,
			override_slots = {5, 2},
			start_crafted_item = 1
		})

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end)

Hooks:Add("BlackMarketGUIUpdateInfoText", "BlackMarketGUIUpdateInfoText_ExtendedInventory", function(gui)

	local psuccess, perror = pcall(function()

		local self = gui
		local slot_data = self._slot_data
		local tab_data = self._tabs[self._selected]._data
		local prev_data = tab_data.prev_node_data
		local ids_category = Idstring(slot_data.category)
		local identifier = tab_data.identifier
		local updated_texts = {
			{text = ""},
			{text = ""},
			{text = ""},
			{text = ""},
			{text = ""}
		}
		
		if ids_category == self.identifiers.extended_inv then

			updated_texts[1].text = slot_data.name_localized or ""
			updated_texts[2].text = tostring(slot_data.amount or 0) .. " " .. ExtendedInv:GetReserveText(slot_data.name)
			updated_texts[4].text = slot_data.desc_localized or ""

			gui:_update_info_text(slot_data, updated_texts)

		end

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end)

-- Saving and Loading
function ExtendedInv:GetSaveString()

	local contents = "";
	for k, v in pairs( ExtendedInv.Items ) do
		
		if type(v) == "table" then
			contents = string.format( "%s[%s]\n", contents, tostring(k) )
			for a, b in pairs( v ) do
				contents = string.format( "%s%s=%s\n", contents, tostring(a), tostring(b) )
			end
		end

	end

	return contents

end

function ExtendedInv:Save(fileName)

	if fileName == nil then
		fileName = ExtendedInv.SaveFile
	end

	-- Encode data using "base64" while saving
	-- Simple, but will stop most players from editing the save file since it'll look like gibberish
	-- Those who want to cheat that badly will decode any encryption or use lua to bypass it, so
	-- no point in super-complicated systems
	local file = io.open(fileName, "w+")
	local data = ExtendedInv:GetSaveString()
	data = GoonBase.Utils.Base64:Encode( data )
	file:write( data )
	file:close()

end

function ExtendedInv:Load(fileName)

	if fileName == nil then
		fileName = ExtendedInv.SaveFile
	end

	local file = io.open(fileName, 'r')
	local key

	if file == nil then
		Print( "Could not open file (" .. fileName .. ")! Does it exist?" )
		return
	end

	local fileString = ""
	for line in file:lines() do
		fileString = fileString .. line .. "\n"
	end
	fileString = GoonBase.Utils.Base64:Decode( fileString )

	local fileLines = string.split(fileString, "[\n]")
	for i, line in pairs( fileLines ) do

		local loadKey = line:match('^%[([^%[%]]+)%]$')
		if loadKey then
			key = tonumber(loadKey) and tonumber(loadKey) or loadKey
			ExtendedInv.Items[key] = ExtendedInv.Items[key] or {}
		end

		local param, val = line:match('^([%w|_]+)%s-=%s-(.+)$')
		if param and val ~= nil then

			if tonumber(val) then
				val = tonumber(val)
			elseif val == "true" then
				val = true
			elseif val == "false" then
				val = false
			end

			if tonumber(param) then
				param = tonumber(param)
			end

			ExtendedInv.Items[key][param] = val

		end

	end

	file:close()

end
-- END OF FILE
