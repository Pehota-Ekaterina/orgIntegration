import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex'; 
import { NavigationMixin } from 'lightning/navigation';

import getOrgConnectionsController from '@salesforce/apex/OrgController.getOrgConnections';
import saveOrgConnectionController from '@salesforce/apex/OrgController.saveOrgConnection';
import deleteOrgConnectionController from '@salesforce/apex/OrgController.deleteOrgConnection';
import disconnectOrgConnectionController from '@salesforce/apex/OrgController.disconnectOrgConnection';
import openOrgConnectionController from '@salesforce/apex/OrgController.openOrgConnection';
import getAuthUrlController from '@salesforce/apex/OrgController.getAuthorizationUrl';
import connectionStatusCheckController from '@salesforce/apex/OrgController.connectionStatusCheck';

export default class OrgConnectionPage extends NavigationMixin(LightningElement) {
    orgConnectionList = [];
    wiredOrgConnectionsResult;
    isLoading = true;
    hasVerifiedConnections = false;
    searchQuery = '';
    showModal = false;

    @wire(getOrgConnectionsController)
    wiredOrgConnections(result) {
        this.wiredOrgConnectionsResult = result;
        if (result.data) {
            this.orgConnectionList = result.data;
            this.isLoading = false;
            if (!this.hasVerifiedConnections) {
                this.hasVerifiedConnections = true;
                this.connectionStatusCheck();
            }
        } else if (result.error) {
            this.orgConnectionList = [];
            this.isLoading = false;
            this.showToast('Error', 'Error loading data', 'error');
        }
    }

    // Чистый геттер для фильтрации (без мутации this)
    get filteredOrgList() {
        if (!this.searchQuery) return this.orgConnectionList;
        const query = this.searchQuery.toLowerCase();
        return this.orgConnectionList.filter(org => 
            (org.Org_Name__c || '').toLowerCase().includes(query)
        );
    }

    // --- Управление модальным окном ---
    handleOpenModal() { this.showModal = true; }
    handleCloseModal() { this.showModal = false; }

    // --- Обработка событий от дочерних компонентов ---
    
    async handleSaveOrgConnection(event) {
        try {
            const orgId = await saveOrgConnectionController({ 
                orgName: event.detail.Org_Name__c,
                type: event.detail.Type__c,
                loginUrl: event.detail.Login_Url__c
            });
            this.handleCloseModal();
            this.showToast('Success', 'Org Connection saved successfully', 'success');
            this.authorizeOrgConnection(orgId); // Авто-авторизация после создания
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error adding org connection.', 'error');
        }
    }

    async handleDelete(event) {
        const { id, name } = event.detail;
        if (!confirm(`Are you sure you want to delete "${name}"?`)) return;
        try {
            await deleteOrgConnectionController({ orgConnectionId: id });
            this.showToast('Success', 'Org Connection deleted successfully', 'success');
            await refreshApex(this.wiredOrgConnectionsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error deleting.', 'error');
        }
    }

    async handleDisconnect(event) {
        const { id, name } = event.detail;
        if (!confirm(`Are you sure you want to disconnect "${name}"?`)) return;
        try {
            await disconnectOrgConnectionController({ orgConnectionId: id });
            this.showToast('Success', 'Org Connection disconnected successfully', 'success');
            await refreshApex(this.wiredOrgConnectionsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error disconnecting.', 'error');
        }
    }

    async handleOpen(event) {
        try {
            const orgUrl = await openOrgConnectionController({ orgConnectionId: event.detail.id });
            if (orgUrl) {
                window.open(orgUrl, '_blank');
            } else {
                this.showToast('Error', 'The connection is broken. Please reconnect.', 'error');
                await refreshApex(this.wiredOrgConnectionsResult);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error opening org.', 'error');
        }
    }

    async handleAuthorize(event) {
        try {
            const authUrl = await getAuthUrlController({ orgConnectionId: event.detail.id });
            window.open(authUrl, '_blank');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error authorizing.', 'error');
        }
    }

    handleNavigate(event) {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: { recordId: event.detail.id, objectApiName: "Org_Connection__c", actionName: "view" }
        });
    }

    // --- Утилиты ---
    handleSearchChange(event) { this.searchQuery = event.target.value.toLowerCase().trim(); }
    
    handleShowToast(event) {
        this.showToast(event.detail.title, event.detail.message, event.detail.variant);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async connectionStatusCheck() {
        try {
            await connectionStatusCheckController();
            await refreshApex(this.wiredOrgConnectionsResult);
        } catch (error) {
            console.error('Status check failed', error);
        }
    }
}