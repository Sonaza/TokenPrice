------------------------------------------------------------
-- TokenPrice by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = Addon;

local LibDataBroker = LibStub("LibDataBroker-1.1");
local AceDB         = LibStub("AceDB-3.0");
local LibRealmInfo  = LibStub("LibRealmInfo");

local ICON_PATTERN_16 = "|T%s:16:16:0:0|t";
local MODULE_ICON_PATH = "Interface\\Icons\\wow_token01";
local TEX_MODULE_ICON = ICON_PATTERN_16:format(MODULE_ICON_PATH);

local tokenPrice = {
	["EUR"] = { name = "Euro", 				price = 20, 	currency = "EUR" },
	["GBP"] = { name = "British Pound", 	price = 15, 	currency = "GBP" },
	["USD"] = { name = "US Dollar", 		price = 20, 	currency = "USD" },
	["CNY"]	= { name = "Chinese Yuan", 		price = 30, 	currency = "CNY" },
	["TWD"]	= { name = "New Taiwan Dollar", price = 500, 	currency = "TWD" },
	["KRW"]	= { name = "South Korean Won", 	price = 22000, 	currency = "KRW" },
};

local regionCurrency = {
	["EU"] = "EUR",
	["US"] = "USD",
	["KR"] = "KRW",
	["TW"] = "TWD",
	["CN"] = "CNY",
};

function Addon:OnEnable()
	local playerRegion = LibRealmInfo:GetCurrentRegion() or "US";
	
	local defaults = {
		global = {
			marketPriceData = {},
			lastUpdate = 0,
			currency = regionCurrency[playerRegion] or "USD",
			showPercentChange = true,
			useLiteral = false,
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
			text = "TokenPrice Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Show percentage difference in broker",
			func = function() self.db.global.showPercentChange = not self.db.global.showPercentChange; Addon:UpdateBrokerText(); end,
			checked = function() return self.db.global.showPercentChange; end,
			isNotRadio = true,
		},
		{
			text = "Use literal gold display",
			func = function() self.db.global.useLiteral = not self.db.global.useLiteral; Addon:UpdateBrokerText(); end,
			checked = function() return self.db.global.useLiteral; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Currency Options", isTitle = true, notCheckable = true,
		},
	};
	
	for _, data in pairs(tokenPrice) do
		tinsert(contextMenuData, {
			text = data.name,
			func = function() self.db.global.currency = data.currency; CloseMenus(); end,
			checked = function() return self.db.global.currency == data.currency; end,
		});
	end
	
	Addon.ContextMenu:SetPoint("BOTTOM", parentFrame, "BOTTOM", 0, 5);
	EasyMenu(contextMenuData, Addon.ContextMenu, parentFrame, 0, 0, "MENU", 5);
end

function Addon:GetRealMoneyPrice(money)
	if(not money or money == 0) then return 0 end
	
	local gold = money / 10000;
	
	local pricedata = tokenPrice[self.db.global.currency];
	return pricedata.price / (gold / 1000), pricedata.currency;
end

local function sign(value)
	if(value >= 0) then return 1; end
	return -1;
end

function Addon:GetPercentDifference(price, otherPrice)
	return math.abs(1.0 - (otherPrice / price)) * 100, sign(otherPrice - price);
end

function Addon:GetChangeColor(value)
	if(not value) then return ""; end
		
	if(value >= 0) then
		return "|cff9efa38+";
	else
		return "|cfffa3d27-";
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
	tooltip:AddLine(TEX_MODULE_ICON .. " TokenPrice");
	tooltip:AddLine(" ");
	
	local lastPrice = Addon:GetLastPrice();
	tooltip:AddDoubleLine("Current Price", "|cffffffff" .. GetMoneyString(lastPrice.price, true) .. "|r");
	
	if(lastPrice.priceDiff ~= nil) then
		local priceChange = math.abs(lastPrice.priceDiff);
		local percentChange = Addon:GetPercentDifference(lastPrice.price + lastPrice.priceDiff, lastPrice.price);
		
		local changePrefix = Addon:GetChangeColor(lastPrice.priceDiff);
		
		tooltip:AddDoubleLine("Last Change",
			string.format("%s%s|r (%s%.1f%%|r)",
				changePrefix, GetMoneyString(priceChange, true),
				changePrefix, percentChange
			)
		);
		
		tooltip:AddDoubleLine(" ", string.format("%s ago", Addon:FormatTime(time() - lastPrice.time)));
	end
	
	tooltip:AddLine(" ");
	
	local realPrice, realCurrency = Addon:GetRealMoneyPrice(lastPrice.price);
	tooltip:AddDoubleLine("Real Price", string.format("|cffffffff%.3f|r %s / |cffffffff%s|r", realPrice, realCurrency, GetMoneyString(10000000, true)));
	
	local timeToSell = Addon:GetTimeLeftString();
	tooltip:AddDoubleLine("Average Sell Time", string.format("|cffffffff%s|r", timeToSell));
	
	local highPrice, lowPrice = Addon:GetPeaks();
	if(highPrice or lowPrice) then
		tooltip:AddLine(" ");
		tooltip:AddLine("Recorded Peaks within 48 hr");
		
		local diffPrefix = ""
		local highPercentDiff, highDiffSign = Addon:GetPercentDifference(lastPrice.price, highPrice.price);
		tooltip:AddDoubleLine("Highest",
			string.format("|cffffffff%s|r (%s%s %s%.1f%%|r)",
				GetMoneyString(highPrice.price, true), Addon:GetChangeColor(highDiffSign), GetMoneyString(highPrice.price - lastPrice.price, true), Addon:GetChangeColor(highDiffSign), highPercentDiff)
		);

		local lowPercentDiff, lowDiffSign = Addon:GetPercentDifference(lastPrice.price, lowPrice.price);
		tooltip:AddDoubleLine("Lowest",
			string.format("|cffffffff%s|r (%s%s %s%.1f%%|r)",
				GetMoneyString(lowPrice.price, true), Addon:GetChangeColor(lowDiffSign), GetMoneyString(math.abs(lowPrice.price - lastPrice.price), true), Addon:GetChangeColor(lowDiffSign), lowPercentDiff)
		);
		
		tooltip:AddLine(" ");
		tooltip:AddLine("|cffaaaaaaNote these values are only updated while logged in.|r");
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
		label = "TokenPrice",
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
		Addon.module.text = "Unavailable";
		
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
