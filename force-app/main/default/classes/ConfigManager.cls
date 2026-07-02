public with sharing class ConfigManager {
    /**
     * Получает Client ID из метаданных
     */
    public static String getClientId() {
        List<OAuth_Config__mdt> configs = [
            SELECT Client_Id__c 
            FROM OAuth_Config__mdt
            WHERE Is_Active__c = true 
            LIMIT 1
        ];

        return configs[0].Client_Id__c;
    }
    
    /**
     * Получает Client Secret из метаданных
     */
    public static String getClientSecret() {
        List<OAuth_Config__mdt> configs = [
            SELECT Client_Secret__c 
            FROM OAuth_Config__mdt 
            WHERE Is_Active__c = true 
            LIMIT 1
        ];
        
        return configs[0].Client_Secret__c;
    }
}