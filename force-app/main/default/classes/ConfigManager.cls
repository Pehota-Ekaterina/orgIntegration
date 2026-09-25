public with sharing class ConfigManager {

    private static OAuth_Config__mdt getActiveConfig() {
        OAuth_Config__mdt result = null;

        try {
            OAuth_Config__mdt config = OAuth_Config__mdt.getInstance('Main_Config');

            System.debug('getActiveConfig config: ' + config);
            
            if (config != null && config.Is_Active__c) {
                result = config;
            }
        } catch (Exception e) {
            System.debug('ERROR: Failed to get OAuth config via getInstance(): ' + e.getMessage());
        }
        
        return result;
    }

    public static String getClientId() {
        OAuth_Config__mdt config = getActiveConfig();

        System.debug('getClientId config: ' + config);

        return config != null ? config.Client_Id__c : null;
    }
    
    public static String getClientSecret() {
        OAuth_Config__mdt config = getActiveConfig();

        return config != null ? config.Client_Secret__c : null;
    }

    public static String getRedirectUrl() {
        OAuth_Config__mdt config = getActiveConfig();

        System.debug('getRedirectUrl config: ' + config);

        return config != null ? config.Redirect_Url__c : null;
    }

    public static String getRedirectUrlLightning() {
        OAuth_Config__mdt config = getActiveConfig();

        return config != null ? config.Redirect_Url_lightning__c : null;
    }

    public static String getRedirectUrlCommunity() {
        OAuth_Config__mdt config = getActiveConfig();

        return config != null ? config.Redirect_Url_community__c : null;
    }
}