import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class AccessRequestModal extends LightningModal {
    @api orgId;
    showForm = false;

    get showIntro() { 
        return !this.showForm; 
    }

    get headerLabel() { 
        return this.showForm ? 'Access Request' : 'Access Required'; 
    }

    get flowInputs() {
        return [{ name: 'orgConnectionId', type: 'String', value: this.orgId }];
    }

    handleCreate() { 
        this.showForm = true; 
    }

    handleCancel() { 
        this.close('cancel'); 
    }

    handleStatusChange(event) {
        const { status, outputVariables } = event.detail;

        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            const requestId = outputVariables?.find(v => v.name === 'requestId')?.value;
            this.close(requestId ? 'submitted' : 'cancel');
        }
    }
}