public class SAIdValidator {
    public class IdDecodeResult{
        public Boolean isValid;
        public String errorMessage;
        public Date dateOfBirth;
        public String gender;
        public Boolean isSACitizen;
        public String idNumber;
    }

    private static final Integer VALID_ID_LENGTH = 13;
    private static final String MALE = 'Male';
    private static final String FEMALE = 'Female';

    public static IdDecodeResult validateAndDecode(String idNumber){
        IdDecodeResult result = new IdDecodeResult();

        // Remove whitespace upfront
        if(String.isNotBlank(idNumber)){
            idNumber = idNumber.replaceAll('\\s+','').trim();
        }

        result.idNumber = idNumber;

        // validate format
        if(!isValidFormat(idNumber)){
            result.isValid = false;
            result.errorMessage = 'Invalid Id Number. Id number must exactly be 13 digits and the format must be numbers only.';
            return result;
        }

        if(!validateLuhnCheckSum(idNumber)){
            result.isValid = false;
            result.errorMessage = 'Invalid Id Number. validation failed.';
            return result;
        }
        try{
            result.dateOfBirth = decodeDateOfBirth(idNumber);
        }catch(Exception e){
            result.isValid = false;
            result.errorMessage = 'Invalid date of birth in Id number.';
            return result;
        }

        //Decode Gender
        Integer genderDigit = Integer.valueOf(idNumber.substring(6,7));
        result.gender = genderDigit<5? FEMALE : MALE;

        //decode citizenship
        Integer citizenshipDigit = Integer.valueOf(idNumber.substring(10,11));
        if(citizenshipDigit==0){
            result.isSACitizen = true;
        }else if(citizenshipDigit==1){
            result.isSACitizen = false;
        }else{
            result.isValid = false;
            result.errorMessage = 'Invalid Citizenship in Id number.';
            return result;
        }

        result.isValid = true;
        return result;
    }

    private static Boolean isValidFormat(String idNumber){
        //check if is blank
        if(String.isBlank(idNumber)){
            return false;
        }

        //vallidate the length
        if(idNumber.length()!=VALID_ID_LENGTH){
            return false;
        }

        //must contain only digits
        Pattern digitPattern = Pattern.compile('^[0-9]+$');
        Matcher matcher = digitPattern.matcher(idNumber);

        if (!matcher.matches()) {
            return false;
        }

        return true;
    }

    private static Boolean validateLuhnCheckSum(String idNumber){
    Integer sum = 0;
    Boolean isSecond = true;  // was: false — doubling must start on the digit right before the check digit
    for(Integer i = idNumber.length() - 2; i >= 0; i--){
        Integer digit = Integer.valueOf(idNumber.substring(i, i+1));
        if(isSecond){
            digit = digit * 2;
            if(digit > 9){
                digit = digit - 9;
            }
        }
        sum += digit;
        isSecond = !isSecond;
    }
    Integer checkDigit = Math.mod(10 - Math.mod(sum, 10), 10);
    Integer actualCheckDigit = Integer.valueOf(idNumber.substring(12, 13));
    return checkDigit == actualCheckDigit;
}

    private static Date decodeDateOfBirth(String idNumber){
        Integer year = Integer.valueOf(idNumber.substring(0,2));
        Integer month = Integer.valueOf(idNumber.substring(2,4));
        Integer day = Integer.valueOf(idNumber.substring(4,6));

        Integer fullYear = year > 26 ? 1900 + year : 2000 + year;

        if(month < 1 || month > 12){
            throw new IllegalArgumentException('Invalid month: '+month);
        }

        if(day <1 || day>31){
            throw new IllegalArgumentException('Invalid Day: '+day);
        }

        if(!isValidDayForMonth(day, month, fullYear)){
            throw new IllegalArgumentException('Invalid day for month: '+day);
        }

        try{
            return Date.newinstance(fullYear,month,day);
        }catch(Exception e){
            throw new IllegalArgumentException('Invalid date: '+ fullYear + '-'+month+'-'+day);
        }
    }

    private static Boolean isValidDayForMonth(Integer day, Integer month, Integer year){
        Integer maxDays;

        if(month == 2){
            Boolean isLeapYear = (Math.mod(year, 4) == 0 && Math.mod(year, 100) != 0) || (Math.mod(year, 400) == 0);
            maxDays = isLeapYear ? 29 : 28;
        } else if(month == 4 || month == 6 || month == 9 || month == 11){
            maxDays = 30;
        } else {
            maxDays = 31;
        }

        return day >= 1 && day <= maxDays;
    }
}