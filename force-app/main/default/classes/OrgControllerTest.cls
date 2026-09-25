@isTest
private class OrgControllerTest {

    @TestSetup
    static void setupTestData() {
        List<Org_Connection__c> testConnections = new List<Org_Connection__c>();
        
        for (Integer i = 1; i <= 5; i++) {
            testConnections.add(new Org_Connection__c(
                Org_Name__c = 'Test Org ' + i,
                Type__c = 'Sandbox',
                Login_Url__c = 'https://test' + i + '.salesforce.com',
                UserName__c = 'testuser' + i + '@example.com',
                Status__c = i == 1 ? 'Connected' : (i == 2 ? 'Failed' : 'Not linked')
            ));
        }

        testConnections.add(new Org_Connection__c(
            Org_Name__c = 'Test Org 2.1',
            Login_Url__c = 'https://test.salesforce.com',
            Instance_Url__c = 'https://my-instance.salesforce.com',
            Refresh_Token__c = 'valid_refresh_token_123',
            Status__c = 'Connected'
        ));

        testConnections.add(new Org_Connection__c(
            Org_Name__c = 'Test Org 2.2',
            Login_Url__c = 'https://test.salesforce.com',
            Status__c = 'Connected'
        ));

        testConnections.add(new Org_Connection__c(
            Org_Name__c = 'Test Org 2.3',
            Login_Url__c = 'https://test.salesforce.com',
            Refresh_Token__c = 'invalid_refresh_token_999',
            Status__c = 'Connected'
        ));
        
        insert testConnections;
    }

    @isTest
    static void getOrgConnectionsTest() {
        Test.startTest();
        List<Org_Connection__c> orgConnections = OrgController.getOrgConnections();
        Test.stopTest();

        System.assertNotEquals(null, orgConnections, 'Expected non-null list of org connections.');
        System.assertEquals(8, orgConnections.size(), 'Expected 5 org connections to be retrieved.');
    }

    @isTest
    static void getOrgConnectionsEmptyTest() {
        delete [SELECT Id FROM Org_Connection__c];

        Test.startTest();
        List<Org_Connection__c> result = OrgController.getOrgConnections();
        Test.stopTest();

        System.assert(result.isEmpty(), 'Result should be empty when no records exist.');
    }

    private static Id getStandardProfileId() {
        return [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1].Id;
    }

    @isTest
    static void checkPermissionAdminWithPermissionTest() {
        CustomPermission cp = [
            SELECT Id, DeveloperName 
            FROM CustomPermission 
            WHERE DeveloperName = 'Manage_org_connection' 
            LIMIT 1
        ];

        PermissionSet ps = new PermissionSet(
            Name = 'Test_Manage_Org_Connection_PS',
            Label = 'Test Manage Org Connection PS'
        );
        insert ps;

        SetupEntityAccess sea = new SetupEntityAccess(
            ParentId = ps.Id,
            SetupEntityId = cp.Id
        );
        insert sea;

        User adminUser = new User(
            Alias = 'admin',
            Email = 'admin' + System.currentTimeMillis() + '@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = getStandardProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'admin' + System.currentTimeMillis() + '@testorg.com'
        );
        insert adminUser;

        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = adminUser.Id,
            PermissionSetId = ps.Id
        );
        insert psa;

        Boolean result;
        Test.startTest();
        System.runAs(adminUser) {
            result = OrgController.checkPermissionAdmin();
        }
        Test.stopTest();

        System.assertEquals(true, result, 'User with Custom Permission should receive true.');
    }

    @isTest
    static void checkPermissionAdminWithoutPermissionTest() {
        User viewerUser = new User(
            Alias = 'viewer',
            Email = 'viewer' + System.currentTimeMillis() + '@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Viewer',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = getStandardProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'viewer' + System.currentTimeMillis() + '@testorg.com'
        );
        insert viewerUser;

        Boolean result;
        Test.startTest();
        System.runAs(viewerUser) {
            result = OrgController.checkPermissionAdmin();
        }
        Test.stopTest();

        System.assertEquals(false, result, 'User without Custom Permission should receive false.');
    }

    @isTest
    static void getOrgConnectionByIdTest() {
        Org_Connection__c testConnection = [SELECT Id FROM Org_Connection__c LIMIT 1];

        Test.startTest();
        Org_Connection__c result = OrgController.getOrgConnectionById(testConnection.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected non-null org connection record.');
        System.assertEquals(testConnection.Id, result.Id, 'Expected the retrieved record to match the test record.');
    }

    @isTest
    static void getOrgConnectionByIdNullIdTest() {
        Test.startTest();
        try {
            OrgController.getOrgConnectionById(null);
            System.assert(false, 'Expected AuraHandledException to be thrown for null ID, but no exception was thrown.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Expected AuraHandledException for null ID.');
        }
        Test.stopTest();
    }

    @isTest
    static void saveOrgConnectionTest() {
        Map<String, Object> orgConnectionData = new Map<String, Object>{
            'Org_Name__c' => 'Test Connection',
            'Type__c' => 'Sandbox',
            'Login_Url__c' => 'https://test.salesforce.com'
        };

        Test.startTest();
        String orgId = OrgController.saveOrgConnection(orgConnectionData);
        Test.stopTest();        

        Org_Connection__c savedConn = [SELECT Id, Org_Name__c, Type__c, Login_Url__c FROM Org_Connection__c WHERE Id = :orgId];
        System.assertNotEquals(null, savedConn, 'Expected the new org connection to be saved.');
        System.assertNotEquals(null, orgId, 'Expected the new org connection Id to be returned.');
        System.assertEquals('Test Connection', savedConn.Org_Name__c, 'Expected the name to match.');
        System.assertEquals('Sandbox', savedConn.Type__c, 'Expected the type to match.');
        System.assertEquals('https://test.salesforce.com', savedConn.Login_Url__c, 'Expected the login URL to match.');
    }

    @isTest
    static void saveOrgConnectionOrgDataIsEmptyTest() {
        Map<String, Object> orgConnectionData = new Map<String, Object>{};

        Test.startTest();
        try {
            OrgController.saveOrgConnection(orgConnectionData);
            System.assert(false, 'Expected AuraHandledException to be thrown for empty org data, but no exception was thrown.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Expected AuraHandledException for empty org data.');
        }
        Test.stopTest();
    }

    @isTest
    static void deleteOrgConnectionSuccessTest() {
        Org_Connection__c recordToDelete = [SELECT Id FROM Org_Connection__c LIMIT 1];
        
        Test.startTest();
        OrgController.deleteOrgConnection(recordToDelete.Id);
        Test.stopTest();

        List<Org_Connection__c> deletedRecords = [SELECT Id FROM Org_Connection__c WHERE Id = :recordToDelete.Id];
        System.assertEquals(0, deletedRecords.size(), 'Expected the org connection to be deleted.');
    }

    @isTest
    static void deleteOrgConnectionInvalidIdTest() {
        Test.startTest();
        try {
            OrgController.deleteOrgConnection(null);
            System.assert(false, 'Expected AuraHandledException to be thrown for null ID, but no exception was thrown.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }
    
    @isTest
    static void disconnectOrgConnectionTest() {
        Org_Connection__c recordToDisconnect = [SELECT Id FROM Org_Connection__c WHERE Status__c = 'Connected' LIMIT 1];

        Test.startTest();
        OrgController.disconnectOrgConnection(recordToDisconnect.Id);
        Test.stopTest();

        Org_Connection__c updatedRecord = [SELECT Id, Status__c, Refresh_Token__c, Instance_Url__c, UserName__c FROM Org_Connection__c WHERE Id = :recordToDisconnect.Id];
        System.assertEquals('Not linked', updatedRecord.Status__c, 'Expected status to be updated to Not linked.');
        System.assertEquals(null, updatedRecord.Refresh_Token__c, 'Expected Refresh Token to be cleared.');
        System.assertEquals(null, updatedRecord.Instance_Url__c, 'Expected Instance URL to be cleared.');
        System.assertEquals(null, updatedRecord.UserName__c, 'Expected User Name to be cleared.');
    }

    @isTest
    static void disconnectOrgConnectionInvalidIdTest() {
        Test.startTest();
        try {
            OrgController.disconnectOrgConnection(null);
            System.assert(false, 'Expected AuraHandledException to be thrown for null ID, but no exception was thrown.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    private class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"access_token": "mocked_access_token_12345", "instance_url": "https://mocked.instance.com"}');
            return res;
        }
    }

    private class FailureHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error": "invalid_grant", "error_description": "refresh token expired"}');
            return res;
        }
    }

    @isTest
    static void openOrgConnectionWithNullIdTest() {
        Test.startTest();
        try {
            OrgController.openOrgConnection(null);
            System.assert(false, 'Expected exception for null ID');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @isTest
    static void openOrgConnectionWithInvalidIdTest() {
        String fakeId = 'a00000000000000AAA';

        Test.startTest();
        try {
            OrgController.openOrgConnection(fakeId);
            System.assert(false, 'Expected exception for non-existent ID');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @isTest
    static void openOrgConnectionSuccessTest() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c WHERE Org_Name__c = 'Test Org 2.1' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.startTest();
        String resultUrl = OrgController.openOrgConnection(testRecord.Id);
        Test.stopTest();

        System.assertNotEquals(null, resultUrl, 'Expected non-null URL for successful response');
        System.assert(resultUrl.contains('frontdoor.jsp'), 'Expected URL to contain frontdoor.jsp');
        System.assert(resultUrl.contains('sid=mocked_access_token_12345'), 'Expected URL to contain the mocked access token');
    }

    @isTest
    static void openOrgConnectionFailureTest() {
        Org_Connection__c testRecord = [SELECT Id FROM Org_Connection__c WHERE Org_Name__c = 'Test Org 2.1' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Test.startTest();
        String failResult = OrgController.openOrgConnection(testRecord.Id);
        Test.stopTest();

        System.assertEquals(null, failResult, 'Expected null result for failed request');
        
        Org_Connection__c updatedRecord = [SELECT Status__c FROM Org_Connection__c WHERE Id = :testRecord.Id];
        System.assertEquals('Failed', updatedRecord.Status__c, 'Expected status to change to Failed');
    }

    @isTest
    static void getAuthorizationUrlWithNullIdTest() {
        Test.startTest();
        try {
            OrgController.getAuthorizationUrl(null);
            System.assert(false, 'Expected exception for null ID');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @isTest
    static void getAuthorizationUrlWithInvalidIdTest() {
        String fakeId = 'a00000000000000AAA';

        Test.startTest();
        try {
            OrgController.getAuthorizationUrl(fakeId);
            System.assert(false, 'Expected exception for non-existent ID');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @isTest
    static void getAuthorizationUrlTest() {
        Org_Connection__c testRecord = [SELECT Id, Login_Url__c FROM Org_Connection__c WHERE Org_Name__c = 'Test Org 2.1' LIMIT 1];
        String fakeId = 'a00000000000000AAA';

        Test.startTest();
        String authUrl = OrgController.getAuthorizationUrl(testRecord.Id);
        Test.stopTest();

        System.assert(authUrl != null, 'Expected non-null URL');
        System.assert(authUrl.startsWith('https://test.salesforce.com/services/oauth2/authorize'), 'Expected URL to start with the correct base URL');
        System.assert(authUrl.contains('response_type=code'), 'Expected URL to contain response_type=code');
        System.assert(authUrl.contains('scope=full%20refresh_token%20web'), 'Expected URL to contain scope');
        System.assert(authUrl.contains('state=' + testRecord.Id), 'Expected URL to contain state with ID');
    }

    @isTest
    static void connectionStatusCheckTest() {
        Org_Connection__c noTokenRecord = [SELECT Id FROM Org_Connection__c WHERE Org_Name__c = 'Test Org 2.2' LIMIT 1];
        Org_Connection__c invalidTokenRecord = [SELECT Id FROM Org_Connection__c WHERE Org_Name__c = 'Test Org 2.3' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Test.startTest();
        OrgController.connectionStatusCheck();
        Test.stopTest();

        Org_Connection__c updatedNoToken = [SELECT Status__c FROM Org_Connection__c WHERE Id = :noTokenRecord.Id];
        Org_Connection__c updatedInvalidToken = [SELECT Status__c FROM Org_Connection__c WHERE Id = :invalidTokenRecord.Id];
        
        System.assertEquals('Not linked', updatedNoToken.Status__c, 'Expected status for record without token to be Not linked');
        System.assertEquals('Failed', updatedInvalidToken.Status__c, 'Expected status for record with invalid token to be Failed');
    }

    @isTest
    static void isRefreshTokenValidWithValidTokenTest() {
        String loginUrl = 'https://test.salesforce.com';
        String validToken = 'valid_refresh_token_123';

        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.startTest();
        Boolean resultValid = OrgController.isRefreshTokenValid(loginUrl, validToken);
        Test.stopTest();

        System.assertEquals(true, resultValid, 'Expected true for valid refresh token');
    }

    @isTest
    static void isRefreshTokenValidWithInvalidParametersTest() {
        String loginUrl = 'https://test.salesforce.com';
        String validToken = 'valid_refresh_token_123';
        String invalidToken = 'invalid_refresh_token_999';

        Test.startTest();
        Boolean resultBlank = OrgController.isRefreshTokenValid('', validToken);
        Boolean resultNull = OrgController.isRefreshTokenValid(loginUrl, null);
        Test.stopTest();

        System.assertEquals(false, resultBlank, 'Expected false for empty loginUrl');
        System.assertEquals(false, resultNull, 'Expected false for null refreshToken');
    }

    @isTest
    static void isRefreshTokenValidWithInvalidTokenTest() {
        String loginUrl = 'https://test.salesforce.com';
        String invalidToken = 'invalid_refresh_token_999';

        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Test.startTest();
        Boolean resultInvalid = OrgController.isRefreshTokenValid(loginUrl, invalidToken);
        Test.stopTest();

        System.assertEquals(false, resultInvalid, 'Expected false for invalid refresh token');
    }
}