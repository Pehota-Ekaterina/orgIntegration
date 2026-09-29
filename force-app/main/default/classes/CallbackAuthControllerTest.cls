@isTest
private class CallbackAuthControllerTest {
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

    private class TokenFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error": "invalid_grant", "error_description": "Authorization code expired"}');
            return res;
        }
    }

    private class RefreshTokenFailureMock implements HttpCalloutMock {
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

    private class UserInfoFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/services/oauth2/userinfo')) {
                res.setStatusCode(500);
                res.setBody('{"error": "internal_server_error"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"access_token": "mock_token", "instance_url": "https://mock.com", "refresh_token": "mock_refresh"}');
            }
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        Org_Connection__c testRecord = new Org_Connection__c(
            Org_Name__c = 'Test Org for VF Callback',
            Login_Url__c = 'https://test.salesforce.com',
            Type__c = 'Sandbox',
            Status__c = 'Not linked'
        );
        insert testRecord;
    }

    private static void setupPageParameters(String code, String state) {
        PageReference testPage = new PageReference('/apex/CallbackAuthPage');
        if (code != null) testPage.getParameters().put('code', code);
        if (state != null) testPage.getParameters().put('state', state);
        Test.setCurrentPage(testPage);
    }

    @isTest
    static void callbackAuthTestMissingCode() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupPageParameters(null, testRecord.Id);
        
        Test.startTest();
        CallbackAuthController controller = new CallbackAuthController();
        PageReference result = controller.callbackAuth();
        Test.stopTest();
        
        System.assertEquals(null, result, 'Expected null PageReference when code is missing');
        System.assert(controller.errors[0].contains('Code is empty'));
    }

    @isTest
    static void callbackAuthTestMissingState() {
        setupPageParameters('valid_code_123', null);
        
        Test.startTest();
        CallbackAuthController controller = new CallbackAuthController();
        PageReference result = controller.callbackAuth();
        Test.stopTest();
        
        System.assertEquals(null, result, 'Expected null PageReference when state is missing');
        System.assert(controller.errors[0].contains('State parameter is empty'));
    }

    @isTest
    static void callbackAuthTestRecordNotFound() {
        String fakeId = 'a00000000000000AAA';
        setupPageParameters('valid_code_123', fakeId);
        
        Test.startTest();
        CallbackAuthController controller = new CallbackAuthController();
        PageReference result = controller.callbackAuth();
        Test.stopTest();
        
        System.assertEquals(null, result);
        System.assertEquals(1, controller.errors.size());
        System.assert(controller.errors[0].contains('not found for ID: ' + fakeId));
    }

    @isTest
    static void callbackAuthTestSuccessFlow() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupPageParameters('valid_auth_code_123', testRecord.Id);
        
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        CallbackAuthController controller = new CallbackAuthController();
        PageReference result = controller.callbackAuth();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Expected a valid PageReference on successful callback');
        System.assertEquals(true, result.getRedirect(), 'Expected a redirect');
        System.assert(result.getUrl().contains('org-connection/' + testRecord.Id), 'URL should contain the record ID');
        
        System.assertEquals(0, controller.errors.size(), 'Should not have any errors');
        
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
    static void callbackAuthTestTokenExchangeFailure() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupPageParameters('invalid_auth_code', testRecord.Id);
        
        Test.setMock(HttpCalloutMock.class, new TokenFailureMock());
        
        Test.startTest();
        CallbackAuthController controller = new CallbackAuthController();
        PageReference result = controller.callbackAuth();
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('org-connection/' + testRecord.Id), 'Expected redirect back to the record');
        
        Org_Connection__c unchangedRecord = [SELECT Status__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
        System.assertEquals('Not linked', unchangedRecord.Status__c);
    }

    @isTest
    static void callbackAuthTestRefreshTokenValidationFailure() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupPageParameters('valid_auth_code_123', testRecord.Id);
        
        Test.setMock(HttpCalloutMock.class, new RefreshTokenFailureMock());
        
        Test.startTest();
        CallbackAuthController controller = new CallbackAuthController();
        PageReference result = controller.callbackAuth();
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('org-connection/' + testRecord.Id));
        
        Org_Connection__c unchangedRecord = [SELECT Status__c, Refresh_Token__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
        System.assertEquals('Not linked', unchangedRecord.Status__c);
        System.assertEquals(null, unchangedRecord.Refresh_Token__c);
    }

    @isTest
    static void callbackAuthTestUserInfoFailureGraceful() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c LIMIT 1];
        setupPageParameters('valid_auth_code_123', testRecord.Id);
        
        Test.setMock(HttpCalloutMock.class, new UserInfoFailureMock());
        
        Test.startTest();
        CallbackAuthController controller = new CallbackAuthController();
        PageReference result = controller.callbackAuth();
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('org-connection/' + testRecord.Id));
        
        Org_Connection__c updatedRecord = [SELECT Status__c, UserName__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
        System.assertEquals('Connected', updatedRecord.Status__c, 'Status should be Connected');
        
        System.assertEquals(null, updatedRecord.UserName__c);
        System.assertEquals(1, controller.errors.size());
        System.assert(controller.errors[0].contains('Username not captured') || controller.errors[0].contains('Error username'));
    }
}