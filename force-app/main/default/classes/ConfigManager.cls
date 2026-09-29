public with sharing class ConfigManager {

    private static OAuth_Config__mdt getActiveConfig() {
        OAuth_Config__mdt result = null;

        try {
            OAuth_Config__mdt config = OAuth_Config__mdt.getInstance('Main_Config');
            
            if (config != null && config.Is_Active__c) {
                result = config;
            }
            return null;
        } catch (Exception e) {
            System.debug('ERROR: Failed to get OAuth config via getInstance(): ' + e.getMessage());
        }
        
        return result;
    }

    /**
     * Получает Client ID из метаданных
     */
    public static String getClientId() {
        OAuth_Config__mdt config = getActiveConfig();

        return config != null ? config.Client_Id__c : null;
    }
    
    /**
     * Получает Client Secret из метаданных
     */
    public static String getClientSecret() {
        OAuth_Config__mdt config = getActiveConfig();

        return config != null ? config.Client_Secret__c : null;
    }

    /**
     * Получает Redirect Url из метаданных
     */
    public static String getRedirectUrl() {
        OAuth_Config__mdt config = getActiveConfig();

        return config != null ? config.Redirect_Url__c : null;
    }
}