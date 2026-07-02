import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrgConnectionsController from '@salesforce/apex/OrgController.getOrgConnections';
import saveOrgConnectionController from '@salesforce/apex/OrgController.saveOrgConnection';
import deleteOrgConnectionController from '@salesforce/apex/OrgController.deleteOrgConnection';
import disconnectOrgConnectionController from '@salesforce/apex/OrgController.disconnectOrgConnection';
import getAuthUrlController from '@salesforce/apex/OrgController.getAuthorizationUrl';
import { refreshApex } from '@salesforce/apex'; 

export default class Integration extends LightningElement {
    @track orgConnectionList = [];
    filteredOrgList = [];
    error;
    wiredOrgConnectionsResult;

    @track searchQuery = '';

    showModal = false;

    orgConnection = {
        orgName: '',
        type: '',
        loginUrl: ''
    };

    @wire(getOrgConnectionsController)
    wiredOrgConnections(result) {
        this.wiredOrgConnectionsResult = result;

        if (result.data) {
            this.orgConnectionList = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.orgConnectionList = [];
        }
    }

    get processedList() {
        if (!this.searchQuery) {
            this.filteredOrgList = this.orgConnectionList;
        } else {
            this.filteredOrgList = this.orgConnectionList.filter(org => {
                const orgName = (org.Org_Name__c || '').toLowerCase();
                return orgName.includes(this.searchQuery);
            });
        }

        return this.filteredOrgList.map(org => {
            const status = org.Status__c;
            let statusClass = '';
            let icon = '';
            
            let statusConnected = false;
            let statusFailed = false;
            let statusNotLinked = false;

            switch (status) {
                case 'Connected': 
                    statusClass = 'card-status status-green';
                    icon = 'utility:check';
                    statusConnected = true;
                    break;
                case 'Failed': 
                    statusClass = 'card-status status-red';
                    icon = 'utility:warning';
                    statusFailed = true;
                    break;
                case 'Not linked':
                default: 
                    statusClass = 'card-status status-gray';
                    icon = 'utility:routing_offline';
                    statusNotLinked = true;
            }

            return {
                ...org,
                statusSpanClass: statusClass,
                statusIcon: icon,
                
                isStatusConnected: statusConnected,
                isStatusFailed: statusFailed,
                isStatusNotLinked: statusNotLinked
            };
        });
    }

    get typeOptions() {
        return [
            { label: '--Select Type--', value: '' },
            { label: 'Production', value: 'Production' },
            { label: 'Sandbox', value: 'Sandbox' },
            { label: 'Scratch', value: 'Scratch' }
        ];
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    connectedCallback() {
        window.addEventListener('focus', () => this.handleTabFocus());
    }
    
    disconnectedCallback() {
        window.removeEventListener('focus', () => this.handleTabFocus());
    }

    async handleTabFocus() {
        await refreshApex(this.wiredOrgConnectionsResult);
    }

    handleSearchChange(event) {
        this.searchQuery = event.target.value.toLowerCase().trim();
    }

    handleOrgNameChange(event) {
        const inputField = this.template.querySelector('[data-id="orgName"]');
        inputField.setCustomValidity('');
        inputField.reportValidity();
       
        this.orgConnection.orgName = event.target.value;
    }

    handleOrgTypeChange(event) {
        const inputFields = [
            this.template.querySelector('[data-id="type"]'),
            this.template.querySelector('[data-id="loginUrl"]')
        ];
        
        inputFields.forEach(input => {
            input.setCustomValidity('');
            input.reportValidity();
        });

        this.orgConnection.type = event.target.value;
    }

    handleOrgLoginUrlChange(event) {
        const inputFields = [
            this.template.querySelector('[data-id="type"]'),
            this.template.querySelector('[data-id="loginUrl"]')
        ];
        
        inputFields.forEach(input => {
            input.setCustomValidity('');
            input.reportValidity();
        });

        this.orgConnection.loginUrl = event.target.value;
    }

    handleModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
        this.cleanOrgConnection();
    }

    cleanOrgConnection() {
        this.orgConnection = {
            orgName: '',
            type: '',
            loginUrl: ''
        };
    }

    async handleAddOrgConnection() {

        this.resetValidation();

        let isValid = true;
        const orgNameInput = this.template.querySelector('[data-id="orgName"]');
        const typeCombobox = this.template.querySelector('[data-id="type"]');
        const loginUrlInput = this.template.querySelector('[data-id="loginUrl"]');        

        if (!this.orgConnection.orgName || this.orgConnection.orgName.trim() === '') {
            orgNameInput.setCustomValidity('Org Name is required');
            orgNameInput.reportValidity();
            this.isValid = false;
        }

        const hasType = this.orgConnection.type && this.orgConnection.type !== '';
        const hasLoginUrl = this.orgConnection.loginUrl && this.orgConnection.loginUrl.trim() !== '';

        if (!hasType && !hasLoginUrl) {
            typeCombobox.setCustomValidity('Select a Type or enter a Login URL');
            typeCombobox.reportValidity();
            loginUrlInput.setCustomValidity('Select a Type or enter a Login URL');
            loginUrlInput.reportValidity();
            isValid = false;    
        } 

        if (!isValid) {
            this.showToast('Error', 'Please fix the errors in the form.', 'error');
            return;
        }

        if(this.orgConnection.type && this.orgConnection.loginUrl.trim() === '') {
            switch (this.orgConnection.type) {
                case 'Production':
                    this.orgConnection.loginUrl = 'https://login.salesforce.com';
                    break;
                case 'Sandbox':
                    this.orgConnection.loginUrl = 'https://test.salesforce.com';
                    break;
                case 'Scratch':
                    this.orgConnection.loginUrl = 'https://test.salesforce.com';
                    break;
                default:
                    this.orgConnection.loginUrl = 'https://login.salesforce.com';
            }
        }

        const orgConnectionData = {
            Org_Name__c: this.orgConnection.orgName,
            Type__c: this.orgConnection.type,
            Login_Url__c: this.orgConnection.loginUrl
        };

        try {
            let orgconnectionId = await saveOrgConnectionController({orgData: orgConnectionData});

            const authUrl = await getAuthUrlController({ orgConnectionId: orgconnectionId });
            window.open(authUrl, '_blankk');

            this.showToast('Success', 'Org Connection saved successfully', 'success');
            this.handleCloseModal();
            await refreshApex(this.wiredOrgConnectionsResult);
        } catch (error) {
            this.showToast('Error', 'Error saving org connection.', 'error');
        }
    }

    resetValidation() {
        const inputFields = [
            this.template.querySelector('[data-id="orgName"]'),
            this.template.querySelector('[data-id="type"]'),
            this.template.querySelector('[data-id="loginUrl"]')
        ];
        
        inputFields.forEach(input => {
            input.setCustomValidity('');
            input.reportValidity();
        });
    }

    handleDeleteOrgConnection(event) {
        const recordId = event.target.dataset.orgId;
        const recordName = event.target.dataset.orgName;

        if (!recordId) return;

        if (confirm(`Are you sure you want to delete "${recordName}"? This action cannot be undone.`)) {
            this.deleteOrgConnection(recordId);
        }
    }

    handleDisconnectOrgConnection(event) {
        const recordId = event.target.dataset.orgId;
        const recordName = event.target.dataset.orgName;

        if (!recordId) return;

        if (confirm(`Are you sure you want to disconnect "${recordName}"? This action cannot be undone.`)) {
            this.disconnectOrgConnection(recordId);
        }
    }

    async deleteOrgConnection(recordId) {
        try {
            await deleteOrgConnectionController({ recordId: recordId });
            
            this.showToast('Success', 'Org Connection deleted successfully', 'success');
            
            await refreshApex(this.wiredOrgConnectionsResult);
            
        } catch (error) {
            let errorMsg = 'Error deleting org connection.';
            
            if (error.body?.message) {
                errorMsg = error.body.message;
            } else if (error.message) {
                errorMsg = error.message;
            } else if (Array.isArray(error) && error[0]?.message) {
                errorMsg = error[0].message;
            }
            
            this.showToast('Error', errorMsg, 'error');
        }
    }

    async disconnectOrgConnection(recordId) {
        try {
            await disconnectOrgConnectionController({ recordId: recordId });
            
            this.showToast('Success', 'Org Connection disconnected successfully', 'success');
            
            await refreshApex(this.wiredOrgConnectionsResult);

        } catch (error) {
            let errorMsg = 'Error disconnecting org connection.';
            
            if (error.body?.message) {
                errorMsg = error.body.message;
            } else if (error.message) {
                errorMsg = error.message;
            } else if (Array.isArray(error) && error[0]?.message) {
                errorMsg = error[0].message;
            }
            
            this.showToast('Error', errorMsg, 'error');
        }
    }
}