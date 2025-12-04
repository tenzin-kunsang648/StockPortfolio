import { LightningElement, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';

export default class PortfolioContainer extends LightningElement {
    @api recordId; // Portfolio ID from record page context
    showStockSearch = false;

    /**
     * Handle Add Stock button click from Portfolio Dashboard
     * Opens the stock search modal
     */
    handleAddStock() {
        this.showStockSearch = true;
    }

    /**
     * Handle successful stock addition
     * Closes modal and refreshes the dashboard
     */
    handleStockAdded() {
        // Refresh the portfolio dashboard to show new position
        this.refreshDashboard();

        this.showStockSearch = false;
    }

    /**
     * Handle modal close (X button or cancel)
     */
    handleCloseModal() {
        this.showStockSearch = false;
    }

    /**
     * Refresh the portfolio dashboard component
     */
    refreshDashboard() {
        // Get reference to portfolio dashboard component
        const dashboard = this.template.querySelector('c-portfolio-dashboard');
        
        if (dashboard) {
            // // Dispatching to manually refresh
            // dashboard.dispatchEvent(new CustomEvent('handleRefreshAll'));

            // exposed to parent via api, calling method directly
            dashboard.handleRefreshAll();
        }
    }

    /**
     * Handle ESC key to close modal
     */
    connectedCallback() {
        this.handleKeyPress = this.handleKeyPress.bind(this);
        window.addEventListener('keydown', this.handleKeyPress);
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this.handleKeyPress);
    }

    handleKeyPress(event) {
        if (event.key === 'Escape' && this.showStockSearch) {
            this.handleCloseModal();
        }
    }
}