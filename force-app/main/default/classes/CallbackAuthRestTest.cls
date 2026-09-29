@isTest
private class CallbackAuthRestTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/services/oauth2/token') && req.getBody().contains('grant_type=authorization_code')) {
                res.setStatusCode(200);
                res.setBody('{"access_token": "mock_access_token_123", "instance_url": "https://mock.instance.com", "refresh_token": "mock_refresh_token_456"}');
            } else if (req.getEndpoint().contains('/services/oauth2/userinfo')) {
                res.setStatusCode(200);
                res.setBody('{"username": "testuser@example.com", "preferred_username": "testuser@example.com"}');
            } else if (req.getEndpoint().contains('/services/oauth2/token') && req.getBody().contains('grant_type=refresh_token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token": "new_mock_access_token"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error": "unknown_request"}');
            }
            return res;
        }
    }

    private class AuthFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error": "invalid_grant", "error_description": "Authorization code expired"}');
            return res;
        }
    }

    private class InvalidRefreshMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/services/oauth2/token') && req.getBody().contains('grant_type=authorization_code')) {
                res.setStatusCode(200);
                res.setBody('{"access_token": "mock_access_token_123", "instance_url": "https://mock.instance.com", "refresh_token": "invalid_refresh_token"}');
            } else if (req.getEndpoint().contains('/services/oauth2/userinfo')) {
                res.setStatusCode(200);
                res.setBody('{"username": "testuser@example.com"}');
            } else if (req.getEndpoint().contains('/services/oauth2/token') && req.getBody().contains('grant_type=refresh_token')) {
                res.setStatusCode(400);
                res.setBody('{"error": "invalid_grant"}');
            }
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        OAuth_Config__mdt config = [SELECT DeveloperName FROM OAuth_Config__mdt WHERE DeveloperName = 'Main_Config' LIMIT 1];

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
        
        if (code != null) req.params.put('code', code);
        if (state != null) req.params.put('state', state);
        
        RestContext.request = req;
        RestContext.response = res;
    }

    @isTest
    static void handleCallbackTestMissingParamCode() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        
        setupRestContext(null, testRecord.Id);
        Test.startTest();
        CallbackAuthRest.handleCallback();
        Test.stopTest();
        
        System.assertEquals(302, RestContext.response.statusCode, 'Expected a redirect due to missing code parameter');
    }

    @isTest
    static void handleCallbackTestMissingParamState() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        
        setupRestContext('valid_code_123', null);
        Test.startTest();
        CallbackAuthRest.handleCallback();
        Test.stopTest();
        
        System.assertEquals(302, RestContext.response.statusCode, 'Expected a redirect due to missing state parameter');
    }

    @isTest
    static void handleCallbackTestRecordNotFound() {
        String fakeId = 'a00000000000000AAA';
        setupRestContext('valid_code_123', fakeId);
        
        Test.startTest();
        CallbackAuthRest.handleCallback();
        Test.stopTest();
        
        System.assertEquals(302, RestContext.response.statusCode);
    }

    @isTest
    static void handleCallbackTestSuccess() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupRestContext('valid_auth_code_123', testRecord.Id);
        
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        CallbackAuthRest.handleCallback();
        Test.stopTest();
        
        System.assertEquals(302, RestContext.response.statusCode);
        
        Org_Connection__c updatedRecord = [
            SELECT Id, Status__c, Refresh_Token__c, Instance_Url__c, UserName__c 
            FROM Org_Connection__c 
            WHERE Id = :testRecord.Id
        ];
        
        System.assertEquals('Connected', updatedRecord.Status__c);
        System.assertEquals('mock_refresh_token_456', updatedRecord.Refresh_Token__c);
        System.assertEquals('https://mock.instance.com', updatedRecord.Instance_Url__c);
        System.assertEquals('testuser@example.com', updatedRecord.UserName__c);
    }

    @isTest
    static void handleCallbackTestAuthorizationFailed() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupRestContext('invalid_auth_code', testRecord.Id);
        
        Test.setMock(HttpCalloutMock.class, new AuthFailureMock());
        
        Test.startTest();
        CallbackAuthRest.handleCallback();
        Test.stopTest();
        
        System.assertEquals(302, RestContext.response.statusCode);
        
        Org_Connection__c unchangedRecord = [SELECT Status__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
        System.assertEquals('Not linked', unchangedRecord.Status__c);
    }

    @isTest
    static void handleCallbackTestInvalidRefreshToken() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupRestContext('valid_auth_code_123', testRecord.Id);
        
        Test.setMock(HttpCalloutMock.class, new InvalidRefreshMock());
        
        Test.startTest();
        CallbackAuthRest.handleCallback();
        Test.stopTest();
        
        System.assertEquals(302, RestContext.response.statusCode);
        
        Org_Connection__c unchangedRecord = [SELECT Status__c, Refresh_Token__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
        System.assertEquals('Not linked', unchangedRecord.Status__c);
        System.assertEquals(null, unchangedRecord.Refresh_Token__c);
    }
}