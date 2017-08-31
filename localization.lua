local _, namespace = ...

local L = setmetatable({}, { __index = function(t, k)
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

namespace.L = L

local LOCALE = GetLocale()

if LOCALE:match("enUS") then
return end

if LOCALE == "deDE" then
	L["TokenPrice Options"] = "TokenPreis Optionen"
	L["Show percentage difference in broker"] = "Prozentwert im broker anzeigen."
    L["Show percentage difference color as buyer"] = "Prozentwert farbe als Käufer anzeigen."
	L["Use literal gold display"] = "verwende wörtliche Goldanzeige."
	L["Show service prices in gold"] = "zeige Dienstleistungspreise in Gold an."
	L["Currency Options"] = "Währungs Optionen"
    --
	L[" TokenPrice"] = " TokenPreis"
    L["Current Price"] = "aktueller Preis"
	L["Last Change"] = "letzte Änderung"
    L["%s ago"] = "vor %s"
    L["Real Price (|cffffffff%.2f|r %s)"] = "echter Preis (|cffffffff%.2f|r %s)"
    L["Average Sell Time"] = "Durchschnittliche Verkaufszeit"
    L["Battle.net Balance (|cffffffff%.2f|r %s)"] = "Battle.net Guthaben (|cffffffff%.2f|r %s)"
    L["Common Service Prices in Gold"] = "übliche Dienstleistungen in Gold"
    L["|cffffffffLevel Boost|r (|cffffffff%.2f|r %s)"] = "|cffffffffLevel Boost|r (|cffffffff%.2f|r %s)"
    L["|cffffffffFaction Change|r (|cffffffff%.2f|r %s)"] = "|cffffffffFraktionswechsel|r (|cffffffff%.2f|r %s)"
    L["|cffffffffCharacter Transfer|r (|cffffffff%.2f|r %s)"] = "|cffffffffCharaktertransfer|r (|cffffffff%.2f|r %s)"
    L["|cffffffffRace Change|r (|cffffffff%.2f|r %s)"] = "|cffffffffVolkswechsel|r (|cffffffff%.2f|r %s)"
    L["|cffffffffAppearance Change|r (|cffffffff%.2f|r %s)"] = "|cffffffffCharakteranpassung|r (|cffffffff%.2f|r %s)"
    L["|cffffffffName Change|r (|cffffffff%.2f|r %s)"] = "|cffffffffCharakterumbenennung|r (|cffffffff%.2f|r %s)"
    --
    L["Recorded Peaks within 48 hr"] = "Aufgenommene Spitzen innerhalb von 48 Stunden"
    --
    L["Highest"] = "höchste"
    L["Lowest"] = "unterste"
    L["|cffaaaaaaNote these values are only updated while logged in.|r"] = "|cffaaaaaaBeachte, dass diese Werte nur beim Spielen aktualisiert werden.|r"
    L["TokenPrice"] = "TokenPreis"
    L["Unavailable"] = "nicht verfügbar"
return end