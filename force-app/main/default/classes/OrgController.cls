public with sharing class OrgController {

    private static final String clientId = ConfigManager.getClientId();
    private static final String clientSecret = ConfigManager.getClientSecret();
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
    public static void deleteOrgConnection(String orgConnectionId) {
        try {
            if (String.isBlank(orgConnectionId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            List<Org_Connection__c> recordsToDelete = [
                SELECT Id FROM Org_Connection__c WHERE Id = :orgConnectionId 
            ];

            if (recordsToDelete.isEmpty()) {
                throw new AuraHandledException('Org Connection not found.');
            }
            // System.debug('debug' );
        

            delete recordsToDelete;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void disconnectOrgConnection(String orgConnectionId) {
        Org_Connection__c recordsToDisconnect = null;

        try {
            if (String.isBlank(orgConnectionId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            recordsToDisconnect = [
                SELECT Id, Refresh_Token__c, UserName__c, Instance_Url__c
                FROM Org_Connection__c 
                WHERE Id = :orgConnectionId 
                LIMIT 1
            ];

            if (recordsToDisconnect == null) {
                throw new AuraHandledException('Org Connection not found.');
            } 

            //delete refrash tocken
            recordsToDisconnect.Refresh_Token__c = '';
            recordsToDisconnect.UserName__c = '';
            recordsToDisconnect.Instance_Url__c = '';
            update recordsToDisconnect;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String openOrgConnection(String orgConnectionId) {
        Org_Connection__c orgConnection = [SELECT Id, Instance_Url__c, Refresh_Token__c, Login_Url__c, Status__c FROM Org_Connection__c WHERE Id = :orgConnectionId LIMIT 1];

        // Implement logic to open the org connection based on the orgConnectionId
        // get a new accsees token (use refresh token)

        String refreshToken = orgConnection.Refresh_Token__c;
        System.debug('refreshToken: ' + refreshToken);
        String instanceUrl = orgConnection.Instance_Url__c;
        String loginUrl = orgConnection.Login_Url__c;

        //post request to get access rtoken
        HttpRequest req = new HttpRequest();
        req.setEndpoint(loginUrl + '/services/oauth2/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'grant_type=refresh_token' +
                      '&refresh_token=' + EncodingUtil.urlEncode(refreshToken, 'UTF-8') +
                      '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                      '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        Map<String, Object> jsonResp = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

        System.debug('status response: ' + res.getStatusCode());

        if(res.getStatusCode() != 200) {
            orgConnection.Status__c = 'Failed';
            update orgConnection;

            return null;
        }

        String newAccessToken = (String) jsonResp.get('access_token');

        // return string url with frontdoor (use accsees token)
        // {instance_url}/secur/frontdoor.jsp?sid={new_access_token}
        return instanceUrl + '/secur/frontdoor.jsp?' +
            'sid=' + EncodingUtil.urlEncode(newAccessToken, 'UTF-8') +
            '&retURL=/home/home.jsp';
    }

    @AuraEnabled(cacheable=false)
    public static void revokeRefreshToken(String orgConnectionId) {
        Org_Connection__c orgConnection = [SELECT Id, Login_Url__c, Instance_Url__c, Refresh_Token__c FROM Org_Connection__c WHERE Id = :orgConnectionId LIMIT 1];

        String refreshToken = orgConnection.Refresh_Token__c;
        String baseURL = orgConnection.Instance_Url__c; 

        System.debug('Refresh token: ' + orgConnection.Refresh_Token__c);
        System.debug('Base URL: ' + orgConnection.Instance_Url__c);
        
        // HttpRequest req = new HttpRequest();
        // req.setEndpoint(orgConnection.Login_Url__c + '/services/oauth2/revoke');
        // req.setMethod('POST');
        // req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        // String body = 'token=' + EncodingUtil.urlEncode(orgConnection.Refresh_Token__c, 'UTF-8');

        // req.setBody(body);

        // Http http = new Http();
        // HttpResponse res = http.send(req);

        // System.debug('Status code: ' + res.getStatusCode());
        // System.debug('Response body: ' + res.getBody());
        
        // if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
        //     return true;
        // } else {
        //     return false;
        // }
    }

    @AuraEnabled
    public static String getAuthorizationUrl(String orgConnectionId) {
        Org_Connection__c orgConnection = [SELECT Id, Login_Url__c FROM Org_Connection__c WHERE Id = :orgConnectionId LIMIT 1];

        String state = orgConnectionId;
        String baseUrl = orgConnection.Login_Url__c;
        
        return baseUrl + '/services/oauth2/authorize?' +
            'response_type=code' +
            '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
            '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8') +
            '&scope=full%20refresh_token%20web' +
            '&state=' + EncodingUtil.urlEncode(state, 'UTF-8');
    }
}