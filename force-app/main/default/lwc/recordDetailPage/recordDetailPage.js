import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrgConnectionById from '@salesforce/apex/OrgController.getOrgConnectionById';
import deleteOrgConnectionController from '@salesforce/apex/OrgController.deleteOrgConnection';
import disconnectOrgConnectionController from '@salesforce/apex/OrgController.disconnectOrgConnection';
import openOrgConnectionController from '@salesforce/apex/OrgController.openOrgConnection';
import getAuthUrlController from '@salesforce/apex/OrgController.getAuthorizationUrl';
import { NavigationMixin } from 'lightning/navigation';

export default class RecordDetailPage extends NavigationMixin(LightningElement) {
    orgConnection;
    error;
    isLoading = true;
    toastShown = false;
    wiredOrgConnectionResult;

    @api recordId;

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (!this.recordId && pageRef?.attributes?.recordId) {
            this.recordId = pageRef.attributes.recordId;
        }

        if (pageRef?.state && !this.toastShown) {
            
            const toastType = pageRef.state.c__toast;
            const message = pageRef.state.c__message;

            if (toastType && message) {
                this.toastShown = true;

                const variant = toastType === 'success' ? 'success' : 'error';
                const title = toastType === 'success' ? 'Success' : 'Error';

                const decodedMessage = decodeURIComponent(message.replace(/\+/g, ' '));
                this.showToast(title, decodedMessage, variant);
                
                setTimeout(() => {
                    this.cleanUrlParameters();
                }, 500);
            }
        }
    }

    @wire(getOrgConnectionById, { orgConnectionId: '$recordId' })
    wiredOrgConnection(result) {
        this.wiredOrgConnectionResult = result;

        if (result.data) {
            const org = result.data;
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

            this.orgConnection = {
                ...org,
                statusSpanClass: statusClass,
                statusIcon: icon,
                
                isStatusConnected: statusConnected,
                isStatusFailed: statusFailed,
                isStatusNotLinked: statusNotLinked
            };
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error;
            this.orgConnection = undefined;
            this.isLoading = false;
        }
    }

    connectedCallback() {
        window.addEventListener('focus', () => this.handleTabFocus());
    }
    
    disconnectedCallback() {
        window.removeEventListener('focus', () => this.handleTabFocus());
    }

    async handleTabFocus() {
        await refreshApex(this.wiredOrgConnectionResult);
    }

    handleDisconnectOrgConnection() {
        const recordId = this.orgConnection.Id;
        const orgName = this.orgConnection.Org_Name__c;

        if (!recordId) return;

        if (confirm(`Are you sure you want to disconnect "${orgName}"? This action cannot be undone.`)) {
            this.disconnectOrgConnection(recordId);
        }
    }

    handleDeleteOrgConnection() {
        const recordId = this.orgConnection.Id;
        const orgName = this.orgConnection.Org_Name__c;

        if (!recordId) return;

        if (confirm(`Are you sure you want to delete "${orgName}"? This action cannot be undone.`)) {
            this.deleteOrgConnection(recordId);
        }
    }

    handleOpenOrgConnection() {
        const recordId = this.orgConnection.Id;

        if (!recordId) return;

        this.openOrgConnection(recordId);
    }

    handleAuthorizeOrgConnection() {
        const recordId = this.orgConnection.Id;

        if (!recordId) return;

        this.authorizeOrgConnection(recordId);
    }

    async disconnectOrgConnection(recordId) {
        try {
            await disconnectOrgConnectionController({ orgConnectionId: recordId });
            
            this.showToast('Success', 'Org Connection disconnected successfully', 'success');
            
            await refreshApex(this.wiredOrgConnectionResult);

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

    async deleteOrgConnection(recordId) {
        try {
            await deleteOrgConnectionController({ orgConnectionId: recordId });
            
            this.showToast('Success', 'Org Connection deleted successfully', 'success');

            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'home'
                },
            });
            
            
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

    async openOrgConnection(recordId) {
        try {
            const orgUrl = await openOrgConnectionController({ orgConnectionId: recordId });

            if (orgUrl) {
                window.open(orgUrl, '_blank');                
            } else {
                this.showToast('Error', 'The connection is broken. Please reconnect the org.', 'error');
                await refreshApex(this.wiredOrgConnectionResult);                
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

    async authorizeOrgConnection(recordId) {
        try {
            const authUrl = await getAuthUrlController({ orgConnectionId: recordId });
            window.open(authUrl, '_blank');

            this.showToast('Success', 'Org Connection authorized successfully', 'success');
            await refreshApex(this.wiredOrgConnectionResult);
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    cleanUrlParameters() {
        const url = new URL(window.location);
        url.searchParams.delete('c__toast');
        url.searchParams.delete('c__message');
        window.history.replaceState({}, document.title, url.pathname + url.search);
    }
}


