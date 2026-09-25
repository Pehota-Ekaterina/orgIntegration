@RestResource(urlMapping='/oauth/callback/*')
global without sharing class CallbackAuthRest {

    private static final String clientId = ConfigManager.getClientId();
    private static final String clientSecret = ConfigManager.getClientSecret();
    private static final String redirectUri = ConfigManager.getRedirectUrl(); 

    @HttpGet
    global static void handleCallback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // 1. Получаем параметры из URL (вместо ApexPages)
        String code = req.params.get('code');
        String state = req.params.get('state');
        
        if (String.isBlank(code) || String.isBlank(state)) {
            res.statusCode = 302;
            res.addHeader('Location', buildErrorUrl(null, 'lightning', 'Missing code or state parameters'));
            // res.addHeader('Location', buildErrorUrl(null, 'Missing code or state parameters'));
            return;
        }

        // 2. Парсим state (формат: recordId__context)
        List<String> stateParts = state.split('__');
        String recordId = stateParts[0];
        // String recordId = state;
        // String context = stateParts.size() > 1 ? stateParts[1] : 'lightning';
        String context = stateParts[1];
        
        Org_Connection__c orgConnection;
        try {
            orgConnection = [
                SELECT Id, Refresh_Token__c, Instance_Url__c, Login_Url__c, UserName__c
                FROM Org_Connection__c 
                WHERE Id = :recordId 
                LIMIT 1
            ];
        } catch (Exception e) {
            res.statusCode = 302;
            res.addHeader('Location', buildErrorUrl(recordId, context, 'Record not found'));
            // res.addHeader('Location', buildErrorUrl(recordId, 'Record not found'));
            return;
        }
        
        String orgUrl = orgConnection.Login_Url__c;

        try {
            // 3. Обмен кода на токены
            HttpRequest tokenReq = new HttpRequest();
            tokenReq.setEndpoint(orgUrl + '/services/oauth2/token');
            tokenReq.setMethod('POST');
            tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String body = 'grant_type=authorization_code' +
                          '&code=' + EncodingUtil.urlEncode(code, 'UTF-8') +
                          '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8') +
                          '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                          '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');
            
            tokenReq.setBody(body);
            
            HttpResponse tokenRes = new Http().send(tokenReq);
            Map<String, Object> jsonResp = (Map<String, Object>)JSON.deserializeUntyped(tokenRes.getBody());
            
            if (tokenRes.getStatusCode() != 200) {
                res.statusCode = 302;
                res.addHeader('Location', buildErrorUrl(recordId, context, 'Authorization failed: status code ' + tokenRes.getStatusCode()));
                // res.addHeader('Location', buildErrorUrl(recordId, 'Authorization failed: status code ' + tokenRes.getStatusCode()));
                return;
            }

            String accessToken = (String) jsonResp.get('access_token');
            String instanceUrl = (String) jsonResp.get('instance_url');
            String refreshToken = (String) jsonResp.get('refresh_token');
            
            // 4. Получаем Username
            String username = getUsernameViaUserInfo(accessToken, orgUrl);
            if (String.isNotBlank(username)) {
                orgConnection.UserName__c = username;
            }

            // 5. Валидируем Refresh Token
            if (!isRefreshTokenValid(orgUrl, refreshToken)) {
                res.statusCode = 302;
                res.addHeader('Location', buildErrorUrl(recordId, context, 'Authorization failed: invalid refresh token'));
                // res.addHeader('Location', buildErrorUrl(recordId, 'Authorization failed: invalid refresh token'));
                return;
            }
            
            // 6. Сохраняем данные
            orgConnection.Refresh_Token__c = refreshToken;
            orgConnection.Instance_Url__c = instanceUrl;
            orgConnection.Status__c = 'Connected';
            update orgConnection;  

            System.debug('Org successfully linked! ID: ' + orgConnection.Id);
            
            // 7. Успешный редирект
            res.statusCode = 302;
            res.addHeader('Location', buildSuccessUrl(recordId, context));
            // res.addHeader('Location', buildSuccessUrl(recordId));
            
        } catch (Exception e) {
            res.statusCode = 302;
            res.addHeader('Location', buildErrorUrl(recordId, context, 'Authorization failed: ' + e.getMessage()));
            // res.addHeader('Location', buildErrorUrl(recordId, 'Authorization failed: ' + e.getMessage()));
        }
    }

    // --- Вспомогательные методы для формирования URL редиректа ---

    private static String buildSuccessUrl(String recordId, String context) {
    // private static String buildSuccessUrl(String recordId) {
        String baseUrl;
        String recordPath;

        // baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/org-connection/';
        // recordPath = recordId;

        if (context == 'community') {
            baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/org-connection/';
            recordPath = recordId;
        } else {
            baseUrl = URL.getOrgDomainUrl().toExternalForm();
            recordPath = '/lightning/r/Org_Connection__c/' + recordId + '/view';
        }

        String finalUrl = baseUrl + recordPath;
        // finalUrl += '?c__toast=success&c__message=' + EncodingUtil.urlEncode('Org successfully linked!', 'UTF-8');
        
        return finalUrl;
        // return baseUrl + recordPath;
    }

    private static String buildErrorUrl(String recordId, String context, String errorMessage) {
    // private static String buildErrorUrl(String recordId, String errorMessage) {
        String baseUrl;
        String recordPath;
        
        if (String.isNotBlank(recordId)) {
            baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/org-connection/';
            recordPath = recordId;
            if (context == 'community') {
                baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/org-connection/';
                recordPath = recordId;
            } else {
                baseUrl = URL.getOrgDomainUrl().toExternalForm();
                recordPath = '/lightning/r/Org_Connection__c/' + recordId + '/view';
            }
        } else {
            baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/org-connection/';
            recordPath = '';
            if (context == 'community') {
                baseUrl = 'https://orgfarm-f379b895a8-dev-ed.develop.my.site.com/org-connection/';
                recordPath = '';
            } else {
                baseUrl = URL.getOrgDomainUrl().toExternalForm();
                recordPath = '/lightning/page/home';
            }
        }
        
        String finalUrl = baseUrl + recordPath;
        // finalUrl += '?c__toast=error&c__message=' + EncodingUtil.urlEncode(errorMessage, 'UTF-8');
        
        return finalUrl;
        // return baseUrl + recordPath;
    }

    private static String getUsernameViaUserInfo(String accessToken, String orgUrl) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(orgUrl + '/services/oauth2/userinfo');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            
            HttpResponse res = new Http().send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> userInfo = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                return (String) userInfo.get('username') ?? (String) userInfo.get('preferred_username'); 
            }
            return null;
        } catch (Exception e) {
            System.debug('Error getting username: ' + e.getMessage());
            return null;
        }
    }

    private static Boolean isRefreshTokenValid(String url, String refreshToken) {    
        if (String.isBlank(url) || String.isBlank(refreshToken)) {
            return false;
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url + '/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            // req.setTimeout(10000); // Рекомендуется добавить таймаут

            String body = 'grant_type=refresh_token' +
                          '&refresh_token=' + EncodingUtil.urlEncode(refreshToken, 'UTF-8') +
                          '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                          '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');
            req.setBody(body);

            HttpResponse res = new Http().send(req);
            return res.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug('Token validation error: ' + e.getMessage());
            return false;
        }
    }
}