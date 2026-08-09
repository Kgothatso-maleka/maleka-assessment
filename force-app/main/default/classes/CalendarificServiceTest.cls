@IsTest
private class CalendarificServiceTest {

    /**
     * Mock successful Calendarific API response
     */
    private class SuccessfulResponseMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            System.assertEquals('GET', req.getMethod());
            System.assert(req.getEndpoint().contains('calendarific.com'));
            System.assert(req.getEndpoint().contains('country=ZA'));
            System.assert(req.getEndpoint().contains('year=2026'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{' +
                    '"response": {' +
                        '"holidays": [' +
                            '{' +
                                '"name": "New Year\'s Day",' +
                                '"description": "New Year\'s Day",' +
                                '"date": {' +
                                    '"iso": "2026-01-01"' +
                                '},' +
                                '"type": ["National holiday"]' +
                            '},' +
                            '{' +
                                '"name": "Human Rights Day",' +
                                '"description": "Human Rights Day",' +
                                '"date": {' +
                                    '"iso": "2026-03-21"' +
                                '},' +
                                '"type": ["National holiday"]' +
                            '}' +
                        ']' +
                    '}' +
                '}'
            );

            return res;
        }
    }


    /**
     * Mock response with no holidays
     */
    private class EmptyHolidayResponseMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{' +
                    '"response": {' +
                        '"holidays": []' +
                    '}' +
                '}'
            );

            return res;
        }
    }


    /**
     * Mock 400 Bad Request response
     */
    private class BadRequestMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody(
                '{"error":"Invalid request"}'
            );

            return res;
        }
    }


    /**
     * Mock 500 Internal Server Error
     */
    private class ServerErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody(
                '{"error":"Internal server error"}'
            );

            return res;
        }
    }


    /**
     * Mock API-level error returned with HTTP 200
     */
    private class ApiErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{' +
                    '"error": "Invalid API key"' +
                '}'
            );

            return res;
        }
    }


    /**
     * Mock malformed JSON response
     */
    private class MalformedJsonMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{invalid-json-response'
            );

            return res;
        }
    }


    /**
     * Test: null year
     */
    @IsTest
    static void testNullYear() {

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(null);

        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('Invalid year: null', result.errorMessage);
        System.assertEquals(0, result.retryCount);
        System.assertEquals(0, result.holidays.size());
    }


    /**
     * Test: year below allowed range
     */
    @IsTest
    static void testYearBelowMinimum() {

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(1899);

        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('Invalid year: 1899', result.errorMessage);
        System.assertEquals(0, result.retryCount);
    }


    /**
     * Test: year above allowed range
     */
    @IsTest
    static void testYearAboveMaximum() {

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(2101);

        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('Invalid year: 2101', result.errorMessage);
        System.assertEquals(0, result.retryCount);
    }


    /**
     * Test: successful API call
     */
    @IsTest
    static void testSuccessfulResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessfulResponseMock()
        );

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(2026);

        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        System.assertEquals(null, result.errorMessage);

        System.assertEquals(2, result.holidays.size());

        CalendarificService.Holiday firstHoliday =
            result.holidays[0];

        System.assertEquals(
            'New Year\'s Day',
            firstHoliday.name
        );

        System.assertEquals(
            '2026-01-01',
            firstHoliday.date_x
        );

        System.assertEquals(
            'New Year\'s Day',
            firstHoliday.description
        );

        System.assertEquals(
            'National holiday',
            firstHoliday.type
        );
    }


    /**
     * Test: API returns successfully but no holidays
     */
    @IsTest
    static void testNoHolidaysFound() {

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyHolidayResponseMock()
        );

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(2026);

        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        System.assertEquals(
            'No holidays found',
            result.errorMessage
        );

        System.assertEquals(
            0,
            result.holidays.size()
        );
    }


    /**
     * Test: HTTP 400 response
     *
     * 400 is non-retryable.
     */
    @IsTest
    static void testBadRequestResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new BadRequestMock()
        );

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(2026);

        Test.stopTest();

        System.assertEquals(false, result.isSuccess);

        System.assertEquals(
            'API returned status: 400',
            result.errorMessage
        );
    }


    /**
     * Test: HTTP 500 response
     *
     * 500 is retryable.
     */
    @IsTest
    static void testServerErrorResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new ServerErrorMock()
        );

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(2026);

        Test.stopTest();

        System.assertEquals(false, result.isSuccess);

        System.assert(
            result.errorMessage.contains('500')
        );

        System.assert(
            result.errorMessage.contains('retryable')
        );
    }


    /**
     * Test: API returns an error inside a 200 response
     */
    @IsTest
    static void testApiErrorResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new ApiErrorMock()
        );

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(2026);

        Test.stopTest();

        System.assertEquals(false, result.isSuccess);

        System.assertEquals(
            'API Error: Invalid API key',
            result.errorMessage
        );
    }


    /**
     * Test: malformed JSON response
     */
    @IsTest
    static void testMalformedJsonResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new MalformedJsonMock()
        );

        Test.startTest();

        CalendarificService.HolidayResult result =
            CalendarificService.getHolidaysByYear(2026);

        Test.stopTest();

        System.assertEquals(false, result.isSuccess);

        System.assert(
            result.errorMessage.startsWith(
                'Failed to parse response:'
            )
        );
    }
}