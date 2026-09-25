import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAuthUrlController from '@salesforce/apex/OrgController.getAuthorizationUrl';
import hasPermissionApex from '@salesforce/apex/OrgController.checkPermissionAdmin';

export default class AuthorizeAction extends LightningElement {
    permissionCheckResult = false;
    errorPermission;
    
    @api recordId;
    @api invoke() {
        console.log("AuthorizeAction action.");

        this.authorizeOrgConnection(this.recordId);
    }

    @wire(hasPermissionApex)
    hasPermission(result) {
        if(result.data) {
            this.permissionCheckResult = result.data;
            this.errorPermission = undefined;
        } else if (result.error) {
            this.errorPermission = result.error;
            this.permissionCheckResult = false;
        }
    }

    async authorizeOrgConnection(recordId) {
        if (!this.permissionCheckResult) {
            this.showToast('Error', 'You do not have permission to authorize the org connection.', 'error');
            return;
        }

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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}