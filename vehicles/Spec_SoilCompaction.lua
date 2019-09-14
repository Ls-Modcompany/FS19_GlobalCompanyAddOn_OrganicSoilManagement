-- 
-- GlobalCompany - AddOn - ManureBarrelFix
-- 
-- @Interface: 1.4.1.0 b5332
-- @Author: LS-Modcompany / kevink98
-- @Date: 28.07.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (28.07.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
--      - fix missing attribute 'turnOffIfNotAllowed' on giants vehicles
-- 
-- ToDo:
-- 

Gc_Spec_SoilCompaction = {}

Gc_Spec_SoilCompaction.SOILCOMPACTION_NONE = 0
Gc_Spec_SoilCompaction.SOILCOMPACTION_CULTIVATORS = 1
Gc_Spec_SoilCompaction.SOILCOMPACTION_DISCHARROWS = 2
Gc_Spec_SoilCompaction.SOILCOMPACTION_POWERHARROWS = 3

function Gc_Spec_SoilCompaction.initSpecialization()
end

function Gc_Spec_SoilCompaction.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Cultivator, specializations)
end

function Gc_Spec_SoilCompaction.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", Gc_Spec_SoilCompaction)
end

function Gc_Spec_SoilCompaction.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processCultivatorArea",        Gc_Spec_SoilCompaction.processCultivatorArea)
end

function Gc_Spec_SoilCompaction:onPostLoad(savegame)
    local item = g_storeManager:getItemByXMLFilename(self.configFileName)
    self.cultivatorTyp = Gc_Spec_SoilCompaction.SOILCOMPACTION_CULTIVATORS
    if item.categoryName == "DISCHARROWS" then
        self.cultivatorTyp = Gc_Spec_SoilCompaction.SOILCOMPACTION_DISCHARROWS
    elseif item.categoryName == "POWERHARROWS" then
        self.cultivatorTyp = Gc_Spec_SoilCompaction.SOILCOMPACTION_POWERHARROWS
    end
end

function Gc_Spec_SoilCompaction:processCultivatorArea(superFunc, workArea, dt)
    g_company.addOnSoilCultivation.soilCompaction:setNextCultivatorTyp(self.cultivatorTyp)
    return superFunc(self, workArea, dt)
end