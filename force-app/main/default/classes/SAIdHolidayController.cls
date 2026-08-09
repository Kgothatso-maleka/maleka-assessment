/**
 * Apex Controller for SA ID Holiday Checker LWC
 * Orchestrates the flow between UI and backend services
 */
public with sharing class SAIdHolidayController {

    public class SearchResponse {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public IdDecodeInfo decodedInfo;
        @AuraEnabled public List<HolidayInfo> holidays;
        @AuraEnabled public String recordId;
        @AuraEnabled public Integer searchCount;
    }

    public class IdDecodeInfo {
        @AuraEnabled public String idNumber;
        @AuraEnabled public String dateOfBirth;
        @AuraEnabled public String gender;
        @AuraEnabled public Boolean isSACitizen;
    }

    public class HolidayInfo {
        @AuraEnabled public String name;
        @AuraEnabled public String date_x;
        @AuraEnabled public String description;
        @AuraEnabled public String type;
    }

    /**
     * Validates an SA ID number and retrieves holidays for the birth year
     * Main entry point from LWC
     * @param idNumber The SA ID number to search
     * @return SearchResponse with validation result, decoded info, and holidays
     */
    @AuraEnabled(cacheable=false)
    public static SearchResponse searchIdAndHolidays(String idNumber) {
        SearchResponse response = new SearchResponse();

        try {
            //Validate and decode ID
            SAIdValidator.IdDecodeResult validationResult = SAIdValidator.validateAndDecode(idNumber);
			
            if (!validationResult.isValid) {
                response.isSuccess = false;
                response.errorMessage = validationResult.errorMessage;
                return response;
            }
			// Fetch holidays for the birth year
            Integer birthYear = validationResult.dateOfBirth.year();
            CalendarificService.HolidayResult holidayResult = CalendarificService.getHolidaysByYear(birthYear);	
            // Save to database and get record details
            SAIdSearchService.SaveResult saveResult = SAIdSearchService.saveIdSearch(
                idNumber,
                validationResult
            );

            if (!saveResult.isSuccess) {
                response.isSuccess = false;
                response.errorMessage = 'Failed to save search: ' + saveResult.errorMessage;
                return response;
            }

            //Get updated record to retrieve search count
            SA_ID_Search__c savedRecord = SAIdSearchService.getSearchRecord(idNumber);

            

            if (!holidayResult.isSuccess) {
                // We still return success with saved ID but no holidays
                response.isSuccess = true;
                response.errorMessage = 'Could not retrieve holidays: ' + holidayResult.errorMessage;
            } else {
                response.isSuccess = true;
                response.holidays = transformHolidays(holidayResult.holidays);
            }

            // Build response with all information
            response.decodedInfo = new IdDecodeInfo();
            response.decodedInfo.idNumber = validationResult.idNumber;
            response.decodedInfo.dateOfBirth = validationResult.dateOfBirth.format();
            response.decodedInfo.gender = validationResult.gender;
            response.decodedInfo.isSACitizen = validationResult.isSACitizen;

            response.recordId = saveResult.recordId;
            if (savedRecord != null) {
                response.searchCount = (Integer) savedRecord.Search_Count__c;
            }

        } catch (Exception e) {
            response.isSuccess = false;
            response.errorMessage = 'Unexpected error: ' + e.getMessage();
            System.debug('Error in searchIdAndHolidays: ' + e.getStackTraceString());
        }

        return response;
    }

    /**
     * Validates an SA ID number without saving or fetching holiday
     * @param idNumber The SA ID to validate
     * @return Map with validation status and message
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> validateIdNumber(String idNumber) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            SAIdValidator.IdDecodeResult validationResult = SAIdValidator.validateAndDecode(idNumber);

            result.put('isValid', validationResult.isValid);
            result.put('message', validationResult.errorMessage);

            if (validationResult.isValid) {
                result.put('dateOfBirth', validationResult.dateOfBirth.format());
                result.put('gender', validationResult.gender);
            }

        } catch (Exception e) {
            result.put('isValid', false);
            result.put('message', 'Validation error: ' + e.getMessage());
        }

        return result;
    }

    /**
     * Retrieves statistics about ID searches
     * Used for analytics dashboard
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSearchStatistics() {
        Map<String, Object> stats = new Map<String, Object>();

        try {
            List<SA_ID_Search__c> allRecords = SAIdSearchService.getAllSearchRecords(10000);

            Integer totalSearches = 0;
            Integer maleCount = 0;
            Integer femaleCount = 0;
            Integer citizenCount = 0;

            for (SA_ID_Search__c record : allRecords) {
                totalSearches += (Integer) record.Search_Count__c;

                if ('Male'.equals(record.Gender__c)) {
                    maleCount++;
                } else if ('Female'.equals(record.Gender__c)) {
                    femaleCount++;
                }

                if (record.SA_Citizen__c) {
                    citizenCount++;
                }
            }

            stats.put('totalRecords', allRecords.size());
            stats.put('totalSearches', totalSearches);
            stats.put('maleCount', maleCount);
            stats.put('femaleCount', femaleCount);
            stats.put('citizenCount', citizenCount);

        } catch (Exception e) {
            System.debug('Error getting statistics: ' + e.getMessage());
            stats.put('error', e.getMessage());
        }

        return stats;
    }

    /**
     * Transforms CalendarificService holidays to LWC format
     */
    private static List<HolidayInfo> transformHolidays(List<CalendarificService.Holiday> holidays) {
        List<HolidayInfo> result = new List<HolidayInfo>();

        for (CalendarificService.Holiday holiday : holidays) {
            HolidayInfo info = new HolidayInfo();
            info.name = holiday.name;
            info.date_x = holiday.date_x;
            info.description = holiday.description;
            info.type = holiday.type;
            result.add(info);
        }

        return result;
    }
}