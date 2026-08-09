/**
 * Test class for SAIdHolidayController
 * The HttpCalloutMock below is a best-guess JSON shape — verify/adjust once
 * CalendarificService.getHolidaysByYear() parsing logic is confirmed.
 */
@isTest
private class SAIdHolidayControllerTest {

    // Male, SA citizen, DOB 1990-01-01 (Luhn-valid)
    private static final String VALID_ID = '9001015800088';
    private static final String INVALID_FORMAT_ID = '123456789012';

    // Best-guess Calendarific-style success payload — ADJUST to match actual parsing
    private class HolidaySuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"response":{"holidays":[' +
                '{"name":"New Year\'s Day","date":{"iso":"1990-01-01"},"description":"Public holiday","type":["National holiday"]}' +
            ']}}');
            return res;
        }
    }

    private class HolidayFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Service unavailable"}');
            return res;
        }
    }

    @isTest
    static void testSearchIdAndHolidays_Success() {
        Test.setMock(HttpCalloutMock.class, new HolidaySuccessMock());

        Test.startTest();
        SAIdHolidayController.SearchResponse response = SAIdHolidayController.searchIdAndHolidays(VALID_ID);
        Test.stopTest();

        System.assertEquals(true, response.isSuccess, 'Should succeed for a valid ID');
        System.assertNotEquals(null, response.decodedInfo, 'Decoded info should be populated');
        System.assertEquals('Male', response.decodedInfo.gender);
        System.assertEquals(true, response.decodedInfo.isSACitizen);
        System.assertNotEquals(null, response.recordId, 'Record should have been saved');
        System.assertEquals(2, response.searchCount, 'First search should have count of 2');

        SA_ID_Search__c saved = [SELECT SA_ID_Number__c FROM SA_ID_Search__c WHERE SA_ID_Number__c = :VALID_ID];
        System.assertEquals(VALID_ID, saved.SA_ID_Number__c);
    }

    @isTest
    static void testSearchIdAndHolidays_InvalidIdFormat_ReturnsEarly() {
        Test.startTest();
        SAIdHolidayController.SearchResponse response = SAIdHolidayController.searchIdAndHolidays(INVALID_FORMAT_ID);
        Test.stopTest();

        System.assertEquals(false, response.isSuccess);
        System.assertNotEquals(null, response.errorMessage);
        System.assertEquals(null, response.decodedInfo, 'Should not decode invalid ID');
        System.assertEquals(null, response.recordId, 'Should not save invalid ID');

        List<SA_ID_Search__c> records = [SELECT Id FROM SA_ID_Search__c];
        System.assertEquals(0, records.size(), 'No record should be created for invalid ID');
    }

    @isTest
    static void testSearchIdAndHolidays_HolidayServiceFails_StillSavesAndSucceeds() {
        Test.setMock(HttpCalloutMock.class, new HolidayFailureMock());

        Test.startTest();
        SAIdHolidayController.SearchResponse response = SAIdHolidayController.searchIdAndHolidays(VALID_ID);
        Test.stopTest();

        // Per controller logic: holiday failure does NOT fail the overall response
        System.assertEquals(true, response.isSuccess, 'Should still succeed when only holiday lookup fails');
        System.assert(response.errorMessage != null && response.errorMessage.contains('Could not retrieve holidays'),
            'Should surface holiday failure in errorMessage while still succeeding');
        System.assertNotEquals(null, response.recordId, 'ID should still be saved even if holidays fail');
    }

    @isTest
    static void testSearchIdAndHolidays_NullInput_HandledGracefully() {
        Test.startTest();
        SAIdHolidayController.SearchResponse response = SAIdHolidayController.searchIdAndHolidays(null);
        Test.stopTest();

        System.assertEquals(false, response.isSuccess);
        System.assertNotEquals(null, response.errorMessage);
    }

    @isTest
    static void testValidateIdNumber_ValidId() {
        Test.startTest();
        Map<String, Object> result = SAIdHolidayController.validateIdNumber(VALID_ID);
        Test.stopTest();

        System.assertEquals(true, result.get('isValid'));
        System.assertEquals('Male', result.get('gender'));
        System.assertNotEquals(null, result.get('dateOfBirth'));
    }

    @isTest
    static void testValidateIdNumber_InvalidId() {
        Test.startTest();
        Map<String, Object> result = SAIdHolidayController.validateIdNumber(INVALID_FORMAT_ID);
        Test.stopTest();

        System.assertEquals(false, result.get('isValid'));
        System.assertNotEquals(null, result.get('message'));
        System.assertEquals(false, result.containsKey('gender'), 'Should not include gender for invalid ID');
    }

    @isTest
    static void testGetSearchStatistics_ReturnsCounts() {
        insert new List<SA_ID_Search__c>{
            new SA_ID_Search__c(SA_ID_Number__c = '9001015800088', Gender__c = 'Male', SA_Citizen__c = true, Search_Count__c = 3),
            new SA_ID_Search__c(SA_ID_Number__c = '8505203000187', Gender__c = 'Female', SA_Citizen__c = false, Search_Count__c = 2)
        };

        Test.startTest();
        Map<String, Object> stats = SAIdHolidayController.getSearchStatistics();
        Test.stopTest();

        System.assertEquals(2, stats.get('totalRecords'));
        System.assertEquals(5, stats.get('totalSearches'));
        System.assertEquals(1, stats.get('citizenCount'));

        System.assertEquals(0, stats.get('maleCount'));
        System.assertEquals(0, stats.get('femaleCount'));
    }

    @isTest
    static void testGetSearchStatistics_NoRecords() {
        Test.startTest();
        Map<String, Object> stats = SAIdHolidayController.getSearchStatistics();
        Test.stopTest();

        System.assertEquals(0, stats.get('totalRecords'));
        System.assertEquals(0, stats.get('totalSearches'));
    }
}