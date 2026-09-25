@isTest
private class ConfigManagerTest {

    @isTest
    static void getActiveConfigValuesTest() {
        Test.startTest();
        OAuth_Config__mdt activeConfig = [
            SELECT Client_Id__c, Client_Secret__c, Redirect_Url__c, Redirect_Url_lightning__c, Redirect_Url_community__c 
            FROM OAuth_Config__mdt 
            WHERE DeveloperName = 'Main_Config' AND Is_Active__c = true 
            LIMIT 1
        ];
        Test.stopTest();

        System.assertEquals(activeConfig.Client_Id__c, ConfigManager.getClientId());
        System.assertEquals(activeConfig.Client_Secret__c, ConfigManager.getClientSecret());
        System.assertEquals(activeConfig.Redirect_Url__c, ConfigManager.getRedirectUrl());
        System.assertEquals(activeConfig.Redirect_Url_lightning__c, ConfigManager.getRedirectUrlLightning());
        System.assertEquals(activeConfig.Redirect_Url_community__c, ConfigManager.getRedirectUrlCommunity());
    }
}