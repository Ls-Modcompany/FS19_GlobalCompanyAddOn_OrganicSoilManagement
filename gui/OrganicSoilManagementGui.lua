--
-- GlobalCompany - Gui - AnimalShop
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 25.08.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (25.08.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
-- ToDo:
--
--
--


OrganicSoilManagementGui = {};
OrganicSoilManagementGui.xmlFilename = g_company.dir .. "gui/OrganicSoilManagementGui.xml";
OrganicSoilManagementGui.debugIndex = g_company.debug:registerScriptName("OrganicSoilManagementGui");

local OrganicSoilManagementGui_mt = Class(OrganicSoilManagementGui, GuiScreen);

function OrganicSoilManagementGui:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = OrganicSoilManagementGui_mt;
    end;
	local self = setmetatable({}, OrganicSoilManagementGui_mt);			
	return self;
end;

function OrganicSoilManagementGui:onOpen() 
    OrganicSoilManagementGui:superClass().onOpen(self);
    
    if self.currentPage == nil then
        self:setPage(1, self.page_1);
    end;
end;

function OrganicSoilManagementGui:onClose() 
    OrganicSoilManagementGui:superClass().onClose(self);
    
end;

function OrganicSoilManagementGui:onCreate() 
    OrganicSoilManagementGui:superClass().onCreate(self);

    self.texts.page_1 = g_company.languageManager:getText("GC_animalShop_page_1");
    self.texts.page_2_1 = g_company.languageManager:getText("GC_animalShop_page_2_1");
    self.texts.page_2_2 = g_company.languageManager:getText("GC_animalShop_page_2_2");
    self.texts.page_2_3 = g_company.languageManager:getText("GC_animalShop_page_2_3");
    self.texts.page_2_4 = g_company.languageManager:getText("GC_animalShop_page_2_4");

end;

function OrganicSoilManagementGui:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func};
end;

function OrganicSoilManagementGui:setData(animalShop)
    self.animalShop = animalShop;
    
    
end
