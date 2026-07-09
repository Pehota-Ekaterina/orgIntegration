public without sharing class CallbackAuthController {
    public String statusMessage { get; set; }
    public List<String> errors { get; set; }

    public String accessToken { get; set; }
    public String idToken { get; set; }
    
    private static final String clientId = ConfigManager.getClientId();
    private static final String clientSecret = ConfigManager.getClientSecret();
    private static final String redirectUri = 'https://orgfarm-f379b895a8-dev-ed.develop.my.salesforce.com/apex/CallbackAuth';
    
    public PageReference callbackAuth() {
        errors = new List<String>();
        
        String code = ApexPages.currentPage().getParameters().get('code');
        String state = ApexPages.currentPage().getParameters().get('state');
        Org_Connection__c orgConnection = null;
        
        if (String.isBlank(code)) {
            errors.add('Code is empty.');
            return null;
        }
        
        if (String.isBlank(state)) {
            errors.add('State parameter is empty.');
            return null;
        }
        
        try {
            orgConnection = [
                SELECT Id, Refresh_Token__c, Instance_Url__c, Login_Url__c, UserName__c
                FROM Org_Connection__c 
                WHERE Id = :state 
                LIMIT 1
            ];
        } catch (Exception e) {
            errors.add('Record not found: ' + e.getMessage());
            return null;
        }
        
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
                errors.add('Error from token endpoint: ' + res.getBody());
                errors.add('status ' + res.getStatusCode());
                return null;
            }

            String accessToken = (String) jsonResp.get('access_token');
            String idToken = (String) jsonResp.get('id_token');
            String instanceUrl = (String) jsonResp.get('instance_url');
            
            String username = getUsernameViaUserInfo(accessToken, orgUrl);
            
            if (String.isBlank(username)) {
                errors.add('Username not captured.');
            } else {
                orgConnection.UserName__c = username;
            }
            
            orgConnection.Refresh_Token__c = (String) jsonResp.get('refresh_token');
            orgConnection.Instance_Url__c = (String) jsonResp.get('instance_url');
            orgConnection.Status__c = 'Connected';
            update orgConnection;
            
            statusMessage = 'Authorization successful!';
            
        } catch (Exception e) {
            errors.add('Error on token save: ' + e.getMessage());
        }
        
        return null;
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
}