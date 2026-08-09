/**
 * Test class for SAIdValidator
 * Valid SA ID numbers below have correctly computed Luhn check digits.
 */
@isTest
private class SAIdValidatorTest {

    // Male, SA citizen, DOB 1990-01-01
    private static final String VALID_MALE_SA_CITIZEN = '9001015800088';
    // Female, non-citizen, DOB 1985-05-20
    private static final String VALID_FEMALE_NON_CITIZEN = '8505203000187';
    // Valid Luhn, but month = 13 (invalid)
    private static final String INVALID_MONTH_ID = '9013015800083';
    // Valid Luhn, but Feb 30 in a non-leap year (invalid day for month)
    private static final String INVALID_DAY_ID = '9902305800086';
    // Valid Luhn, but citizenship digit = 5 (only 0/1 allowed)
    private static final String INVALID_CITIZENSHIP_ID = '9001015800583';

    @isTest
    static void testValidateAndDecode_ValidMaleSACitizen() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(VALID_MALE_SA_CITIZEN);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'ID should be valid');
        System.assertEquals(Date.newInstance(1990, 1, 1), result.dateOfBirth);
        System.assertEquals('Male', result.gender);
        System.assertEquals(true, result.isSACitizen);
        System.assertEquals(null, result.errorMessage);
    }

    @isTest
    static void testValidateAndDecode_ValidFemaleNonCitizen() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(VALID_FEMALE_NON_CITIZEN);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'ID should be valid');
        System.assertEquals(Date.newInstance(1985, 5, 20), result.dateOfBirth);
        System.assertEquals('Female', result.gender);
        System.assertEquals(false, result.isSACitizen);
    }

    @isTest
    static void testValidateAndDecode_WhitespaceIsStripped() {
        String withWhitespace = ' 9001015 800088 ';

        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(withWhitespace);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Whitespace should be stripped before validation');
        System.assertEquals(VALID_MALE_SA_CITIZEN, result.idNumber, 'Stored idNumber should have whitespace removed');
    }

    @isTest
    static void testValidateAndDecode_NullInput() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(null);
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('13 digits'), 'Should return format error message');
    }

    @isTest
    static void testValidateAndDecode_BlankInput() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode('   ');
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('13 digits'), 'Should return format error message');
    }

    @isTest
    static void testValidateAndDecode_TooShort() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode('123456789012');
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('13 digits'), 'Should flag incorrect length');
    }

    @isTest
    static void testValidateAndDecode_TooLong() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode('12345678901234');
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('13 digits'), 'Should flag incorrect length');
    }

    @isTest
    static void testValidateAndDecode_NonDigitCharacters() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode('900101580008A');
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('numbers only'), 'Should flag non-digit characters');
    }

    @isTest
    static void testValidateAndDecode_InvalidChecksum() {
        // Same as valid male ID but last digit altered to break the Luhn check
        String badChecksum = '9001015800089';

        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(badChecksum);
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('validation failed'), 'Should flag checksum failure');
    }

    @isTest
    static void testValidateAndDecode_InvalidMonth() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(INVALID_MONTH_ID);
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('Invalid date of birth'), 'Should flag invalid month');
    }

    @isTest
    static void testValidateAndDecode_InvalidDayForMonth() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(INVALID_DAY_ID);
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('Invalid date of birth'), 'Should flag Feb 30 as invalid day for month');
    }

    @isTest
    static void testValidateAndDecode_InvalidCitizenshipDigit() {
        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(INVALID_CITIZENSHIP_ID);
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.errorMessage.contains('Invalid Citizenship'), 'Should flag invalid citizenship digit');
    }

    @isTest
    static void testValidateAndDecode_LeapYearFeb29IsValid() {
        // YY=00 -> fullYear 2000 (leap year), MM=02, DD=29, SSSS=5800, C=0, A=8, checksum=6
        String leapYearId = '0002295800086';

        Test.startTest();
        SAIdValidator.IdDecodeResult result = SAIdValidator.validateAndDecode(leapYearId);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Feb 29 2000 should be valid (2000 is a leap year)');
        System.assertEquals(Date.newInstance(2000, 2, 29), result.dateOfBirth);
    }
}