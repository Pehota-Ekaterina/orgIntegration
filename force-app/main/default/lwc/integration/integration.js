import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrgConnectionsController from '@salesforce/apex/OrgController.getOrgConnections';
import saveOrgConnectionController from '@salesforce/apex/OrgController.saveOrgConnection';
import deleteOrgConnectionController from '@salesforce/apex/OrgController.deleteOrgConnection';
import disconnectOrgConnectionController from '@salesforce/apex/OrgController.disconnectOrgConnection';
import openOrgConnectionController from '@salesforce/apex/OrgController.openOrgConnection';
import getAuthUrlController from '@salesforce/apex/OrgController.getAuthorizationUrl';
import connectionStatusCheckController from '@salesforce/apex/OrgController.connectionStatusCheck';
import { refreshApex } from '@salesforce/apex'; 
import { NavigationMixin } from 'lightning/navigation';

export default class Integration extends NavigationMixin(LightningElement) {
    @track orgConnectionList = [];
    filteredOrgList = [];
    error;
    wiredOrgConnectionsResult;

    isLoading = true;
    hasVerifiedConnections = false;

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

            if (!this.hasVerifiedConnections) {
                this.hasVerifiedConnections = true;
                this.connectionStatusCheck();
            }
        } else if (result.error) {
            this.error = result.error;
            this.orgConnectionList = [];
            this.isLoading = false;
            this.showToast('Error', 'Error loading data ', 'error');
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

    _handleTabFocus = async () => {
        if (this.wiredOrgConnectionsResult) {
            await refreshApex(this.wiredOrgConnectionsResult);
        }
    };

    connectedCallback() {
        window.addEventListener('focus', this._handleTabFocus);
    }
    
    disconnectedCallback() {
        window.removeEventListener('focus', this._handleTabFocus);
    }

    async connectionStatusCheck() {
       await connectionStatusCheckController();

       if (this.wiredOrgConnectionsResult) {
            await refreshApex(this.wiredOrgConnectionsResult);
        }

        this.isLoading = false;
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
        this.clearValidation();

        this.orgConnection.type = event.target.value;
    }

    handleOrgLoginUrlChange(event) {
        this.clearValidation();
        
        this.orgConnection.loginUrl = event.target.value;
    }

    clearValidation() {
        const inputFields = [
            this.template.querySelector('[data-id="type"]'),
            this.template.querySelector('[data-id="loginUrl"]')
        ];
        
        inputFields.forEach(input => {
            if(input) {
                input.setCustomValidity('');
                input.reportValidity();
            }
        });
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
            // isValid = false;
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
            let orgConnectionId = await saveOrgConnectionController({orgData: orgConnectionData});
            this.handleCloseModal();            

            this.authorizeOrgConnection(orgConnectionId);
        } catch (error) {
            this.showToast('Error', 'Error adding org connection.', 'error');
        }
    }

    handleAuthorizeOrgConnection(event) {
        const recordId = event.target.dataset.orgId;

        if (!recordId) return;

        this.authorizeOrgConnection(recordId);
    }

    async authorizeOrgConnection(recordId) {
        try {
            const authUrl = await getAuthUrlController({ orgConnectionId: recordId });
            window.open(authUrl, '_blank');
        } catch (error) {
            let errorMsg = 'Error authorizing org connection.';
            
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
            await deleteOrgConnectionController({ orgConnectionId: recordId });
            
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
            await disconnectOrgConnectionController({ orgConnectionId: recordId });
            
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

    handleOpenOrgConnection(event) {
        const recordId = event.target.dataset.orgId;

        if (!recordId) return;

        this.openOrgConnection(recordId);
    }

    async openOrgConnection(recordId) {
        try {
            const orgUrl = await openOrgConnectionController({ orgConnectionId: recordId });

            if (orgUrl) {
                window.open(orgUrl, '_blank');                
            } else {
                this.showToast('Error', 'The connection is broken. Please reconnect the org.', 'error');
                await refreshApex(this.wiredOrgConnectionsResult);                
            }            
        } catch (error) {
            let errorMsg = 'Error opening org connection.';
            
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

    handleOpenDetailPage(event) {
        const recordId = event.target.dataset.orgId;

        if(!recordId) return;

        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: recordId,
                objectApiName: "Org_Connection__c",
                actionName: "view",
            },
        });      
    }
}