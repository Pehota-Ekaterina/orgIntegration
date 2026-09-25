@isTest
private class CallbackAuthRestTest {
    private class SuccessTokenExchangeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/services/oauth2/token') && 
                req.getBody().contains('grant_type=authorization_code')) {
                res.setStatusCode(200);
                res.setBody('{' +
                    '"access_token": "mocked_access_token_12345",' +
                    '"instance_url": "https://mocked-instance.salesforce.com",' +
                    '"refresh_token": "mocked_refresh_token_67890"' +
                '}');
            } else if (req.getEndpoint().contains('/services/oauth2/userinfo')) {
                res.setStatusCode(200);
                res.setBody('{"username": "testuser@example.com", "preferred_username": "testuser@example.com"}');
            } else if (req.getEndpoint().contains('/services/oauth2/token') && 
                       req.getBody().contains('grant_type=refresh_token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token": "new_access_token"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error": "unknown_request"}');
            }
            
            return res;
        }
    }

    private class FailedTokenExchangeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error": "invalid_grant", "error_description": "expired authorization code"}');
            return res;
        }
    }

    private class InvalidRefreshTokenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/services/oauth2/token') && 
                req.getBody().contains('grant_type=authorization_code')) {
                res.setStatusCode(200);
                res.setBody('{' +
                    '"access_token": "mocked_access_token_12345",' +
                    '"instance_url": "https://mocked-instance.salesforce.com",' +
                    '"refresh_token": "invalid_refresh_token"' +
                '}');
            } else if (req.getEndpoint().contains('/services/oauth2/userinfo')) {
                res.setStatusCode(200);
                res.setBody('{"username": "testuser@example.com"}');
            } else if (req.getEndpoint().contains('/services/oauth2/token') && 
                       req.getBody().contains('grant_type=refresh_token')) {
                res.setStatusCode(400);
                res.setBody('{"error": "invalid_grant"}');
            }
            return res;
        }
    }

    private class UsernameFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/services/oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{' +
                    '"access_token": "mocked_access_token",' +
                    '"instance_url": "https://mocked-instance.salesforce.com",' +
                    '"refresh_token": "mocked_refresh_token"' +
                '}');
            } else if (req.getEndpoint().contains('/services/oauth2/userinfo')) {
                res.setStatusCode(500);
                res.setBody('{"error": "internal_server_error"}');
            }
            
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        Org_Connection__c testRecord = new Org_Connection__c(
            Org_Name__c = 'Test Org for Callback',
            Login_Url__c = 'https://test.salesforce.com',
            Type__c = 'Sandbox',
            Status__c = 'Not linked'
        );
        insert testRecord;
    }

    private static void setupRestContext(String code, String state) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/oauth/callback';
        req.httpMethod = 'GET';
        
        if (code != null) {
            req.params.put('code', code);
        }
        if (state != null) {
            req.params.put('state', state);
        }
        
        RestContext.request = req;
        RestContext.response = res;
    }

    // @isTest
    // static void testHandleCallback_Success() {
    //     Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
    //     String state = testRecord.Id + '__lightning';
        
    //     Test.setMock(HttpCalloutMock.class, new SuccessTokenExchangeMock());
    //     setupRestContext('valid_auth_code_123', state);
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     // Проверяем статус ответа
    //     System.assertEquals(302, RestContext.response.statusCode, 'Должен быть редирект (302)');
        
    //     // Проверяем заголовок Location
    //     String locationHeader = RestContext.response.getHeader('Location');
    //     System.assert(locationHeader != null, 'Location header должен присутствовать');
    //     System.assert(locationHeader.contains(testRecord.Id), 'URL должен содержать ID записи');
        
    //     // Проверяем, что запись обновилась в БД
    //     Org_Connection__c updatedRecord = [
    //         SELECT Status__c, Refresh_Token__c, Instance_Url__c, UserName__c 
    //         FROM Org_Connection__c 
    //         WHERE Id = :testRecord.Id
    //     ];
        
    //     System.assertEquals('Connected', updatedRecord.Status__c, 'Статус должен быть Connected');
    //     System.assertEquals('mocked_refresh_token_67890', updatedRecord.Refresh_Token__c, 'Refresh token должен быть сохранен');
    //     System.assertEquals('https://mocked-instance.salesforce.com', updatedRecord.Instance_Url__c, 'Instance URL должен быть сохранен');
    //     System.assertEquals('testuser@example.com', updatedRecord.UserName__c, 'Username должен быть сохранен');
    // }

    // @isTest
    // static void testHandleCallback_Success_CommunityContext() {
    //     Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
    //     String state = testRecord.Id + '__community';
        
    //     Test.setMock(HttpCalloutMock.class, new SuccessTokenExchangeMock());
    //     setupRestContext('valid_auth_code_123', state);
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     System.assertEquals(302, RestContext.response.statusCode);
        
    //     String locationHeader = RestContext.response.getHeader('Location');
    //     System.assert(locationHeader.contains('my.site.com'), 'URL должен содержать community domain');
    //     System.assert(locationHeader.contains(testRecord.Id), 'URL должен содержать ID записи');
    // }

    // @isTest
    // static void testHandleCallback_MissingCode() {
    //     Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
    //     String state = testRecord.Id + '__lightning';
        
    //     setupRestContext(null, state); // code = null
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     System.assertEquals(302, RestContext.response.statusCode, 'Должен быть редирект');
        
    //     String locationHeader = RestContext.response.getHeader('Location');
    //     System.assert(locationHeader != null, 'Location header должен присутствовать');
    //     // URL должен вести на error page (без recordId, т.к. code отсутствует)
    // }

    // @isTest
    // static void testHandleCallback_MissingState() {
    //     setupRestContext('valid_auth_code_123', null); // state = null
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     System.assertEquals(302, RestContext.response.statusCode);
    //     String locationHeader = RestContext.response.getHeader('Location');
    //     System.assert(locationHeader != null);
    // }

    // @isTest
    // static void testHandleCallback_RecordNotFound() {
    //     String fakeId = 'a00000000000000AAA';
    //     String state = fakeId + '__lightning';
        
    //     Test.setMock(HttpCalloutMock.class, new SuccessTokenExchangeMock());
    //     setupRestContext('valid_auth_code_123', state);
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     System.assertEquals(302, RestContext.response.statusCode);
        
    //     String locationHeader = RestContext.response.getHeader('Location');
    //     System.assert(locationHeader != null);
    //     // Проверяем, что запись НЕ была обновлена (т.к. её не нашли)
    //     List<Org_Connection__c> records = [SELECT Status__c FROM Org_Connection__c WHERE Id = :fakeId];
    //     System.assertEquals(0, records.size(), 'Запись не должна существовать');
    // }

    // @isTest
    // static void testHandleCallback_AuthorizationFailed() {
    //     Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
    //     String state = testRecord.Id + '__lightning';
        
    //     Test.setMock(HttpCalloutMock.class, new FailedTokenExchangeMock());
    //     setupRestContext('invalid_auth_code', state);
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     System.assertEquals(302, RestContext.response.statusCode);
        
    //     String locationHeader = RestContext.response.getHeader('Location');
    //     System.assert(locationHeader != null);
        
    //     // Проверяем, что запись НЕ была обновлена
    //     Org_Connection__c unchangedRecord = [SELECT Status__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
    //     System.assertEquals('Not linked', unchangedRecord.Status__c, 'Статус не должен измениться при ошибке');
    // }

    // @isTest
    // static void testHandleCallback_InvalidRefreshToken() {
    //     Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
    //     String state = testRecord.Id + '__lightning';
        
    //     Test.setMock(HttpCalloutMock.class, new InvalidRefreshTokenMock());
    //     setupRestContext('valid_auth_code_123', state);
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     System.assertEquals(302, RestContext.response.statusCode);
        
    //     String locationHeader = RestContext.response.getHeader('Location');
    //     System.assert(locationHeader != null);
        
    //     // Проверяем, что запись НЕ была обновлена (refresh token невалиден)
    //     Org_Connection__c unchangedRecord = [SELECT Status__c, Refresh_Token__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
    //     System.assertEquals('Not linked', unchangedRecord.Status__c, 'Статус не должен измениться');
    //     System.assertEquals(null, unchangedRecord.Refresh_Token__c, 'Refresh token не должен быть сохранен');
    // }

    // @isTest
    // static void testHandleCallback_UsernameFailure() {
    //     Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
    //     String state = testRecord.Id + '__lightning';
        
    //     Test.setMock(HttpCalloutMock.class, new UsernameFailureMock());
    //     setupRestContext('valid_auth_code_123', state);
        
    //     Test.startTest();
    //     CallbackAuthRest.handleCallback();
    //     Test.stopTest();
        
    //     // Авторизация должна быть успешной, даже если username не получен
    //     System.assertEquals(302, RestContext.response.statusCode);
        
    //     Org_Connection__c updatedRecord = [SELECT Status__c, UserName__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
    //     System.assertEquals('Connected', updatedRecord.Status__c, 'Статус должен быть Connected');
    //     // Username может быть null или не измениться (зависит от изначального значения)
    // }
}