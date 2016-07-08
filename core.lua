local ADDON_NAME, SHARED = ...;

local _G = getfenv(0);

local LibStub = LibStub;
local A = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = A;
SHARED[1] = A;

local LDB = LibStub:GetLibrary("LibDataBroker-1.1");
local AceDB = LibStub("AceDB-3.0");

local ICON_PATTERN_16 = "|T%s:16:16:0:0|t";
local MDB_ICON_PATH = "Interface\\Icons\\wow_token01";
local TEX_MDB_ICON = ICON_PATTERN_16:format(MDB_ICON_PATH);

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
};

local DAY_ABBR, HOUR_ABBR = gsub(DAY_ONELETTER_ABBR, "%%d%s*", ""), gsub(HOUR_ONELETTER_ABBR, "%%d%s*", "");
local MIN_ABBR, SEC_ABBR = gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", ""), gsub(SECOND_ONELETTER_ABBR, "%%d%s*", "");

local DHMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local  HMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local   MS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR, "%02d", SEC_ABBR)
local    S = format("|cffffffff%s|r|cffffcc00%s|r", "%d", SEC_ABBR)

local DH   = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR)
local  HM  = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR)

local function FormatTime(t, short)
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

function A:OnInitialize()
	
end

function A:OnEnable()
	local defaults = {
		global = {
			marketPriceData = {},
			lastUpdate = 0,
			currency = regionCurrency[A.region or "DERP"] or "USD",
			showPercentChange = true,
		}
	};
	
	self.db = AceDB:New("TokenPriceDB", defaults, true);
	
	A:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED");
	
	A:CreateBroker();
	A:InitializeUpdater();
	
	A.UpdaterFrame = CreateFrame("Frame"):SetScript("OnUpdate", A.OnUpdate);
end

function A:OnUpdate(elapsed)
	A.elapsed = (A.elapsed or 0) + elapsed;
	
	if(A.elapsed >= 1.0) then
		if(A.tooltip_open) then
			GameTooltip:ClearLines();
			-- A.Broker.OnTooltipShow(GameTooltip);
			A:SetTooltipText(GameTooltip);
			GameTooltip:Show();
		end
	end
end

function A:OnDisable()
		
end

function A:OpenContextMenu(parentFrame)
	if(not A.ContextMenu) then
		A.ContextMenu = CreateFrame("Frame", "TokenPriceContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	local contextMenuData = {
		{
			text = "TokenPrice Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Show Percentage Difference in Broker",
			func = function() self.db.global.showPercentChange = not self.db.global.showPercentChange; A:UpdateBrokerText(); end,
			checked = function() return self.db.global.showPercentChange; end,
			isNotRadio = true,
		},
		{
			text = "Conversion Currency",
			notCheckable = true,
			hasArrow = true,
			menuList = (function()
				local currencyList = {
					{
						text = "Currency Options", isTitle = true, notCheckable = true,
					},
				};
				
				for _, data in pairs(tokenPrice) do
					tinsert(currencyList, {
						text = data.name,
						func = function() self.db.global.currency = data.currency; CloseMenus(); end,
						checked = function() return self.db.global.currency == data.currency; end,
					});
				end
			
				return currencyList;
			end)(),
		},
	};
	
	A.ContextMenu:SetPoint("BOTTOM", parentFrame, "BOTTOM", 0, 5);
	EasyMenu(contextMenuData, A.ContextMenu, parentFrame, 0, 0, "MENU", 5);
end

function A:GetRealMoneyPrice(money)
	if(not money or money == 0) then return 0 end
	
	local gold = money / 10000;
	
	local pricedata = tokenPrice[self.db.global.currency];
	return pricedata.price / (gold / 1000), pricedata.currency;
end

local function sign(value)
	if(value >= 0) then return 1; end
	return -1;
end

function A:GetPercentDifference(price, otherPrice)
	return math.abs(1.0 - (otherPrice / price)) * 100, sign(otherPrice - price);
end

function A:GetChangeColor(value)
	if(not value) then return ""; end
		
	if(value >= 0) then
		return "|cff9efa38+";
	else
		return "|cfffa3d27-";
	end
	
	return "";
end

function A:SetTooltipText(tooltip)
	tooltip:AddLine(TEX_MDB_ICON .. " TokenPrice");
	tooltip:AddLine(" ");
	
	local lastPrice = A:GetLastPrice();
	tooltip:AddDoubleLine("Current Price", "|cffffffff" .. GetMoneyString(lastPrice.price, true) .. "|r");
	
	if(lastPrice.priceDiff ~= nil) then
		local priceChange = math.abs(lastPrice.priceDiff);
		local percentChange = A:GetPercentDifference(lastPrice.price + lastPrice.priceDiff, lastPrice.price);
		
		local changePrefix = A:GetChangeColor(lastPrice.priceDiff);
		
		tooltip:AddDoubleLine("Last Change",
			string.format("%s%s|r (%s%.1f%%|r)",
				changePrefix, GetMoneyString(priceChange, true),
				changePrefix, percentChange
			)
		);
		
		tooltip:AddDoubleLine(" ", string.format("%s ago", FormatTime(time() - lastPrice.time)));
	end
	
	local realPrice, realCurrency = A:GetRealMoneyPrice(lastPrice.price);
	tooltip:AddLine(" ");
	tooltip:AddDoubleLine("Real Price", string.format("|cffffffff%.3f|r %s / |cffffffff%s|r", realPrice, realCurrency, GetMoneyString(10000000, true)));
	
	local highPrice, lowPrice = A:GetPeaks();
	if(highPrice or lowPrice) then
		tooltip:AddLine(" ");
		tooltip:AddLine("Recorded Peaks within 48 hr");
		
		local diffPrefix = ""
		local highPercentDiff, highDiffSign = A:GetPercentDifference(lastPrice.price, highPrice.price);
		tooltip:AddDoubleLine("Highest",
			string.format("|cffffffff%s|r (%s%s %s%.1f%%|r)",
				GetMoneyString(highPrice.price, true), A:GetChangeColor(highDiffSign), GetMoneyString(highPrice.price - lastPrice.price, true), A:GetChangeColor(highDiffSign), highPercentDiff)
		);

		local lowPercentDiff, lowDiffSign = A:GetPercentDifference(lastPrice.price, lowPrice.price);
		tooltip:AddDoubleLine("Lowest",
			string.format("|cffffffff%s|r (%s%s %s%.1f%%|r)",
				GetMoneyString(lowPrice.price, true), A:GetChangeColor(lowDiffSign), GetMoneyString(math.abs(lowPrice.price - lastPrice.price), true), A:GetChangeColor(lowDiffSign), lowPercentDiff)
		);
	end
end

function A:CreateBroker()
	A.Broker = LDB:NewDataObject(ADDON_NAME, {
		type = "data source",
		label = "TokenPrice",
		text = "",
		icon = MDB_ICON_PATH,
		OnClick = function(frame, button)
			if(button == "RightButton") then
				GameTooltip:Hide();
				A:OpenContextMenu(frame);
			end
		end,
		OnEnter = function(frame)
			-- print(frame, frame:GetName());
			-- if not tooltip or not tooltip.AddLine then return end
			
			GameTooltip:ClearLines();
			GameTooltip:ClearAllPoints();
			GameTooltip:SetOwner(frame, "ANCHOR_PRESERVE");
			
			local point, relativePoint = "TOP", "BOTTOM";
			
			local _, framey = frame:GetCenter();
			local scale = UIParent:GetEffectiveScale();
			
			if(framey / scale <= GetScreenHeight() / 2) then
				point, relativePoint = "BOTTOM", "TOP";
			end
			
			GameTooltip:SetPoint(point, frame, relativePoint, 0, 0);
			
			A:SetTooltipText(GameTooltip);
			GameTooltip:Show();
			
			A.tooltip_open = true;
		end,
		OnLeave = function(frame)
			GameTooltip:Hide();
			A.tooltip_open = false;
		end,
	})
end

function A:UpdateBrokerText()
	if(not A.Broker or not A.enabled) then return end
	
	local brokerText = {};
	
	local lastPrice = A:GetLastPrice();
	tinsert(brokerText, GetMoneyString(lastPrice.price, true));
	
	if(lastPrice.priceDiff ~= nil and self.db.global.showPercentChange) then
		local priceChange = math.abs(lastPrice.priceDiff);
		local percentChange = A:GetPercentDifference(lastPrice.price + lastPrice.priceDiff, lastPrice.price);
		
		local changePrefix = A:GetChangeColor(lastPrice.priceDiff);
		
		tinsert(brokerText, string.format("%s%.1f%%|r", changePrefix, percentChange));
	end
	
	A.Broker.text = table.concat(brokerText, " ");
end

function A:GetLastPrice()
	return self.db.global.marketPriceData[#self.db.global.marketPriceData];
end

function A:InitializeUpdater()
	local active, pollTime = C_WowTokenPublic.GetCommerceSystemStatus();
	if(active and pollTime > 0) then
		A.ticker = A:NewTicker(pollTime, A.UpdateMarketPrice);
		A.pollTime = pollTime;
		A.enabled = true;
		
		A:UpdateMarketPrice();
	else
		A.Broker.text = "Unavailable";
		
		A.ticker = nil;
		A.enabled = false;
	end
end

function A:TOKEN_MARKET_PRICE_UPDATED()
	local currentTime = time();
	local currentPrice = C_WowTokenPublic.GetCurrentMarketPrice();
	
	if(currentPrice) then
		local priceDiff, timeDiff;
		local previousPrice = A:GetLastPrice();
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
	
	A:UpdateBrokerText();
	
	-- print("EVENT CALLBACK");
end

function A:GetPeaks()
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

function A:GetPriceChange(time)
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

function A:UpdateMarketPrice()
	C_WowTokenPublic.UpdateMarketPrice();
	A.nextUpdate = time() + A.pollTime;
	
	-- print("UPDATING THINGY");
end

function A:CancelTicker(ticker)
	ticker._cancelled = true;
end

function A:NewTicker(duration, callback, iterations)
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
