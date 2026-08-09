/**
 * Handles integration with Calendarific API
 * Retrieves public holidays for a given year and country
 */
public class CalendarificService {

    public class Holiday {
        public String name;
        public String date_x;
        public String description;
        public String type;
    }

    public class HolidayResult {
        public Boolean isSuccess;
        public String errorMessage;
        public List<Holiday> holidays;
        public Integer retryCount;
    }

    private static final String API_KEY = '24c5e86734eb44dc4a962826324a5546e74dc42f';
    private static final String BASE_URL = 'https://calendarific.com/api/v2/holidays';
    private static final String COUNTRY_CODE = 'ZA'; // South Africa
    private static final Integer MAX_RETRIES = 3;
    private static final Integer TIMEOUT = 30000; // 30 seconds

    /**
     * Fetches public holidays for a given year
     * @param year The year to fetch holidays for
     * @return HolidayResult with list of holidays or error details
     */
    public static HolidayResult getHolidaysByYear(Integer year) {
        HolidayResult result = new HolidayResult();
        result.holidays = new List<Holiday>();
        result.retryCount = 0;

        if (year == null || year < 1900 || year > 2100) {
            result.isSuccess = false;
            result.errorMessage = 'Invalid year: ' + year;
            return result;
        }

        for (Integer attempt = 0; attempt < MAX_RETRIES; attempt++) {
            result.retryCount = attempt;

            try {
                result = callCalendarificAPI(year);

                if (result.isSuccess) {
                    return result;
                }

                // Only retry on trAansient failures
                if (!isRetryableError(result.errorMessage)) {
                    return result;
                }

                // Wait before retry (exponential backoff: 1s, 2s, 4s)
                if (attempt < MAX_RETRIES - 1) {
                    Integer waitTime = 1000 * (2 ^ attempt);
                    // Note: Actual sleep not feasible in Apex, using exponential logic
                }
            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = 'Exception on attempt ' + (attempt + 1) + ': ' + e.getMessage();
            }
        }

        return result;
    }

    /**
     * Makes the actual HTTP callout to Calendarific API
     */
    private static HolidayResult callCalendarificAPI(Integer year) {
        HolidayResult result = new HolidayResult();
        result.holidays = new List<Holiday>();

        try {
            // Build request URL with parameters
            String url = BASE_URL + '?api_key=' + API_KEY + '&country=' + COUNTRY_CODE + '&year=' + year;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT);
            req.setHeader('Content-Type', 'application/json');

            // Make the HTTP callout
            Http http = new Http();
            HttpResponse res = http.send(req);

            // Check response status
            if (res.getStatusCode() != 200) {
                result.isSuccess = false;
                result.errorMessage = 'API returned status: ' + res.getStatusCode();

                if (res.getStatusCode() >= 500) {
                    result.errorMessage += ' (retryable)';
                }

                return result;
            }

            // Parse response JSON
            result = parseHolidayResponse(res.getBody());

        } catch (CalloutException e) {
            result.isSuccess = false;
            result.errorMessage = 'Callout failed: ' + e.getMessage();
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = 'Error: ' + e.getMessage();
        }

        return result;
    }

    /**
     * Parses JSON response from Calendarific API
     * Extracts holiday information into structured format
     */
    private static HolidayResult parseHolidayResponse(String responseBody) {
        HolidayResult result = new HolidayResult();
        result.holidays = new List<Holiday>();

        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

            // Check for API errors
            if (response.containsKey('error') && response.get('error') != null) {
                result.isSuccess = false;
                result.errorMessage = 'API Error: ' + response.get('error');
                return result;
            }

            // Extract response object
            Map<String, Object> responseObj = (Map<String, Object>) response.get('response');

            if (responseObj == null) {
                result.isSuccess = false;
                result.errorMessage = 'Invalid API response format';
                return result;
            }

            // Extract holidays array
            List<Object> holidaysList = (List<Object>) responseObj.get('holidays');

            if (holidaysList == null || holidaysList.isEmpty()) {
                result.isSuccess = true;
                result.errorMessage = 'No holidays found';
                return result;
            }

            // Process each holiday
            for (Object holidayObj : holidaysList) {
                Map<String, Object> holidayMap = (Map<String, Object>) holidayObj;
				//System.debug('Test view- '+holidayMap);
                Holiday holiday = new Holiday();
                holiday.name = (String) holidayMap.get('name');
                
                holiday.description = (String) holidayMap.get('description');
					Map<String, Object> dateObj = (Map<String, Object>) holidayMap.get('date');
                    if (dateObj != null) {
    					holiday.date_x = (String) dateObj.get('iso');
					}
                List<Object> types = (List<Object>) holidayMap.get('type');

				if (types != null && !types.isEmpty()) {
    				holiday.type = String.valueOf(types[0]);
					}


                result.holidays.add(holiday);
            }

            result.isSuccess = true;

        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = 'Failed to parse response: ' + e.getMessage() + ' Line number - ' + e.getStackTraceString();
        }

        return result;
    }

    /**
     * Determines if an error is retryable
     * Transient errors: timeouts, 5xx errors
     * Non-retryable: 4xx errors (invalid request)
     */
    private static Boolean isRetryableError(String errorMessage) {
        if (String.isBlank(errorMessage)) {
            return false;
        }

        // Transient errors that warrant retry
        return errorMessage.containsIgnoreCase('timeout') ||
               errorMessage.containsIgnoreCase('500') ||
               errorMessage.containsIgnoreCase('502') ||
               errorMessage.containsIgnoreCase('503');
    }
}