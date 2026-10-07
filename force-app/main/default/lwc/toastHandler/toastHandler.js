import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ToastHandler extends LightningElement {

    @wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef && pageRef.state) {
            const showToast = pageRef.state.c__showToast;
            const message = pageRef.state.c__message;
            const toastType = pageRef.state.c__toast;
            
            // message = message ? decodeURIComponent(message.replace(/\+/g, ' ')) : '';

            if (showToast === 'true' && toastType) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        message: message ? decodeURIComponent(message.replace(/\+/g, ' ')) : '',
                        variant: toastType
                    })
                );
                
                const url = new URL(window.location.href);
                url.searchParams.delete('c__showToast');
                url.searchParams.delete('c__message');
                url.searchParams.delete('c__toast');
                window.history.replaceState({}, '', url.toString());
            }
        }
    }
}
