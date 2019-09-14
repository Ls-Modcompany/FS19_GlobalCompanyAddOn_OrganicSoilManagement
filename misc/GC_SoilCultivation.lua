-- 
-- GlobalCompany - AddOn - SoilCultivation
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

GC_SoilCultivation = {}
GC_SoilCultivation.version = "0.0.0.1"
GC_SoilCultivation.developerVersion = true

GC_SoilCultivation.modDirectory = g_currentModDirectory
GC_SoilCultivation.modName = g_currentModName

source(g_currentModDirectory .. "misc/GC_SoilCompaction.lua")

function GC_SoilCultivation.initGlobalCompany(customEnvironment, modName, baseDirectory, xmlFile, mission)
	if (g_company == nil) or (GC_SoilCultivation.isInitiated ~= nil) then
		return
	end

	GC_SoilCultivation.debugIndex = g_company.debug:registerScriptName("GC_SoilCultivation")
	GC_SoilCultivation.modName = customEnvironment
	GC_SoilCultivation.isInitiated = true

	g_company.addOnSoilCultivation = GC_SoilCultivation
    g_company.addInit(GC_SoilCultivation, GC_SoilCultivation.init)
    
    g_company.addOnSoilCultivation.mission = mission
end

function GC_SoilCultivation:init()
	--self.isServer = g_server ~= nil
	--self.isClient = g_dedicatedServerInfo == nil
	--self.isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer
	
	g_company.addOnSoilCultivation.soilCompaction = GC_SoilCompaction:new(g_company.addOnSoilCultivation.mission)
	
    g_company.gui:loadGuiTemplates(g_company.utils.createDirPath(GC_SoilCultivation.modName) .. "gui/guiTemplates.xml");
	g_company.gui:registerGui("gcAddOnOrganicSoilManagement", InputAction.GC_ORGANICSOILMANAGEMENT, OrganicSoilManagementGui, true, true);
	
    FieldInfoDisplay.onFieldDataUpdateFinished = Utils.appendedFunction(FieldInfoDisplay.onFieldDataUpdateFinished, GC_SoilCultivation.onFieldDataUpdateFinished)
end



function Vehicle:soilCultivaion_getSpecTable(name)
    return self["spec_" .. GC_SoilCultivation.modName .. "." .. name]
end

function Vehicle:soilCultivaion_getModName()
    return GC_SoilCultivation.modName
end

function Vehicle:soilCultivaion_getSpecSaveKey(key, specName)
    return ("%s.%s.%s"):format(key, GC_SoilCultivation.modName, specName)
end


function GC_SoilCultivation.onFieldDataUpdateFinished(display, data)
	if data == nil then
		return
	end

	display:clearCustomText()

	g_company.addOnSoilCultivation.soilCompaction:onFieldDataUpdateFinished(display)
end