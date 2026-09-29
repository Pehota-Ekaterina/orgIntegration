import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import disconnectOrgConnectionController from '@salesforce/apex/OrgController.disconnectOrgConnection';
import hasPermissionApex from '@salesforce/apex/OrgController.checkPermissionAdmin';

export default class DisconnectOrgAction extends LightningElement {
    permissionCheckResult = false;
    errorPermission;

    @api recordId;
    @api invoke() {
        console.log("DisconnectOrgAction action.");

        this.disconnectOrgConnection(this.recordId);
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

    async disconnectOrgConnection(recordId) {
        if (!this.permissionCheckResult) {
            this.showToast('Error', 'You do not have permission to disconnect the org connection.', 'error');
            return;
        }

        try {
            await disconnectOrgConnectionController({ orgConnectionId: recordId });
            
            this.showToast('Success', 'Org Connection disconnected successfully', 'success');
            
            // await refreshApex(this.wiredOrgConnectionsResult);

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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}