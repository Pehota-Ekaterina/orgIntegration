import { LightningElement, api } from 'lwc';

export default class OrgConnectionModal extends LightningElement {
    @api isOpen = false;
    
    orgName = '';
    type = '';
    loginUrl = '';

    get typeOptions() {
        return [
            { label: '--Select Type--', value: '' },
            { label: 'Production', value: 'Production' },
            { label: 'Sandbox', value: 'Sandbox' },
            { label: 'Scratch', value: 'Scratch' }
        ];
    }

    handleClose() {
        this.resetForm();
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this[field] = event.target.value;
        // Сброс валидации при вводе
        event.target.setCustomValidity('');
        event.target.reportValidity();
    }

    handleSave() {
        const orgNameInput = this.template.querySelector('[data-id="orgName"]');
        const typeInput = this.template.querySelector('[data-id="type"]');
        const loginUrlInput = this.template.querySelector('[data-id="loginUrl"]');
        
        let isValid = true;

        if (!this.orgName || this.orgName.trim() === '') {
            orgNameInput.setCustomValidity('Org Name is required');
            orgNameInput.reportValidity();
            isValid = false;
        }

        if (!this.type && (!this.loginUrl || this.loginUrl.trim() === '')) {
            const msg = 'Select a Type or enter a Login URL';
            typeInput.setCustomValidity(msg);
            typeInput.reportValidity();
            loginUrlInput.setCustomValidity(msg);
            loginUrlInput.reportValidity();
            isValid = false;
        }

        if (!isValid) {
            this.dispatchEvent(new CustomEvent('showtoast', { detail: { title: 'Error', message: 'Please fix the errors in the form.', variant: 'error' } }));
            return;
        }

        // Автозаполнение URL
        let finalLoginUrl = this.loginUrl;
        if (this.type && !finalLoginUrl) {
            finalLoginUrl = (this.type === 'Sandbox' || this.type === 'Scratch') ? 'https://test.salesforce.com' : 'https://login.salesforce.com';
        }

        this.dispatchEvent(new CustomEvent('save', { 
            detail: { 
                Org_Name__c: this.orgName.trim(), 
                Type__c: this.type, 
                Login_Url__c: finalLoginUrl 
            } 
        }));
    }

    resetForm() {
        this.orgName = '';
        this.type = '';
        this.loginUrl = '';
        this.template.querySelectorAll('lightning-input, lightning-combobox').forEach(input => {
            input.setCustomValidity('');
            input.reportValidity();
        });
    }
}