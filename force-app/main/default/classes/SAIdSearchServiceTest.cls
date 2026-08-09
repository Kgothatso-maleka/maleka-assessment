/**
 * Test class for SAIdSearchService
 * get by id (found/not found), get all records (with/without limit), delete all
 */
@isTest
private class SAIdSearchServiceTest {

    private static final String ID_NUM_1 = '9001015800086';
    private static final String ID_NUM_2 = '8501015800087';

    // Builds a valid decode result
    private static SAIdValidator.IdDecodeResult buildValidDecode() {
        SAIdValidator.IdDecodeResult decoded = new SAIdValidator.IdDecodeResult();
        decoded.isValid = true;
        decoded.dateOfBirth = Date.newInstance(1990, 1, 1);
        decoded.gender = 'Male';
        decoded.isSACitizen = true;
        decoded.errorMessage = null;
        return decoded;
    }

    // Builds an invalid decode result
    private static SAIdValidator.IdDecodeResult buildInvalidDecode() {
        SAIdValidator.IdDecodeResult decoded = new SAIdValidator.IdDecodeResult();
        decoded.isValid = false;
        decoded.errorMessage = 'Invalid checksum';
        return decoded;
    }

    @isTest
    static void testSaveIdSearch_InsertSuccess() {
        SAIdValidator.IdDecodeResult decoded = buildValidDecode();

        Test.startTest();
        SAIdSearchService.SaveResult result = SAIdSearchService.saveIdSearch(ID_NUM_1, decoded);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Save should succeed');
        System.assertEquals(true, result.wasInserted, 'Record should be newly inserted');
        System.assertNotEquals(null, result.recordId, 'Record Id should be populated');
        System.assertEquals(ID_NUM_1, result.idNumber, 'ID number should match input');

        SA_ID_Search__c inserted = [
            SELECT SA_ID_Number__c, Date_of_Birth__c, Gender__c, SA_Citizen__c, Search_Count__c
            FROM SA_ID_Search__c
            WHERE SA_ID_Number__c = :ID_NUM_1
        ];
        System.assertEquals(decoded.dateOfBirth, inserted.Date_of_Birth__c);
        System.assertEquals(decoded.gender, inserted.Gender__c);
        System.assertEquals(decoded.isSACitizen, inserted.SA_Citizen__c);
        System.assertEquals(2, (Integer) inserted.Search_Count__c, 'Search count should increment to 2 on first save');
    }

    @isTest
    static void testSaveIdSearch_UpdateExisting_IncrementsCount() {
        SAIdValidator.IdDecodeResult decoded = buildValidDecode();

        Test.startTest();
        SAIdSearchService.SaveResult first = SAIdSearchService.saveIdSearch(ID_NUM_1, decoded);
        SAIdSearchService.SaveResult second = SAIdSearchService.saveIdSearch(ID_NUM_1, decoded);
        Test.stopTest();

        System.assertEquals(true, first.wasInserted, 'First save should be an insert');
        System.assertEquals(false, second.wasInserted, 'Second save should be an update (upsert on external id)');
        System.assertEquals(first.recordId, second.recordId, 'Same record should be reused via upsert');

        SA_ID_Search__c updated = [
            SELECT Search_Count__c FROM SA_ID_Search__c WHERE SA_ID_Number__c = :ID_NUM_1
        ];
        System.assertEquals(3, (Integer) updated.Search_Count__c, 'Search count should increment on repeat save');
    }

    @isTest
    static void testSaveIdSearch_InvalidDecode_ReturnsError() {
        SAIdValidator.IdDecodeResult decoded = buildInvalidDecode();

        Test.startTest();
        SAIdSearchService.SaveResult result = SAIdSearchService.saveIdSearch(ID_NUM_1, decoded);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Save should fail for invalid ID');
        System.assert(result.errorMessage.contains('Cannot save invalid ID'), 'Error message should indicate invalid ID');

        List<SA_ID_Search__c> records = [SELECT Id FROM SA_ID_Search__c WHERE SA_ID_Number__c = :ID_NUM_1];
        System.assertEquals(0, records.size(), 'No record should be created for invalid ID');
    }

    @isTest
    static void testGetSearchRecord_Found() {
        insert new SA_ID_Search__c(
            SA_ID_Number__c = ID_NUM_1,
            Date_of_Birth__c = Date.newInstance(1985, 5, 20),
            Gender__c = 'Female',
            SA_Citizen__c = true,
            Search_Count__c = 3
        );

        Test.startTest();
        SA_ID_Search__c found = SAIdSearchService.getSearchRecord(ID_NUM_1);
        Test.stopTest();

        System.assertNotEquals(null, found, 'Record should be found');
        System.assertEquals(ID_NUM_1, found.SA_ID_Number__c);
    }

    @isTest
    static void testGetSearchRecord_NotFound() {
        Test.startTest();
        SA_ID_Search__c found = SAIdSearchService.getSearchRecord('0000000000000');
        Test.stopTest();

        System.assertEquals(null, found, 'No record should be found for non-existent ID');
    }

    @isTest
    static void testGetAllSearchRecords_WithLimit() {
        insert new List<SA_ID_Search__c>{
            new SA_ID_Search__c(SA_ID_Number__c = ID_NUM_1, Search_Count__c = 5),
            new SA_ID_Search__c(SA_ID_Number__c = ID_NUM_2, Search_Count__c = 10)
        };

        Test.startTest();
        List<SA_ID_Search__c> results = SAIdSearchService.getAllSearchRecords(1);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should respect the limit passed in');
        System.assertEquals(ID_NUM_2, results[0].SA_ID_Number__c, 'Highest search count should be first');
    }

    @isTest
    static void testGetAllSearchRecords_NullLimit_UsesDefault() {
        insert new SA_ID_Search__c(SA_ID_Number__c = ID_NUM_1, Search_Count__c = 1);

        Test.startTest();
        List<SA_ID_Search__c> results = SAIdSearchService.getAllSearchRecords(null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return all records when limit is null');
    }

    @isTest
    static void testGetAllSearchRecords_ZeroOrNegativeLimit_UsesDefault() {
        insert new SA_ID_Search__c(SA_ID_Number__c = ID_NUM_1, Search_Count__c = 1);

        Test.startTest();
        List<SA_ID_Search__c> resultsZero = SAIdSearchService.getAllSearchRecords(0);
        List<SA_ID_Search__c> resultsNegative = SAIdSearchService.getAllSearchRecords(-5);
        Test.stopTest();

        System.assertEquals(1, resultsZero.size(), 'Zero limit should fall back to default max');
        System.assertEquals(1, resultsNegative.size(), 'Negative limit should fall back to default max');
    }

    @isTest
    static void testDeleteAllRecords() {
        insert new List<SA_ID_Search__c>{
            new SA_ID_Search__c(SA_ID_Number__c = ID_NUM_1, Search_Count__c = 1),
            new SA_ID_Search__c(SA_ID_Number__c = ID_NUM_2, Search_Count__c = 2)
        };

        Test.startTest();
        SAIdSearchService.deleteAllRecords();
        Test.stopTest();

        List<SA_ID_Search__c> remaining = [SELECT Id FROM SA_ID_Search__c];
        System.assertEquals(0, remaining.size(), 'All records should be deleted');
    }

    @isTest
    static void testDeleteAllRecords_EmptyTable_NoError() {
        Test.startTest();
        SAIdSearchService.deleteAllRecords();
        Test.stopTest();

        List<SA_ID_Search__c> remaining = [SELECT Id FROM SA_ID_Search__c];
        System.assertEquals(0, remaining.size(), 'Should handle empty table without error');
    }
}