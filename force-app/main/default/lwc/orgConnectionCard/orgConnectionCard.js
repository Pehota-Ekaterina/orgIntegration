import { LightningElement, api } from 'lwc';

export default class OrgConnectionCard extends LightningElement {
    // Получаем данные записи от родительского компонента
    @api record;

    // === Геттеры для логики статусов (с защитой от undefined через optional chaining '?') ===
    
    get isStatusConnected() {
        return this.record?.Status__c === 'Connected';
    }

    get isStatusFailed() {
        return this.record?.Status__c === 'Failed';
    }

    get isStatusNotLinked() {
        return !this.record?.Status__c || this.record?.Status__c === 'Not linked';
    }

    // === Геттеры для CSS классов и иконок (строго соответствуют вашему CSS файлу) ===

    get statusSpanClass() {
        if (this.isStatusConnected) return 'card-status status-green';
        if (this.isStatusFailed) return 'card-status status-red';
        return 'card-status status-gray';
    }

    get statusIcon() {
        if (this.isStatusConnected) return 'utility:check';
        if (this.isStatusFailed) return 'utility:warning';
        return 'utility:routing_offline';
    }

    // === Вспомогательный метод для отправки событий наверх ===
    dispatchAction(eventName, detail = {}) {
        this.dispatchEvent(new CustomEvent(eventName, { detail }));
    }

    // === Обработчики кликов ===
    // ВАЖНО: Используем event.currentTarget, чтобы получить data-атрибуты 
    // даже если пользователь кликнул на иконку внутри кнопки, а не на саму кнопку.

    handleDelete(event) {
        this.dispatchAction('orgdelete', {
            id: event.currentTarget.dataset.id,
            name: event.currentTarget.dataset.name
        });
    }

    handleDisconnect(event) {
        this.dispatchAction('orgdisconnect', {
            id: event.currentTarget.dataset.id,
            name: event.currentTarget.dataset.name
        });
    }

    handleOpen(event) {
        this.dispatchAction('orgopen', {
            id: event.currentTarget.dataset.id
        });
    }

    handleAuthorize(event) {
        this.dispatchAction('orgauthorize', {
            id: event.currentTarget.dataset.id
        });
    }

    // === Обработчики навигации по клику на заголовок карточки ===

    handleNavigate() {
        this.dispatchAction('orgnavigate', {
            id: this.record.Id
        });
    }

    // Поддержка навигации с клавиатуры (Enter или Пробел) для доступности (a11y)
    handleNavigateKey(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault(); // Предотвращаем прокрутку страницы при нажатии пробела
            this.handleNavigate();
        }
    }
}