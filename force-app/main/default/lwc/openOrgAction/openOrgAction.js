import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import openOrgConnectionController from '@salesforce/apex/OrgController.openOrgConnection';

export default class OpenOrgAction extends LightningElement {
    @api recordId;
    @api invoke() {
        console.log("OpenOrgAction action.");

        this.openOrgConnection(this.recordId);
    }

    async openOrgConnection(recordId) {
        try {
            const orgUrl = await openOrgConnectionController({ orgConnectionId: recordId });

            if (orgUrl) {
                window.open(orgUrl, '_blank');                
            } else {
                this.showToast('Error', 'The connection is broken. Please reconnect the org.', 'error');         
                // await refreshApex(this.wiredOrgConnectionsResult); 
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}