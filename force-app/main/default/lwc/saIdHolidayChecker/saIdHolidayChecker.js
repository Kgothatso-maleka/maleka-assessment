import { LightningElement, track, api } from 'lwc';
import searchIdAndHolidays from '@salesforce/apex/SAIdHolidayController.searchIdAndHolidays';
import validateIdNumber from '@salesforce/apex/SAIdHolidayController.validateIdNumber';

/**
 * Lightning Web Component for SA ID Holiday Checker
 *
 * BEST PRACTICE: Component lifecycle managed through @track reactive properties
 * - Separation of concerns: UI logic separate from business logic
 * - Error handling at component level
 * - Async/await for cleaner code flow
 */
export default class SaIdHolidayChecker extends LightningElement {
    @api title;
    @api description;
    @track idNumber = '';
    @track isLoading = false;
    @track errorMessage = '';
    @track validationMessage = '';
    @track hasResults = false;
    @track decodedInfo = null;
    @track holidays = [];
    @track searchCount = 0;
    @track birthYear = '';
    

    // Validation state
    isValid = false;

    /**
     * Computed property: Disable search button until valid ID entered
     * BEST PRACTICE: Reactive property computed from state
     */
    get isSearchDisabled() {
        return !this.isValid || this.isLoading;
    }

    /**
     * Computed property: Gender display format
     */
    get genderDisplay() {
        if (!this.decodedInfo) return '';
        console.log(JSON.stringify(this.decodedInfo));
        return this.decodedInfo.gender === 'Male' ? 'Male' : 'Female';

    }

    /**
     * Computed property: Citizen display format
     */
    get citizenDisplay() {
        if (!this.decodedInfo) return '';
        return this.decodedInfo.isSACitizen ? 'Yes' : 'No';
    }

    /**
     * Computed property: Check if holidays array has items
     */
    get hasHolidays() {
        return this.holidays && this.holidays.length > 0;
    }

    /**
     * Computed property: Validation message styling
     */
    get validationMessageClass() {
        return this.isValid ? 'slds-text-color_success' : 'slds-text-color_error';
    }

    /**
     * Handles ID number input with real-time validation
     * BEST PRACTICE: Debounce validation calls for performance
     * BEST PRACTICE: Clear previous results on new input
     */
    async handleIdInput(event) {
        this.idNumber = event.target.value.trim();
        this.validationMessage = '';
        this.errorMessage = '';
        this.hasResults = false;

        // Clear results when user modifies input
        if (this.idNumber.length < 13) {
            this.isValid = false;
            this.decodedInfo = null;
            this.holidays = [];
            this.validationMessage = 'ID number must be 13 digits';
            return;
        }

        // Only validate if full length
        if (this.idNumber.length === 13) {
            await this.performValidation();
        }
    }

    /**
     * Validates ID number via Apex controller
     * Non-blocking validation that doesn't fetch holidays
     * BEST PRACTICE: Apex caching on validation for performance
     */
    async performValidation() {
        try {
            const result = await validateIdNumber({ idNumber: this.idNumber });

            this.isValid = result.isValid;

            if (result.isValid) {
                this.validationMessage = '✓ Valid ID Number';
                this.birthYear = new Date(result.dateOfBirth).getFullYear();
            } else {
                this.validationMessage = result.message;
            }

        } catch (error) {
            this.handleError('Validation error: ' + this.getErrorMessage(error));
            this.isValid = false;
        }
    }

    /**
     * Handles search button click
     * Orchestrates full flow: validate → save → fetch holidays
     * BEST PRACTICE: User feedback (loading state) during async operation
     */
    async handleSearch() {
        if (!this.isValid || this.isLoading) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        try {
            // Call Apex method that handles entire flow
            const response = await searchIdAndHolidays({
                idNumber: this.idNumber
            });

            if (response.isSuccess) {
                this.decodedInfo = response.decodedInfo;
                this.searchCount = response.searchCount || 1;
                this.birthYear = new Date(response.decodedInfo.dateOfBirth).getFullYear();

                // Transform holidays data
                this.holidays = this.transformHolidays(response.holidays || []);

                this.hasResults = true;

                // Show warning if no holidays found
                if (!this.hasHolidays && response.errorMessage) {
                    this.handleError(response.errorMessage);
                }

            } else {
                this.handleError(response.errorMessage || 'Search failed');
            }

        } catch (error) {
            this.handleError('Search error: ' + this.getErrorMessage(error));

        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Transforms API holiday response for display
     * Checks if holiday falls on user's birthday
     * BEST PRACTICE: Data transformation keeps component logic clean
     */
    transformHolidays(apiHolidays) {
    if (!apiHolidays || apiHolidays.length === 0) {
        return [];
    }

    const userBirthDate = new Date(this.decodedInfo.dateOfBirth);
    const userBirthMonth = String(userBirthDate.getMonth() + 1).padStart(2, '0');
    const userBirthDay = String(userBirthDate.getDate()).padStart(2, '0');
    const userBirthDateStr = `${userBirthMonth}-${userBirthDay}`;

    return apiHolidays.map(holiday => {
        // Parse date from API response (format: YYYY-MM-DD)
        console.log(JSON.stringify(holiday));
        const holidayDateStr = holiday.date_x.substring(5); // Extract MM-DD
        const isBirthday = holidayDateStr === userBirthDateStr;

        return {
            name: holiday.name,
            date: this.formatDate(holiday.date),
            description: holiday.description || 'Public Holiday',
            type: holiday.type || 'Holiday',
            isbirthday: isBirthday,
            rowClass: isBirthday
                ? 'slds-hint-parent holiday-highlight'
                : 'slds-hint-parent'
        };
    });
}

    /**
     * Formats date from YYYY-MM-DD to readable format
     * BEST PRACTICE: Consistent date formatting for display
     */
    formatDate(dateStr) {
        try {
            const date = new Date(dateStr + 'T00:00:00Z');
            return new Intl.DateTimeFormat('en-ZA', {
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            }).format(date);
        } catch (error) {
            return dateStr;
        }
    }

    /**
     * Handles and displays error messages
     * BEST PRACTICE: Consistent error handling throughout component
     */
    handleError(message) {
        this.errorMessage = message;
        console.error('SA ID Holiday Checker Error:', message);
    }

    /**
     * Extracts error message from various error types
     * BEST PRACTICE: Defensive error message extraction
     */
    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.body && Array.isArray(error.body)) {
            return error.body[0].message;
        } else if (error.message) {
            return error.message;
        }
        return 'An unknown error occurred';
    }

    /**
     * Dismisses error notification
     */
    dismissError() {
        this.errorMessage = '';
    }

    /**
     * Dismisses success notification
     */
    dismissSuccess() {
        this.hasResults = false;
    }
}