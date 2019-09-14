-- 
-- GlobalCompany - AddOn - SoilCompaction
-- 
-- @Interface: 
-- @Author: LS-Modcompany / kevink98
-- @Date: 
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 ():
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 
-- ToDo:
-- 

GC_SoilCompaction = {}

GC_SoilCompaction.SOILCOMPACTION_NONE = 0
GC_SoilCompaction.SOILCOMPACTION_CULTIVATORS = 1
GC_SoilCompaction.SOILCOMPACTION_DISCHARROWS = 2
GC_SoilCompaction.SOILCOMPACTION_POWERHARROWS = 3
GC_SoilCompaction.SOILCOMPACTION_PLOW = 4

GC_SoilCompaction.SOILCOMPACTION_CULTIVATORS_FACTOR = 50
GC_SoilCompaction.SOILCOMPACTION_DISCHARROWS_FACTOR = 25
GC_SoilCompaction.SOILCOMPACTION_POWERHARROWS_FACTOR = 25
GC_SoilCompaction.SOILCOMPACTION_PLOW_FACTOR = 75

GC_SoilCompaction.SOILCOMPACTION_COMPACT_TIME_MIN = 0
GC_SoilCompaction.SOILCOMPACTION_COMPACT_TIME_MAX = 2

GC_SoilCompaction.SOILCOMPACTION_COMPACT_VALUE_MIDDLE = 50

GC_SoilCompaction.SOILCOMPACTION_COMPACT_MAX_LOSS_FACTOR = 0.3

GC_SoilCompaction.SOILCOMPACTION_COMPACT_FACTOR_PER_HOUR = 2
GC_SoilCompaction.SOILCOMPACTION_COMPACT_FACTOR_SEASONS_PER_HOUR = 2

GC_SoilCompaction.debugIndex = g_company.debug:registerScriptName("GC_SoilCompaction")

local GC_SoilCompaction_mt = Class(GC_SoilCompaction)

function GC_SoilCompaction:new(mission)
    local self = {}
    setmetatable(self, GC_SoilCompaction_mt)
    self.debugData = g_company.debug:getDebugData(GC_SoilCompaction.debugIndex, g_company);

    self:loadText()

    self.mission = mission
    self.terrainSize = self.mission.terrainSize

    self:loadFromXML()

    local createNewBitmap = false
    self.bitmap_soilCompaction, createNewBitmap = g_company.bitmapManager:loadBitMap("SoilCompaction", "SoilCultivation_soilcompaction.grle", 16, true)

    local terrainDetailId = self.mission.terrainDetailId
    local map_soilCompaction = g_company.bitmapManager:getBitmapById(self.bitmap_soilCompaction)

    self.modifiers = {}
    self.modifiers.modifier = DensityMapModifier:new(map_soilCompaction.map, 0, map_soilCompaction.numChannels)
    self.modifiers.filter = DensityMapFilter:new(self.modifiers.modifier)

    self.modifiers.timerModifier = DensityMapModifier:new(map_soilCompaction.map, 0, 2)
    self.modifiers.timerFilter = DensityMapFilter:new(self.modifiers.timerModifier)

    self.modifiers.valueModifier = DensityMapModifier:new(map_soilCompaction.map, 2, 7)
    self.modifiers.valueFilter = DensityMapFilter:new(self.modifiers.valueModifier)

    self.modifiers.valueSowingModifier = DensityMapModifier:new(map_soilCompaction.map, 9, 7)
    self.modifiers.valueSowingFilter = DensityMapFilter:new(self.modifiers.valueSowingModifier)

    if createNewBitmap then
        self.modifiers.valueModifier:executeSet(GC_SoilCompaction.SOILCOMPACTION_COMPACT_VALUE_MIDDLE, self.modifiers.filter, self.modifiers.valueFilter)
        self.modifiers.valueSowingModifier:executeSet(GC_SoilCompaction.SOILCOMPACTION_COMPACT_VALUE_MIDDLE, self.modifiers.filter, self.modifiers.valueSowingFilter)
    end

    self.job_id_setTimer = g_company.jobManager:addJob_Map(self.job_setTimer, self, self.terrainSize, map_soilCompaction.mapSize, 64, 64)
    self.job_id_setValue = g_company.jobManager:addJob_Map(self.job_setValue, self, self.terrainSize, map_soilCompaction.mapSize, 64, 64)
        
    local store_updateCultivatorArea = FSDensityMapUtil.updateCultivatorArea
    FSDensityMapUtil.updateCultivatorArea = function (...)
		local realArea, area = store_updateCultivatorArea(...)
		GC_SoilCompaction.updateCultivatorArea(...)
		return realArea, area
    end;

    local store_updatePlowArea = FSDensityMapUtil.updatePlowArea
    FSDensityMapUtil.updatePlowArea = function (...)
		local realArea, area = store_updatePlowArea(...)
		GC_SoilCompaction.updatePlowArea(...)
		return realArea, area
    end;

    local store_updateSowingArea= FSDensityMapUtil.updateSowingArea
    FSDensityMapUtil.updateSowingArea = function (...)
		local realArea, area = store_updateSowingArea(...)
		GC_SoilCompaction.updateSowingArea(...)
		return realArea, area
    end;

    local store_updateDirectSowingArea = FSDensityMapUtil.updateDirectSowingArea
    FSDensityMapUtil.updateDirectSowingArea = function (...)
		local realArea, area = store_updateDirectSowingArea(...)
		GC_SoilCompaction.updateDirectSowingArea(...)
		return realArea, area
    end;
    
    local store_cutFruitArea = FSDensityMapUtil.cutFruitArea
    FSDensityMapUtil.cutFruitArea = function (...)
		local realArea, area, sprayFactor, plowFactor, limeFactor, weedFactor, growthState, growthStateArea, terrainDetailPixelsSum = store_cutFruitArea(...)
		GC_SoilCompaction.cutFruitArea(realArea, ...)
		return realArea, area, sprayFactor, plowFactor, limeFactor, weedFactor, growthState, growthStateArea, terrainDetailPixelsSum
    end;
    
    FSBaseMission.getHarvestScaleMultiplier = Utils.overwrittenFunction(FSBaseMission.getHarvestScaleMultiplier, GC_SoilCompaction.getHarvestScaleMultiplier)
    
	g_currentMission.environment:addHourChangeListener(self);	
    
    return self
end

function GC_SoilCompaction:setNextCultivatorTyp(typ)
    self.currentCultivatorTyp = typ;
end

function GC_SoilCompaction:updateCompactArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    self.modifiers.modifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
    self.modifiers.timerModifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
   
    self.modifiers.timerFilter:setValueCompareParams("equal", GC_SoilCompaction.SOILCOMPACTION_COMPACT_TIME_MIN)
    local _, area, totalArea = self.modifiers.timerModifier:executeGet(self.modifiers.filter, self.modifiers.timerFilter)
    if area > 0 then        
        self.modifiers.valueModifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
        for i = 1, 100 do
            self.modifiers.valueFilter:setValueCompareParams("equal", i)   
            if self.currentCultivatorTyp == GC_SoilCompaction.SOILCOMPACTION_CULTIVATORS then
                self.modifiers.valueModifier:executeSet(math.max(i - GC_SoilCompaction.SOILCOMPACTION_CULTIVATORS_FACTOR, 0), self.modifiers.timerFilter, self.modifiers.valueFilter)
            elseif self.currentCultivatorTyp == GC_SoilCompaction.SOILCOMPACTION_POWERHARROWS then
                self.modifiers.valueModifier:executeSet(math.max(i - GC_SoilCompaction.SOILCOMPACTION_POWERHARROWS_FACTOR, 0), self.modifiers.timerFilter, self.modifiers.valueFilter)
            elseif self.currentCultivatorTyp == GC_SoilCompaction.SOILCOMPACTION_DISCHARROWS then
                self.modifiers.valueModifier:executeSet(math.max(i - GC_SoilCompaction.SOILCOMPACTION_DISCHARROWS_FACTOR, 0), self.modifiers.timerFilter, self.modifiers.valueFilter)
            elseif self.currentCultivatorTyp == GC_SoilCompaction.SOILCOMPACTION_PLOW then
                self.modifiers.valueModifier:executeSet(math.max(i - GC_SoilCompaction.SOILCOMPACTION_PLOW_FACTOR, 0), self.modifiers.timerFilter, self.modifiers.valueFilter)
            end
        end
        self.modifiers.timerModifier:executeSet(GC_SoilCompaction.SOILCOMPACTION_COMPACT_TIME_MAX, self.modifiers.filter, self.modifiers.timerFilter)
    end 
    self:setNextCultivatorTyp(GC_SoilCompaction.SOILCOMPACTION_NONE)
end

function GC_SoilCompaction:setCurrentStateToSawing(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    self.modifiers.modifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
    self.modifiers.valueModifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
    self.modifiers.valueSowingModifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
   
    local sumArea = 0
    for i = 1, 100 do
        self.modifiers.valueFilter:setValueCompareParams("equal", i)   
        local _, area, totalArea = self.modifiers.valueModifier:executeGet(self.modifiers.filter, self.modifiers.valueFilter)
        if area > 0 then   
            self.modifiers.valueSowingModifier:executeSet(i, self.modifiers.valueFilter)

            sumArea = sumArea + area
            if sumArea == totalArea then
                break
            end
        end
    end
end

function GC_SoilCompaction.updateCultivatorArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, commonForced, angle, blockedSprayTypeIndex, setsWeeds)
    g_company.addOnSoilCultivation.soilCompaction:updateCompactArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
end

function GC_SoilCompaction.updatePlowArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, commonForced, angle, blockedSprayTypeIndex, setsWeeds)
    g_company.addOnSoilCultivation.soilCompaction:setNextCultivatorTyp(GC_SoilCompaction.SOILCOMPACTION_PLOW)
    g_company.addOnSoilCultivation.soilCompaction:updateCompactArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
end

function GC_SoilCompaction.updateDirectSowingArea(fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, commonForced, angle, blockedSprayTypeIndex, setsWeeds)
    g_company.addOnSoilCultivation.soilCompaction:setNextCultivatorTyp(GC_SoilCompaction.SOILCOMPACTION_DISCHARROWS)
    g_company.addOnSoilCultivation.soilCompaction:updateCompactArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    g_company.addOnSoilCultivation.soilCompaction:setCurrentStateToSawing(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
end

function GC_SoilCompaction.updateSowingArea(fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, commonForced, angle, blockedSprayTypeIndex, setsWeeds)
    g_company.addOnSoilCultivation.soilCompaction:setCurrentStateToSawing(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
end

function GC_SoilCompaction.cutFruitArea(realArea, fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, destroySpray, destroySeedingWidth, useMinForageState, excludedSprayType, setsWeeds)
    if realArea > 0 then
        local compaction = g_company.addOnSoilCultivation.soilCompaction
        compaction.modifiers.modifier:setParallelogramUVCoords(startWorldX / compaction.terrainSize + 0.5, startWorldZ / compaction.terrainSize + 0.5, widthWorldX / compaction.terrainSize + 0.5, widthWorldZ / compaction.terrainSize + 0.5, heightWorldX / compaction.terrainSize + 0.5, heightWorldZ / compaction.terrainSize + 0.5, "ppp")
        compaction.modifiers.valueModifier:setParallelogramUVCoords(startWorldX / compaction.terrainSize + 0.5, startWorldZ / compaction.terrainSize + 0.5, widthWorldX / compaction.terrainSize + 0.5, widthWorldZ / compaction.terrainSize + 0.5, heightWorldX / compaction.terrainSize + 0.5, heightWorldZ / compaction.terrainSize + 0.5, "ppp")
        compaction.modifiers.valueSowingModifier:setParallelogramUVCoords(startWorldX / compaction.terrainSize + 0.5, startWorldZ / compaction.terrainSize + 0.5, widthWorldX / compaction.terrainSize + 0.5, widthWorldZ / compaction.terrainSize + 0.5, heightWorldX / compaction.terrainSize + 0.5, heightWorldZ / compaction.terrainSize + 0.5, "ppp")
        
        local average = 0
        local fullArea = 0
        for i = 1, 100 do
            compaction.modifiers.valueSowingFilter:setValueCompareParams("equal", i)   
            local _, area, totalArea = compaction.modifiers.valueSowingModifier:executeGet(compaction.modifiers.filter, compaction.modifiers.valueSowingFilter)

            if area > 0 then
                average = average + (i * area)
            end
            fullArea = totalArea
            
            if compaction.fruitIdToFactor[fruitIndex] ~= nil then
                compaction.modifiers.valueFilter:setValueCompareParams("equal", i)                   
                compaction.modifiers.valueModifier:executeSet(i + compaction.fruitIdToFactor[fruitIndex], compaction.modifiers.valueFilter, compaction.modifiers.valueSowingFilter)
            end
            compaction.modifiers.valueSowingModifier:executeSet(101, compaction.modifiers.valueSowingFilter)
        end
        compaction.lastCutFactor = average / fullArea            
    end
end

function GC_SoilCompaction:hourChanged()
    g_company.jobManager:startJob(self.job_id_setTimer)
    g_company.jobManager:startJob(self.job_id_setValue)
end

function GC_SoilCompaction:onFieldDataUpdateFinished(display)        
    local bitmap = g_company.bitmapManager:getBitmapById(self.bitmap_soilCompaction);
    
    local x, _, z = getWorldTranslation(getCamera(0))
    local worldToDensityMap = bitmap.mapSize / self.terrainSize
    local xi = math.floor((x + self.terrainSize * 0.5) * worldToDensityMap)
    local zi = math.floor((z + self.terrainSize * 0.5) * worldToDensityMap)

    local value = getBitVectorMapPoint(bitmap.map, xi, zi, 0, bitmap.numChannels)
    local _, bitsStr = g_company.utils.convertNumberToBits(value, bitmap.numChannels)
    
    local percent = g_company.utils.getValueOfBits(bitsStr, 2, 7)
    local sowingPercent = g_company.utils.getValueOfBits(bitsStr, 9, 7)
    local hours = g_company.utils.getValueOfBits(bitsStr, 0, 2)

    if sowingPercent == 101 then
        sowingPercent = "-"
    end
      
    display:addCustomText(self.text.fieldInfo_compaction, string.format("%s %%", percent))
    display:addCustomText(self.text.fieldInfo_sowingCompaction, string.format("%s %%", sowingPercent))

    if hours == 0 then
        display:addCustomText(self.text.fieldInfo_nextCompaction1, self.text.fieldInfo_nextCompactionNow)
    elseif hours == 1 then
        display:addCustomText(self.text.fieldInfo_nextCompaction2, string.format("%s %s", hours, self.text.unit_hour))
    else
        display:addCustomText(self.text.fieldInfo_nextCompaction2, string.format("%s %s", hours, self.text.unit_hours))
    end
end

function GC_SoilCompaction.getHarvestScaleMultiplier(mission, superFunc, fruitType, sprayFactor, plowFactor, limeFactor, weedFactor)
    local multiplier = superFunc(mission, fruitType, sprayFactor, plowFactor, limeFactor, weedFactor)
    if g_company.addOnSoilCultivation.soilCompaction.lastCutFactor ~= nil then
        multiplier = multiplier - g_company.addOnSoilCultivation.soilCompaction.lastCutFactor * 0.01 * GC_SoilCompaction.SOILCOMPACTION_COMPACT_MAX_LOSS_FACTOR
    end  

    return multiplier
end

function GC_SoilCompaction:loadText()     
    self.text = {}
    self.text.fieldInfo_compaction = g_company.languageManager:getText("GlobalCompanyAddOn_SoilCultivation_Compaction_FieldInfo_compaction")
    self.text.fieldInfo_sowingCompaction = g_company.languageManager:getText("GlobalCompanyAddOn_SoilCultivation_Compaction_FieldInfo_sowingCompaction")
    self.text.fieldInfo_nextCompaction1 = g_company.languageManager:getText("GlobalCompanyAddOn_SoilCultivation_Compaction_FieldInfo_nextCompaction1")
    self.text.fieldInfo_nextCompaction2 = g_company.languageManager:getText("GlobalCompanyAddOn_SoilCultivation_Compaction_FieldInfo_nextCompaction2")
    self.text.fieldInfo_nextCompactionNow = g_company.languageManager:getText("GlobalCompanyAddOn_SoilCultivation_Compaction_FieldInfo_nextCompactionNow")
    self.text.unit_hour = g_company.languageManager:getText("GlobalCompanyAddOn_SoilCultivation_unit_hour")
    self.text.unit_hours = g_company.languageManager:getText("GlobalCompanyAddOn_SoilCultivation_unit_hours")
end

function GC_SoilCompaction:loadFromXML()
    local xmlFile = loadXMLFile("compaction", string.format("%s/%s", g_company.addOnSoilCultivation.modDirectory, "Compaction.xml"))
    
    self.fruitIdToFactor = {};

    local i = 0
    while true do
        local key = string.format("compaction.factors.factor(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break;
        end
        
        local factor = getXMLInt(xmlFile, key .. "#percent")
        local filltypes = getXMLString(xmlFile, key .. "#filltypes")
        
        if factor ~= nil and filltypes ~= nil and filltypes ~= "" then
            local splitted = g_company.utils.splitString(filltypes, " ")
            for _,name in pairs(splitted) do
                local fruitId = g_fruitTypeManager.nameToIndex[name]
                if fruitId ~= nil then
                    if self.fruitIdToFactor[fruitId] == nil then
                        self.fruitIdToFactor[fruitId] = factor
                    else
                        g_company.debug:writeError(self.debugData, "Filltype %s already defined", name)
                    end
                else
                    g_company.debug:writeError(self.debugData, "Invalid filltype %s", name)
                end
            end
        end

        i = i + 1
    end
    
    delete(xmlFile)
end

function GC_SoilCompaction:job_setTimer(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    -- self.modifiers.timerModifier:setParallelogramUVCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, "ppp")    
    self.modifiers.timerModifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
    for i = 1, GC_SoilCompaction.SOILCOMPACTION_COMPACT_TIME_MAX do
        self.modifiers.timerFilter:setValueCompareParams("equal", i) 
        self.modifiers.timerModifier:executeSet(i-1, self.modifiers.timerFilter)
    end    
end

function GC_SoilCompaction:job_setValue(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    -- self.modifiers.valueModifier:setParallelogramUVCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, "ppp")
    self.modifiers.valueModifier:setParallelogramUVCoords(startWorldX / self.terrainSize + 0.5, startWorldZ / self.terrainSize + 0.5, widthWorldX / self.terrainSize + 0.5, widthWorldZ / self.terrainSize + 0.5, heightWorldX / self.terrainSize + 0.5, heightWorldZ / self.terrainSize + 0.5, "ppp")
    for i = 99, 0, -1 do
        self.modifiers.valueFilter:setValueCompareParams("equal", i) 
        if g_seasons ~= nil then
            self.modifiers.valueModifier:executeSet(math.min(i + GC_SoilCompaction.SOILCOMPACTION_COMPACT_FACTOR_SEASONS_PER_HOUR, 100), self.modifiers.valueFilter)
        else
            self.modifiers.valueModifier:executeSet(math.min(i + GC_SoilCompaction.SOILCOMPACTION_COMPACT_FACTOR_PER_HOUR, 100), self.modifiers.valueFilter)
        end
    end
end