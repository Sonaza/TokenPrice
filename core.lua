------------------------------------------------------------
-- TokenPrice by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, namespace = ...;
local L = LibStub('AceLocale-3.0'):GetLocale(ADDON_NAME, true);
if(not L) then
	error("Please restart game after updating the addon.");
end

local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = Addon;

local LibDataBroker = LibStub("LibDataBroker-1.1");
local AceDB         = LibStub("AceDB-3.0");
local LibRealmInfo  = LibStub("LibRealmInfo");

local ICON_PATTERN_16 = "|T%s:16:16:0:0|t";
local MODULE_ICON_PATH = "Interface\\Icons\\wow_token01";
local TEX_MODULE_ICON = ICON_PATTERN_16:format(MODULE_ICON_PATH);

local tokenPrice = {
	["EUR"] = { order = 1, name = "Euro", 				price = 20, 	battlenet = 13.00, 	currency = "EUR" },
	["GBP"] = { order = 2, name = "British Pound", 		price = 17, 	battlenet = 10.00, 	currency = "GBP" },
	["USD"] = { order = 3, name = "US Dollar", 			price = 20, 	battlenet = 15.00, 	currency = "USD" },
	["AUD"] = { order = 4, name = "Australian Dollar", 	price = 25, 	battlenet = 17.00, 	currency = "AUD" },
	["RUB"] = { order = 8, name = "Russian Ruble",      price = 1400,   battlenet = 550,    currency = "RUB" },
	["CNY"]	= { order = 5, name = "Chinese Yuan", 		price = 75, 	battlenet = nil, 	currency = "CNY" },
	["TWD"]	= { order = 6, name = "New Taiwan Dollar", 	price = 500, 	battlenet = nil, 	currency = "TWD" },
	["KRW"]	= { order = 7, name = "South Korean Won", 	price = 22000, 	battlenet = nil, 	currency = "KRW" },
};

local regionCurrency = {
	["EU"] = "EUR",
	["US"] = "USD",
	["OC"] = "AUD",
	["RU"] = "RUB",
	["KR"] = "KRW",
	["TW"] = "TWD",
	["CN"] = "CNY",
};

local servicePrices = {
	["EUR"] = {
		levelBoost 			= 60,
		factionChange 		= 30,
		characterTransfer 	= 25,
		raceChange 			= 25,
		appearanceChange 	= 15,
		nameChange 			= 10,
	},
	["GBP"] = {
		levelBoost 			= 49,
		factionChange 		= 27,
		characterTransfer 	= 19,
		raceChange 			= 19,
		appearanceChange 	= 13,
		nameChange 			= 9,
	},
	["USD"] = {
		levelBoost 			= 60,
		factionChange 		= 30,
		characterTransfer 	= 25,
		raceChange 			= 25,
		appearanceChange 	= 15,
		nameChange 			= 10,
	},
	["AUD"] = {
		levelBoost 			= 66,
		factionChange 		= 33,
		characterTransfer 	= 27.5,
		raceChange 			= 27.50,
		appearanceChange 	= 16.5,
		nameChange 			= 11,
	},
	["RUB"] = {
		levelBoost          = 3200,
		factionChange       = 1600,
		characterTransfer   = 1350,
		raceChange          = 1350,
		appearanceChange    = 800,
		nameChange          = 549,
	},
}

function Addon:OnEnable()
	local playerRegion = "US";

	local guid = UnitGUID("player")
	if guid then
		local serverId = tonumber(strmatch(guid, "^Player%-(%d+)"))
		local id, realmName, _, _, _, _, realmRegion, realmTimezone = LibRealmInfo:GetRealmInfo(serverId);
		if(realmRegion == "US" and realmTimezone == "AEST") then
			playerRegion = "OC";
		else
			playerRegion = realmRegion or LibRealmInfo:GetCurrentRegion();
		end
	end
	
	local defaults = {
		global = {
			marketPriceData = {},
			lastUpdate = 0,
			currency = regionCurrency[playerRegion] or "USD",
			showPercentChange = true,
			swapColors = false,
			useLiteral = false,
			showCommonServices = true,
		}
	};
	
	self.db = AceDB:New("TokenPriceDB", defaults, true);
	
	Addon:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED");
	
	Addon:CreateBroker();
	Addon:InitializeUpdater();
	
	Addon.UpdaterFrame = CreateFrame("Frame"):SetScript("OnUpdate", Addon.OnUpdate);
end

function Addon:OnUpdate(elapsed)
	Addon.elapsed = (Addon.elapsed or 0) + elapsed;
	
	if(Addon.elapsed >= 1.0) then
		if(Addon.tooltip_open) then
			GameTooltip:ClearLines();
			Addon:SetTooltipText(GameTooltip);
			GameTooltip:Show();
		end
	end
end

function Addon:OnDisable()
		
end

function Addon:OpenContextMenu(parentFrame)
	if(not Addon.ContextMenu) then
		Addon.ContextMenu = CreateFrame("Frame", "TokenPriceContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	local contextMenuData = {
		{
			text = L["TokenPrice Options"], isTitle = true, notCheckable = true,
		},
		{
			text = L["Show percentage difference in Broker"],
			func = function() self.db.global.showPercentChange = not self.db.global.showPercentChange; Addon:UpdateBrokerText(); end,
			checked = function() return self.db.global.showPercentChange; end,
			isNotRadio = true,
		},
		{
			text = L["Swap colors (seller/buyer)"],
			func = function() self.db.global.swapColors = not self.db.global.swapColors; Addon:UpdateBrokerText(); end,
			checked = function() return self.db.global.swapColors; end,
			isNotRadio = true,
		},
		{
			text = L["Use literal gold display"],
			func = function() self.db.global.useLiteral = not self.db.global.useLiteral; Addon:UpdateBrokerText(); end,
			checked = function() return self.db.global.useLiteral; end,
			isNotRadio = true,
		},
		{
			text = L["Show service prices in gold"],
			func = function() self.db.global.showCommonServices = not self.db.global.showCommonServices; Addon:UpdateBrokerText(); end,
			checked = function() return self.db.global.showCommonServices; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = L["Currency Options"], isTitle = true, notCheckable = true,
		},
	};
	
	
	local currencyList = {}
	for _, data in pairs(tokenPrice) do
		tinsert(currencyList, {
			data = data,
		});
	end
	
	table.sort(currencyList, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return a.data.order < b.data.order;
	end);
	
	for _, v in pairs(currencyList) do
		tinsert(contextMenuData, {
			text = v.data.name,
			func = function() self.db.global.currency = v.data.currency; CloseMenus(); end,
			checked = function() return self.db.global.currency == v.data.currency; end,
		});
	end
	
	Addon.ContextMenu:SetPoint("BOTTOM", parentFrame, "BOTTOM", 0, 5);
	EasyMenu(contextMenuData, Addon.ContextMenu, parentFrame, 0, 0, "MENU", 5);
end

function Addon:GetRealMoneyPrice(money)
	if(not money or money == 0) then return 0 end
	
	local gold = money / 10000;
	
	local pricedata = tokenPrice[self.db.global.currency];
	return pricedata.price, pricedata.price / (gold / 10000), pricedata.currency;
end

function Addon:GetBattleNetRedeemPrice(money)
	if(not money or money == 0) then return 0 end
	
	local gold = money / 10000;
	
	local pricedata = tokenPrice[self.db.global.currency];
	if(not pricedata.battlenet) then return nil end
	
	return pricedata.battlenet, pricedata.battlenet / (gold / 10000), pricedata.currency;
end

function Addon:GetServicePrices(money)
	if(not money or money == 0) then return nil end
	
	local servicePriceData = servicePrices[self.db.global.currency];
	if(not servicePriceData) then return nil end
	
	local tokenPriceData = tokenPrice[self.db.global.currency];
	if(not tokenPriceData) then return nil end
	
	return {
		levelBoost 			= math.ceil(money * (servicePriceData.levelBoost / tokenPriceData.battlenet) / 10000) * 10000,
		factionChange 		= math.ceil(money * (servicePriceData.factionChange / tokenPriceData.battlenet) / 10000) * 10000,
		raceChange 			= math.ceil(money * (servicePriceData.raceChange / tokenPriceData.battlenet) / 10000) * 10000,
		appearanceChange 	= math.ceil(money * (servicePriceData.appearanceChange / tokenPriceData.battlenet) / 10000) * 10000,
		nameChange 			= math.ceil(money * (servicePriceData.nameChange / tokenPriceData.battlenet) / 10000) * 10000,
		characterTransfer 	= math.ceil(money * (servicePriceData.characterTransfer / tokenPriceData.battlenet) / 10000) * 10000
	}, servicePriceData, self.db.global.currency;
end

local function sign(value)
	if(value >= 0) then return 1; end
	return -1;
end

function Addon:GetPercentDifference(price, otherPrice)
	return math.abs(1.0 - (otherPrice / price)) * 100, sign(otherPrice - price);
end

function Addon:GetChangeColor(value)
	if(not value) then
		return "";
	end
	if (self.db.global.swapColors) then
		if(value >= 0) then
			return "|cfffa3d27+";
		else
			return "|cff9efa38-";
		end
	else
		if(value >= 0) then
			return "|cff9efa38+";
		else
			return "|cfffa3d27-";
		end
	end
	
	return "";
end

function Addon:FormatGoldString(coins, literal)
	coins = math.abs(coins or 0);
	
	local pattern;
	if(literal) then
		pattern = "%s|cfff0c80bg|r";
	else
		pattern = "%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t";
	end
	
	return pattern:format(math.floor(coins / 10000));
end

function Addon:SetTooltipText(tooltip)
	tooltip:AddLine(TEX_MODULE_ICON .. " " .. L["TokenPrice"]);
	tooltip:AddLine(" ");
	
	local lastPrice = Addon:GetLastPrice();
	tooltip:AddDoubleLine(L["Current Price"], "|cffffffff" .. GetMoneyString(lastPrice.price, true) .. "|r");
	
	if(lastPrice.priceDiff ~= nil) then
		local priceChange = math.abs(lastPrice.priceDiff);
		local percentChange = Addon:GetPercentDifference(lastPrice.price + lastPrice.priceDiff, lastPrice.price);
		
		local changePrefix = Addon:GetChangeColor(lastPrice.priceDiff);
		
		tooltip:AddDoubleLine(L["Last Change"],
			string.format("%s%s|r (%s%.1f%%|r)",
				changePrefix, GetMoneyString(priceChange, true),
				changePrefix, percentChange
			)
		);
		
		tooltip:AddDoubleLine(" ", string.format(L["%s ago"], Addon:FormatTime(time() - lastPrice.time)));
	end
	
	tooltip:AddLine(" ");
	
	local tokenPriceRealMoney, realPrice, realCurrency = Addon:GetRealMoneyPrice(lastPrice.price);
	tooltip:AddDoubleLine(
		string.format("%s (|cffffffff%.2f|r %s)", L["Real Price"], tokenPriceRealMoney, realCurrency),
		string.format("|cffffffff%.3f|r %s / |cffffffff%s|r", realPrice, realCurrency, GetMoneyString(100000000, true)));
		
	local timeToSell = Addon:GetTimeLeftString();
	tooltip:AddDoubleLine(L["Average Sell Time"], string.format("|cffffffff%s|r", timeToSell));
	
	local redeemPrice, relativeRedeemPrice, realCurrency = Addon:GetBattleNetRedeemPrice(lastPrice.price);
	if(redeemPrice) then
		tooltip:AddLine(" ");
		tooltip:AddDoubleLine(
			string.format("%s (|cffffffff%.2f|r %s)", L["Battle.net Balance"], redeemPrice, realCurrency),
			string.format("|cffffffff%.3f|r %s / |cffffffff%s|r", relativeRedeemPrice, realCurrency, GetMoneyString(100000000, true)));
		
		if(self.db.global.showCommonServices) then
			local servicePricesInGold, servicePrices, realCurrency = Addon:GetServicePrices(lastPrice.price);
			if(servicePricesInGold) then
				tooltip:AddLine(" ");
				tooltip:AddLine(L["Common Service Prices in Gold"]);
				tooltip:AddDoubleLine(
					string.format("|cffffffff%s|r (|cffffffff%.2f|r %s)", L["Level Boost"], servicePrices.levelBoost, realCurrency),
					string.format("|cffffffff%s|r", GetMoneyString(servicePricesInGold.levelBoost, true))
				);
				tooltip:AddDoubleLine(
					string.format("|cffffffff%s|r (|cffffffff%.2f|r %s)", L["Faction Change"], servicePrices.factionChange, realCurrency),
					string.format("|cffffffff%s|r ", GetMoneyString(servicePricesInGold.factionChange, true))
				);
				tooltip:AddDoubleLine(
					string.format("|cffffffff%s|r (|cffffffff%.2f|r %s)", L["Character Transfer"], servicePrices.characterTransfer, realCurrency),
					string.format("|cffffffff%s|r ", GetMoneyString(servicePricesInGold.characterTransfer, true))
				);
				tooltip:AddDoubleLine(
					string.format("|cffffffff%s|r (|cffffffff%.2f|r %s)", L["Race Change"], servicePrices.raceChange, realCurrency),
					string.format("|cffffffff%s|r ", GetMoneyString(servicePricesInGold.raceChange, true))
				);
				tooltip:AddDoubleLine(
					string.format("|cffffffff%s|r (|cffffffff%.2f|r %s)", L["Appearance Change"], servicePrices.appearanceChange, realCurrency),
					string.format("|cffffffff%s|r ", GetMoneyString(servicePricesInGold.appearanceChange, true))
				);
				tooltip:AddDoubleLine(
					string.format("|cffffffff%s|r (|cffffffff%.2f|r %s)", L["Name Change"], servicePrices.nameChange, realCurrency),
					string.format("|cffffffff%s|r ", GetMoneyString(servicePricesInGold.nameChange, true))
				);
			end
		end
	end
	
	local highPrice, lowPrice = Addon:GetPeaks();
	if(highPrice or lowPrice) then
		tooltip:AddLine(" ");
		tooltip:AddLine(L["Recorded Peaks within 48 hr"]);
		
		local diffPrefix = ""
		local highPercentDiff, highDiffSign = Addon:GetPercentDifference(lastPrice.price, highPrice.price);
		tooltip:AddDoubleLine(L["Highest"],
			string.format("|cffffffff%s|r (%s%s %s%.1f%%|r)",
				GetMoneyString(highPrice.price, true), Addon:GetChangeColor(highDiffSign), GetMoneyString(highPrice.price - lastPrice.price, true), Addon:GetChangeColor(highDiffSign), highPercentDiff)
		);

		local lowPercentDiff, lowDiffSign = Addon:GetPercentDifference(lastPrice.price, lowPrice.price);
		tooltip:AddDoubleLine(L["Lowest"],
			string.format("|cffffffff%s|r (%s%s %s%.1f%%|r)",
				GetMoneyString(lowPrice.price, true), Addon:GetChangeColor(lowDiffSign), GetMoneyString(math.abs(lowPrice.price - lastPrice.price), true), Addon:GetChangeColor(lowDiffSign), lowPercentDiff)
		);
		
		tooltip:AddLine(" ");
		tooltip:AddLine(string.format("|cffaaaaaa%s|r", L["Note these values are only updated while logged in."]));
	end
end

function Addon:GetAnchors(frame)
	local B, T = "BOTTOM", "TOP";
	local x, y = frame:GetCenter();
	
	if(y < _G.GetScreenHeight() / 2) then
		return B, T;
	else
		return T, B;
	end
end

function Addon:CreateBroker()
	Addon.module = LibDataBroker:NewDataObject(ADDON_NAME, {
		type = "data source",
		label = L["TokenPrice"],
		text = "",
		icon = MODULE_ICON_PATH,
		OnClick = function(frame, button)
			if(button == "RightButton") then
				GameTooltip:Hide();
				Addon:OpenContextMenu(frame);
			end
		end,
		OnEnter = function(frame)
			GameTooltip:ClearLines();
			GameTooltip:ClearAllPoints();
			GameTooltip:SetOwner(frame, "ANCHOR_PRESERVE");
			
			local point, relativePoint = Addon:GetAnchors(frame);
			
			GameTooltip:SetPoint(point, frame, relativePoint, 0, 0);
			
			Addon:SetTooltipText(GameTooltip);
			GameTooltip:Show();
			
			Addon.tooltip_open = true;
		end,
		OnLeave = function(frame)
			GameTooltip:Hide();
			Addon.tooltip_open = false;
		end,
	})
end

function Addon:UpdateBrokerText()
	if(not Addon.module or not Addon.enabled) then return end
	
	local brokerText = {};
	
	local lastPrice = Addon:GetLastPrice();
	local formattedGold = Addon:FormatGoldString(lastPrice.price, self.db.global.useLiteral);
	tinsert(brokerText, formattedGold);
	
	if(lastPrice.priceDiff ~= nil and self.db.global.showPercentChange) then
		local priceChange = math.abs(lastPrice.priceDiff);
		local percentChange = Addon:GetPercentDifference(lastPrice.price + lastPrice.priceDiff, lastPrice.price);
		
		local changePrefix = Addon:GetChangeColor(lastPrice.priceDiff);
		
		tinsert(brokerText, string.format("%s%.1f%%|r", changePrefix, percentChange));
	end
	
	Addon.module.text = table.concat(brokerText, " ");
end

function Addon:GetLastPrice()
	return self.db.global.marketPriceData[#self.db.global.marketPriceData];
end

function Addon:InitializeUpdater()
	local active, pollTime = C_WowTokenPublic.GetCommerceSystemStatus();
	if(active and pollTime > 0) then
		Addon.ticker = Addon:NewTicker(pollTime, Addon.UpdateMarketPrice);
		Addon.pollTime = pollTime;
		Addon.enabled = true;
		
		Addon:UpdateMarketPrice();
	else
		Addon.module.text = L["Unavailable"];
		
		Addon.ticker = nil;
		Addon.enabled = false;
	end
end

function Addon:GetTimeLeftString()
	local _, duration = C_WowTokenPublic.GetCurrentMarketPrice();
	local timeToSellString;
	if (duration == 1) then
		timeToSellString = AUCTION_TIME_LEFT1_DETAIL;
	elseif (duration == 2) then
		timeToSellString = AUCTION_TIME_LEFT2_DETAIL;
	elseif (duration == 3) then
		timeToSellString = AUCTION_TIME_LEFT3_DETAIL;
	else
		timeToSellString = AUCTION_TIME_LEFT4_DETAIL;
	end
	return timeToSellString;
end

function Addon:TOKEN_MARKET_PRICE_UPDATED()
	local currentTime = time();
	local currentPrice = C_WowTokenPublic.GetCurrentMarketPrice();
	
	if(currentPrice) then
		local priceDiff, timeDiff;
		local previousPrice = Addon:GetLastPrice();
		if(previousPrice) then
			priceDiff = currentPrice - previousPrice.price;
			timeDiff = currentTime - previousPrice.time;
		end
		
		if(priceDiff ~= 0) then
			tinsert(self.db.global.marketPriceData, {
				price 		= currentPrice,
				priceDiff 	= priceDiff,
				
				time 		= currentTime,
				timeDiff	= timeDiff,
			});
		end
		
		self.db.global.lastUpdate = currentTime;
	end
	
	Addon:UpdateBrokerText();
	
	-- print("EVENT CALLBACK");
end

function Addon:GetPeaks()
	local timeLimit = time() - 48 * 3600;
	
	local highPrice, lowPrice;
	
	for id = #self.db.global.marketPriceData, 1, -1 do
		local data = self.db.global.marketPriceData[id];
		
		if(data.time < timeLimit) then break end
		
		if(highPrice == nil or highPrice.price < data.price) then
			highPrice = data;
		end
		
		if(lowPrice == nil or lowPrice.price > data.price) then
			lowPrice = data;
		end
	end
	
	return highPrice, lowPrice;
end

function Addon:GetPriceChange(time)
	local timeLimit = time() - time;
	
	local highPrice, lowPrice;
	
	for id = #self.db.global.marketPriceData, 1, -1 do
		local data = self.db.global.marketPriceData[id];
		
		if(data.time < timeLimit) then break end
		
		if(highPrice == nil or highPrice.price < data.price) then
			highPrice = data;
		end
		
		if(lowPrice == nil or lowPrice.price > data.price) then
			lowPrice = data;
		end
	end
end

function Addon:UpdateMarketPrice()
	C_WowTokenPublic.UpdateMarketPrice();
	Addon.nextUpdate = time() + Addon.pollTime;
end

function Addon:CancelTicker(ticker)
	ticker._cancelled = true;
end

function Addon:NewTicker(duration, callback, iterations)
	local ticker = {};
	ticker._remainingIterations = iterations;
	ticker._callback = function()
		if ( not ticker._cancelled ) then
			callback(ticker);

			--Make sure we weren't cancelled during the callback
			if ( not ticker._cancelled ) then
				if ( ticker._remainingIterations ) then
					ticker._remainingIterations = ticker._remainingIterations - 1;
				end
				if ( not ticker._remainingIterations or ticker._remainingIterations > 0 ) then
					C_Timer.After(duration, ticker._callback);
				end
			end
		end
	end;

	C_Timer.After(duration, ticker._callback);
	return ticker;
end

local DAY_ABBR, HOUR_ABBR = gsub(DAY_ONELETTER_ABBR, "%%d%s*", ""), gsub(HOUR_ONELETTER_ABBR, "%%d%s*", "");
local MIN_ABBR, SEC_ABBR = gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", ""), gsub(SECOND_ONELETTER_ABBR, "%%d%s*", "");

local DHMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local  HMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local   MS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR, "%02d", SEC_ABBR)
local    S = format("|cffffffff%s|r|cffffcc00%s|r", "%d", SEC_ABBR)

local DH   = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR)
local  HM  = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR)

function Addon:FormatTime(t, short)
	if not t then return end

	local d, h, m, s = floor(t / 86400), floor((t % 86400) / 3600), floor((t % 3600) / 60), floor(t % 60)
	
	if d > 0 then
		return short and format(DH, d, h) or format(DHMS, d, h, m, s)
	elseif h > 0 then
		return short and format(HM, h, m) or format(HMS, h, m ,s)
	elseif m > 0 then
		return format(MS, m, s)
	else
		return format(S, s)
	end
end
