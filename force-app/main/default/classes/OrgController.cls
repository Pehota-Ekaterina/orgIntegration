public with sharing class OrgController {

    private static final String clientId = ConfigManager.getClientId();
    private static final String clientSecret = ConfigManager.getClientSecret();
    // private static final String redirectUri = ConfigManager.getRedirectUrl();
    // private static final String redirectUriLightning = ConfigManager.getRedirectUrlLightning();
    private static final String redirectUriCommunity = ConfigManager.getRedirectUrlCommunity();

    @AuraEnabled(cacheable=true)
    public static List<Org_Connection__c> getOrgConnections() {
        return [
            SELECT Id, Org_Name__c, Type__c, Login_Url__c, UserName__c, Status__c
            FROM Org_Connection__c
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkPermissionAdmin() {
        // System.debug('custom permission: ' + FeatureManagement.checkPermission('Manage_org_connection'));
        // System.debug('user:' + UserInfo.getUserId());
        return FeatureManagement.checkPermission('Manage_org_connection');        
    }

    @AuraEnabled(cacheable=true)
    public static Org_Connection__c getOrgConnectionById(String orgConnectionId) {
        try {
            if (String.isBlank(orgConnectionId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            List<Org_Connection__c> records = [
                SELECT Id, Org_Name__c, Type__c, Login_Url__c, UserName__c, Status__c, Instance_Url__c
                FROM Org_Connection__c
                WHERE Id = :orgConnectionId
                LIMIT 1
            ];

            if (records.isEmpty()) {
                throw new AuraHandledException('Org Connection record not found: ' + orgConnectionId);
            }
            
            return records[0];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveOrgConnection(Map<String, Object> orgData) {
        if (!checkPermissionAdmin()) {
            throw new AuraHandledException('Insufficient privileges to save org connection.');
        }

        if (orgData == null || orgData.isEmpty()) {
            throw new AuraHandledException('Invalid org connection data provided.');
        }

        Org_Connection__c orgConnection = new Org_Connection__c();
        orgConnection.Org_Name__c = (String) orgData.get('Org_Name__c');
        orgConnection.Type__c = (String) orgData.get('Type__c');
        orgConnection.Login_Url__c = (String) orgData.get('Login_Url__c');
        insert orgConnection;

        return orgConnection.Id;
    }

    @AuraEnabled
    public static void deleteOrgConnection(String orgConnectionId) {
        if (!checkPermissionAdmin()) {
            throw new AuraHandledException('Insufficient privileges to disconnect.');
        }

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

            delete recordsToDelete;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void disconnectOrgConnection(String orgConnectionId) {
        if (!checkPermissionAdmin()) {
            throw new AuraHandledException('Insufficient privileges to disconnect.');
        }

        try {
            if (String.isBlank(orgConnectionId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            List<Org_Connection__c> recordsToDisconnectList = [
                SELECT Id, Refresh_Token__c, Instance_Url__c, UserName__c, Status__c
                FROM Org_Connection__c 
                WHERE Id = :orgConnectionId 
                LIMIT 1
            ];

            if (recordsToDisconnectList.isEmpty()) {
                throw new AuraHandledException('Org Connection not found.');
            } 

            Org_Connection__c recordToDisconnect = recordsToDisconnectList[0];

            recordToDisconnect.Refresh_Token__c = null;
            recordToDisconnect.Instance_Url__c = null;
            recordToDisconnect.UserName__c = null;

            recordToDisconnect.Status__c = 'Not linked';
            update recordToDisconnect;  
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String openOrgConnection(String orgConnectionId) {
        try {
            if (String.isBlank(orgConnectionId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            List<Org_Connection__c> orgConnectionList = [
                SELECT Id, Instance_Url__c, Refresh_Token__c, Login_Url__c, Status__c 
                FROM Org_Connection__c 
                WHERE Id = :orgConnectionId 
                LIMIT 1
            ];

            if (orgConnectionList.isEmpty()) {
                throw new AuraHandledException('Org Connection not found.');
            } 

            Org_Connection__c orgConnection = orgConnectionList[0];

            String refreshToken = orgConnection.Refresh_Token__c;
            String instanceUrl = orgConnection.Instance_Url__c;
            String loginUrl = orgConnection.Login_Url__c;

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

            if(res.getStatusCode() != 200) {
                orgConnection.Status__c = 'Failed';
                update orgConnection;

                return null; 
            }

            String newAccessToken = (String) jsonResp.get('access_token');

            return instanceUrl + '/secur/frontdoor.jsp?' +
                'sid=' + EncodingUtil.urlEncode(newAccessToken, 'UTF-8') +
                '&retURL=/home/home.jsp'; 
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getAuthorizationUrl(String orgConnectionId) {
        try {
            if (String.isBlank(orgConnectionId)) {
                throw new AuraHandledException('Invalid Record ID provided.');
            }

            List<Org_Connection__c> orgConnectionsList = [
                SELECT Id, Login_Url__c 
                FROM Org_Connection__c 
                WHERE Id = :orgConnectionId 
                LIMIT 1
            ];

            if (orgConnectionsList.isEmpty()) {
                throw new AuraHandledException('Org Connection not found.');
            }        
            Org_Connection__c orgConnection = orgConnectionsList[0];

            String networkId = Network.getNetworkId();
            // String context = String.isNotBlank(networkId) ? 'community' : 'lightning';
            String context = 'community';
        

            // String redirectUri = context == 'community' ? redirectUriCommunity : redirectUriLightning;
            String redirectUri = redirectUriCommunity;

            String state = orgConnectionId + '__' + context;
            // String state = orgConnectionId;
            String baseUrl = orgConnection.Login_Url__c;
            
            return baseUrl + '/services/oauth2/authorize?' +
                'response_type=code' +
                '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8') +
                '&scope=full%20refresh_token%20web' +
                '&state=' + EncodingUtil.urlEncode(state, 'UTF-8');

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }        
    }

    @AuraEnabled
    public static void connectionStatusCheck() {
        List<Org_Connection__c> orgConnectionsList = [SELECT Id, Login_Url__c, Refresh_Token__c, Status__c FROM Org_Connection__c];
        List<Org_Connection__c> orgConnectionsToUpdate = new List<Org_Connection__c>();

        for (Org_Connection__c orgConnection : orgConnectionsList) {            
            if (String.isBlank(orgConnection.Refresh_Token__c)) {
                orgConnection.Status__c = 'Not linked';
            } else {
                String loginUrl = orgConnection.Login_Url__c;
                String refreshToken = orgConnection.Refresh_Token__c;
                Boolean isValid = isRefreshTokenValid(loginUrl, refreshToken);

                if (isValid) {
                    orgConnection.Status__c = 'Connected';
                } else {
                    orgConnection.Status__c = 'Failed';
                }
            }
        }

        update orgConnectionsList;
    }

    @TestVisible
    private static Boolean isRefreshTokenValid(String loginUrl, String refreshToken) {
        if (String.isBlank(loginUrl) || String.isBlank(refreshToken)) {
            return false;
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(loginUrl + '/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            // req.setTimeout(10000);

            String body = 'grant_type=refresh_token' +
                          '&refresh_token=' + EncodingUtil.urlEncode(refreshToken, 'UTF-8') +
                          '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                          '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);

            return res.getStatusCode() == 200;
        } catch (Exception e) {
            return false;
        }
    }
}