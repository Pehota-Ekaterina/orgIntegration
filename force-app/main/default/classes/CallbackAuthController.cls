public without sharing class CallbackAuthController {
    public String statusMessage { get; set; }
    public List<String> errors { get; set; }
    
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
                // errors.add('Error from token endpoint: ' + res.getBody());
                // errors.add('status ' + res.getStatusCode());
                
                PageReference pageRef = new PageReference('/lightning/r/Org_Connection__c/' + state + '/view');
                pageRef.getParameters().put('c__toast', 'error');
                pageRef.getParameters().put('c__message', EncodingUtil.urlEncode('Authorization failed', 'UTF-8'));
                pageRef.setRedirect(true);
                return pageRef;
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

            //open record page with sucses massage  
            PageReference pageRef = new PageReference('/lightning/r/Org_Connection__c/' + state + '/view');
            pageRef.getParameters().put('c__toast', 'success');
            pageRef.getParameters().put('c__message', EncodingUtil.urlEncode('Org successfully linked!', 'UTF-8'));
            pageRef.setRedirect(true);
            return pageRef;
        } catch (Exception e) {
            // errors.add('Error on token save: ' + e.getMessage());
            //open record page with error massage
            PageReference pageRef = new PageReference('/lightning/r/Org_Connection__c/' + state + '/view');
            pageRef.getParameters().put('c__toast', 'error');
            pageRef.getParameters().put('c__message', EncodingUtil.urlEncode('Authorization failed', 'UTF-8'));
            pageRef.setRedirect(true);
            return pageRef;
        }
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