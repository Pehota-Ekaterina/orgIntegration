public without sharing class CallbackAuthController {
    public String statusMessage { get; set; }
    public List<String> errors { get; set; }
    
    private static final String clientId = ConfigManager.getClientId();
    private static final String clientSecret = ConfigManager.getClientSecret();
    private static final String redirectUri = ConfigManager.getRedirectUrlCommunity();

    public PageReference callbackAuth() {
        errors = new List<String>();
        
        System.debug('callbackAuth START!');

        String code = ApexPages.currentPage().getParameters().get('code');
        String recordId = ApexPages.currentPage().getParameters().get('state');
        List<Org_Connection__c> orgConnectionsList = new List<Org_Connection__c>();
        Org_Connection__c orgConnection = null;
        
        if (String.isBlank(code)) {
            errors.add('Code is empty.');
            return null;
        }
        
        if (String.isBlank(recordId)) {
            errors.add('State parameter is empty.');
            return null;
        }

        try {
            orgConnectionsList = [
                SELECT Id, Refresh_Token__c, Instance_Url__c, Login_Url__c, UserName__c
                FROM Org_Connection__c 
                WHERE Id = :recordId 
                LIMIT 1
            ];

            if (orgConnectionsList.isEmpty()) {
                errors.add('Org_Connection__c record not found for ID: ' + recordId);
                System.debug('Org_Connection__c record not found for ID: ' + recordId);
                return null;
            } else {
                System.debug('Org_Connection__c record found: ' + orgConnection);
                orgConnection = orgConnectionsList[0];
            }
        } catch (Exception e) {
            errors.add('Record not found: ' + e.getMessage());
            System.debug('catch error orgConnection');
            System.debug('catch message:' + e.getMessage());
            return null;
        }

        System.debug('orgConnection:' + orgConnection);
        
        String orgUrl = orgConnection.Login_Url__c;

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(orgUrl + '/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String body = 'grant_type=authorization_code' +
                          '&code=' + EncodingUtil.urlEncode(code, 'UTF-8') +
                          '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8') +
                          '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                          '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');
            
            req.setBody(body);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            Map<String, Object> jsonResp = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            
            if (res.getStatusCode() != 200) {
                return buildErrorRedirect(recordId, 'Authorization failed: status code');
            }

            System.debug('res.getStatusCode():' + res.getStatusCode());

            String accessToken = (String) jsonResp.get('access_token');
            // String idToken = (String) jsonResp.get('id_token');
            String instanceUrl = (String) jsonResp.get('instance_url');
            
            String username = getUsernameViaUserInfo(accessToken, orgUrl);
            
            if (String.isBlank(username)) {
                errors.add('Username not captured.');
            } else {
                orgConnection.UserName__c = username;
            }

            String refreshToken = (String) jsonResp.get('refresh_token');

            if(!isRefreshTokenValid(orgUrl, refreshToken)) {
                return buildErrorRedirect(recordId, 'Authorization failed: refresh token');
            }
            
            orgConnection.Refresh_Token__c = refreshToken;
            orgConnection.Instance_Url__c = instanceUrl;
            orgConnection.Status__c = 'Connected';

            System.debug('before update orgConnection');
            update orgConnection;  
            System.debug('after update orgConnection');

            System.debug('Org successfully linked! ID: ' + orgConnection.Id);
            return buildSuccessRedirect(recordId);
        } catch (Exception e) {
            System.debug('catch buildErrorRedirect call');
            return buildErrorRedirect(recordId, 'Authorization failed');
        }
    }

    private PageReference buildSuccessRedirect(String recordId) {
        String baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/orgConnectionPortal/s/org-connection/';
       
        PageReference pageRef = new PageReference(baseUrl + recordId);
        pageRef.setRedirect(true);
        
        return pageRef;
    }

    private PageReference buildErrorRedirect(String recordId, String errorMessage) {
        String baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/orgConnectionPortal/s/org-connection/';
        String recordIdPath;

        if (recordId != null && recordId != '') {
            recordIdPath = recordId;
        } else {
            recordIdPath = '';
        }
        
        PageReference pageRef = new PageReference(baseUrl + recordIdPath);
        pageRef.setRedirect(true);
        
        return pageRef;
    }

    private String getUsernameViaUserInfo(String accessToken, String orgUrl) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(orgUrl + '/services/oauth2/userinfo');
            
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> userInfo = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                return (String) userInfo.get('username') ?? (String) userInfo.get('preferred_username'); 
            }
            return null;
        } catch (Exception e) {
            errors.add('Error username: ' + e.getMessage());
            return null;
        }
    }

    private static Boolean isRefreshTokenValid(String url, String refreshToken) {    
        System.debug('isRefreshTokenValid start!');
        System.debug('clientId: '+ clientId);
        System.debug('clientSecret: '+ clientSecret);

        if (String.isBlank(url) || String.isBlank(refreshToken)) {
            return false;
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url + '/services/oauth2/token');
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

            
            System.debug('res.getStatusCode(): '+ res.getStatusCode());

            return res.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug('Token validation error: ' + e.getMessage());
            return false;
        }
    }
}