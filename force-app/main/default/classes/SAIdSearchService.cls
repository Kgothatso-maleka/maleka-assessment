/**

Handles database operations for SA ID searches

Uses upsert pattern with external ID for atomic operations
*/
public class SAIdSearchService {
    
    public class SaveResult {
        public Boolean isSuccess;
        public String errorMessage;
        public String recordId;
        public String idNumber;
        public Boolean wasInserted;
    }
    
    /**
	@param idNumber The SA ID number
	@param decodedInfo The decoded information from the ID
	@return SaveResult with operation status
	*/
    public static SaveResult saveIdSearch(String idNumber, SAIdValidator.IdDecodeResult decodedInfo) {
        SaveResult result = new SaveResult();
        result.idNumber = idNumber;
        
        if (!decodedInfo.isValid) {
            result.isSuccess = false;
            result.errorMessage = 'Cannot save invalid ID: ' + decodedInfo.errorMessage;
            return result;
        }
        
        try {
            // Create or get existing record
            SA_ID_Search__c searchRecord = new SA_ID_Search__c();
            searchRecord.SA_ID_Number__c = idNumber;
            searchRecord.Date_of_Birth__c = decodedInfo.dateOfBirth;
            searchRecord.Gender__c = decodedInfo.gender;
            searchRecord.SA_Citizen__c = decodedInfo.isSACitizen;
            
            Database.UpsertResult upsertResult = Database.upsert(
                searchRecord,
                SA_ID_Search__c.SA_ID_Number__c,
                true
            );
            
            if (upsertResult.isSuccess()) {
                result.recordId = upsertResult.getId();
                result.isSuccess = true;
                result.wasInserted = upsertResult.isCreated();
                
                
                incrementSearchCount(idNumber);
                
            } else {
                result.isSuccess = false;
                String errors = '';
                for (Database.Error err : upsertResult.getErrors()) {
                    errors += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                }
                result.errorMessage = 'Upsert failed: ' + errors;
            }
            
            
        } catch (DmlException e) {
            result.isSuccess = false;
            result.errorMessage = 'DML Error: ' + e.getMessage();
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    /**
	Retrieves existing search record if one exists
	@param idNumber The SA ID number to search for
	@return The search record or null if not found
	*/
    public static SA_ID_Search__c getSearchRecord(String idNumber) {
        try {
            List<SA_ID_Search__c> records = [
                SELECT Id, SA_ID_Number__c, Date_of_Birth__c, Gender__c,
                SA_Citizen__c, Search_Count__c
                FROM SA_ID_Search__c
                WHERE SA_ID_Number__c = :idNumber
                LIMIT 1
            ];
            
            return records.isEmpty() ? null : records[0];
            
            
        } catch (QueryException e) {
            System.debug('Query error: ' + e.getMessage());
            return null;
        }
    }
    /**
	Increments the search counter for a given ID
	Called after successful save
	*/
    private static void incrementSearchCount(String idNumber) {
        try {
            SA_ID_Search__c record = getSearchRecord(idNumber);
            
            if (record != null) {
                // Increment counter (use Math to avoid null pointer)
                Integer currentCount = record.Search_Count__c != null ?
                    (Integer) record.Search_Count__c : 0;
                record.Search_Count__c = currentCount + 1;
                
                // Update without need for external ID again
                Database.update(record, true);
            }
            
            
        } catch (DmlException e) {
            System.debug('Error incrementing search count: ' + e.getMessage());
            // Non-critical error - don't throw
        }
    }
    /**
	Gets all search records for analytics/reporting
	@param limitRows Maximum number of records to return
	@return List of search records ordered by search count
	*/
    public static List<SA_ID_Search__c> getAllSearchRecords(Integer limitRows) {
        if (limitRows == null || limitRows <= 0) {
            limitRows = 10000; // Salesforce max
        }
        
        try {
            return [
                SELECT Id, SA_ID_Number__c, Date_of_Birth__c, Gender__c,
                SA_Citizen__c, Search_Count__c, CreatedDate
                FROM SA_ID_Search__c
                ORDER BY Search_Count__c DESC, CreatedDate DESC
                LIMIT :limitRows
            ];
            
        } catch (QueryException e) {
            System.debug('Error fetching records: ' + e.getMessage());
            return new List<SA_ID_Search__c>();
        }
    }
    /**
	Deletes all search records (for testing/cleanup)
	Use with caution in production
	*/
    public static void deleteAllRecords() {
        try {
            List<SA_ID_Search__c> allRecords = [
                SELECT Id FROM SA_ID_Search__c
            ];
            
            if (!allRecords.isEmpty()) {
                Database.delete(allRecords, true);
            }
            
            
        } catch (Exception e) {
            System.debug('Error deleting records: ' + e.getMessage());
        }
    }
}