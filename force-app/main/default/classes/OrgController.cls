public with sharing class OrgController {
    @AuraEnabled(cacheable=true)
    public static List<Org_Connection__c> getOrgConnections() {
        return [
            SELECT Id, Org_Name__c, Type__c, Login_Url__c, UserName__c, Status__c
            FROM Org_Connection__c
            LIMIT 100
        ];
    }

    @AuraEnabled
    public static void saveOrgConnection(Map<String, Object> orgData) {
        Org_Connection__c orgConnection = new Org_Connection__c();
        orgConnection.Org_Name__c = (String) orgData.get('Org_Name__c');
        orgConnection.Type__c = (String) orgData.get('Type__c');
        orgConnection.Login_Url__c = (String) orgData.get('Login_Url__c');
        insert orgConnection;
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
}