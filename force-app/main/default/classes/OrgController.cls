public with sharing class OrgController {

    private static final String clientKey = ConfigManager.getClientId();
    private static final String redirectUri = 'https://orgfarm-f379b895a8-dev-ed.develop.my.salesforce.com/apex/CallbackAuth';

    @AuraEnabled(cacheable=true)
    public static List<Org_Connection__c> getOrgConnections() {
        return [
            SELECT Id, Org_Name__c, Type__c, Login_Url__c, UserName__c, Status__c
            FROM Org_Connection__c
            LIMIT 100
        ];
    }

    @AuraEnabled
    public static String saveOrgConnection(Map<String, Object> orgData) {
        Org_Connection__c orgConnection = new Org_Connection__c();
        orgConnection.Org_Name__c = (String) orgData.get('Org_Name__c');
        orgConnection.Type__c = (String) orgData.get('Type__c');
        orgConnection.Login_Url__c = (String) orgData.get('Login_Url__c');
        insert orgConnection;

        return orgConnection.Id;
    }

    @AuraEnabled
    public static void deleteOrgConnection(String recordId){
        try {
            if (String.isBlank(recordId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            List<Org_Connection__c> recordsToDelete = [
                SELECT Id FROM Org_Connection__c WHERE Id = :recordId
            ];

            if (recordsToDelete.isEmpty()) {
                throw new AuraHandledException('Org Connection not found.');
            }

            delete recordsToDelete;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void disconnectOrgConnection(String recordId){
        try {
            if (String.isBlank(recordId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            List<Org_Connection__c> recordsToDisconnect = [
                SELECT Id FROM Org_Connection__c WHERE Id = :recordId
            ];

            if (recordsToDisconnect.isEmpty()) {
                throw new AuraHandledException('Org Connection not found.');
            } 

            //delete refrash tocken
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getAuthorizationUrl(String orgConnectionId) {
        Org_Connection__c orgConnection = [SELECT Id, Login_Url__c FROM Org_Connection__c WHERE Id = :orgConnectionId LIMIT 1];

        String state = orgConnectionId;
        String baseUrl = orgConnection.Login_Url__c;
        
        return baseUrl + '/services/oauth2/authorize?' +
            'response_type=code' +
            '&client_id=' + EncodingUtil.urlEncode(clientKey, 'UTF-8') +
            '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8') +
            '&scope=full%20refresh_token%20web' +
            '&state=' + EncodingUtil.urlEncode(state, 'UTF-8');
    }
}