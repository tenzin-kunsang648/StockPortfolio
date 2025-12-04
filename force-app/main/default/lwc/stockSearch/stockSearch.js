import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchStocks from '@salesforce/apex/StockSearchController.searchStocks';
import addStockToPortfolio from '@salesforce/apex/StockSearchController.addStockToPortfolio';

export default class StockSearch extends LightningElement {
    @api portfolioId;
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedStockId = null;
    @track shares = 0;
    @track pricePerShare = 0;
    @track isLoading = false;

    // Handle search input
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            this.debounceSearch();
        } else {
            this.searchResults = [];
        }
    }

    // Debounce search to avoid excessive API calls
    debounceSearch() {
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.performSearch();
        }, 500);
    }

    // Perform the search
    performSearch() {
        this.isLoading = true;
        searchStocks({ searchTerm: this.searchTerm })
            .then(result => {
                this.searchResults = result.map(stock => ({
                    Id: stock.Id,
                    symbol: stock.Name,
                    name: stock.Company_Name__c,
                    price: stock.Current_Price__c,
                    // change: (stock.Day_Change__c != null ? stock.Day_Change__c : 0).toFixed(2),
                    change: stock.Day_Change__c,
                    changeAmount: stock.Day_Change_Amount__c,
                    isPositive: stock.Day_Change__c >= 0,
                    isSelected: false
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.isLoading = false;
            });
    }

    // Handle stock selection (expand form)
    handleStockSelect(event) {
        const stockId = event.currentTarget.dataset.id;
        
        // Update search results to show form for selected stock
        this.searchResults = this.searchResults.map(stock => ({
            ...stock,
            isSelected: stock.Id === stockId
        }));

        // Set initial values
        const selectedStock = this.searchResults.find(s => s.Id === stockId);
        this.selectedStockId = stockId;
        this.pricePerShare = selectedStock.price;
        this.shares = 1; // Default to 1 share
    }

    // Handle shares input
    handleSharesChange(event) {
        this.shares = parseFloat(event.target.value) || 0;
    }

    // Handle price input
    handlePriceChange(event) {
        this.pricePerShare = parseFloat(event.target.value) || 0;
    }

    // Calculate total cost
    get totalCost() {
        return (this.shares * this.pricePerShare).toFixed(2);
    }

    // Handle cancel
    handleCancel() {
        // Collapse all forms
        this.searchResults = this.searchResults.map(stock => ({
            ...stock,
            isSelected: false
        }));
        this.selectedStockId = null;
        this.shares = 0;
        this.pricePerShare = 0;
    }

    // Add stock to portfolio
    handleAddStock() {
        if (!this.validateInputs()) {
            return;
        }

        this.isLoading = true;
        addStockToPortfolio({
            portfolioId: this.portfolioId,
            stockId: this.selectedStockId,
            shares: this.shares,
            pricePerShare: this.pricePerShare
        })
            .then(() => {
                this.showToast('Success', 'Stock added to portfolio', 'success');
                
                // Fire event to parent to close modal and refresh
                this.dispatchEvent(new CustomEvent('stockadded'));
                
                // Reset form
                this.handleCancel();
                this.searchTerm = '';
                this.searchResults = [];
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Validate inputs
    validateInputs() {
        if (this.shares <= 0) {
            this.showToast('Error', 'Shares must be greater than 0', 'error');
            return false;
        }
        if (this.pricePerShare <= 0) {
            this.showToast('Error', 'Price must be greater than 0', 'error');
            return false;
        }
        return true;
    }

    // Show toast notification
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // Computed properties
    get hasResults() {
        return this.searchResults.length > 0;
    }

    get noResults() {
        return !this.isLoading && this.searchTerm.length >= 2 && this.searchResults.length === 0;
    }
}