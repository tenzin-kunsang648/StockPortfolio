import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchStocks from '@salesforce/apex/StockSearchController.searchStocks';
import addStockToPortfolio from '@salesforce/apex/StockSearchController.addStockToPortfolio';

export default class StockSearch extends LightningElement {
    @api portfolioId;
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedStock = null;
    @track shares = 0;
    @track pricePerShare = 0;
    @track isLoading = false;
    @track showAddModal = false;

    // handling search input
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            this.debounceSearch();
        } else {
            this.searchResults = [];
        }
    }

    // debounce search to avoid excessive API calls
    debounceSearch() {
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.performSearch();
        }, 500);
    }

    // perform the search
    performSearch() {
        this.isLoading = true;
        searchStocks({ searchTerm: this.searchTerm })
            .then(result => {
                this.searchResults = result.map(stock => ({
                    Id: stock.Id,
                    symbol: stock.Name,
                    name: stock.Company_Name__c,
                    price: stock.Current_Price__c,
                    change: stock.Day_Change__c,
                    changeAmount: stock.Day_Change_Amount__c,
                    isPositive: stock.Day_Change__c >= 0
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.isLoading = false;
            });
    }

    // handle stock selection
    handleStockSelect(event) {
        const stockId = event.currentTarget.dataset.id;
        this.selectedStock = this.searchResults.find(s => s.Id === stockId);
        this.pricePerShare = this.selectedStock.price;
        this.showAddModal = true;
    }

    // handle shares input
    handleSharesChange(event) {
        this.shares = parseFloat(event.target.value) || 0;
    }

    // handle price input
    handlePriceChange(event) {
        this.pricePerShare = parseFloat(event.target.value) || 0;
    }

    // calculate total cost
    get totalCost() {
        return (this.shares * this.pricePerShare).toFixed(2);
    }

    // add stock to portfolio
    handleAddStock() {
        if (!this.validateInputs()) {
            return;
        }

        this.isLoading = true;
        addStockToPortfolio({
            portfolioId: this.portfolioId,
            stockId: this.selectedStock.Id,
            shares: this.shares,
            pricePerShare: this.pricePerShare
        })
            .then(() => {
                this.showToast('Success', 'Stock added to portfolio', 'success');
                this.closeModal();
                this.dispatchEvent(new CustomEvent('stockadded'));
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // validate inputs
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

    // close modal
    closeModal() {
        this.showAddModal = false;
        this.selectedStock = null;
        this.shares = 0;
        this.pricePerShare = 0;
    }

    // show toast notification
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // computed properties
    get hasResults() {
        return this.searchResults.length > 0;
    }

    get noResults() {
        return !this.isLoading && this.searchTerm.length >= 2 && this.searchResults.length === 0;
    }
}