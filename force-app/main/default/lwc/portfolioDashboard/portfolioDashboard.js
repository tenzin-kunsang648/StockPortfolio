import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPortfolioSummary from '@salesforce/apex/StockSearchController.getPortfolioSummary';
import getPortfolioPositions from '@salesforce/apex/StockSearchController.getPortfolioPositions';
import refreshStockPrice from '@salesforce/apex/StockSearchController.refreshStockPrice';

export default class PortfolioDashboard extends LightningElement {
    @api recordId;
    @track portfolioSummary = {};
    @track positions = [];
    @track isLoading = false;
    @track chartData = [];
    
    wiredPositionsResult;
    wiredSummaryResult;

    // Wire portfolio summary
    @wire(getPortfolioSummary, { portfolioId: '$recordId' })
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.portfolioSummary = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.showToast('Error', 'Failed to load portfolio summary', 'error');
        }
    }

    // Wire portfolio positions
    @wire(getPortfolioPositions, { portfolioId: '$recordId' })
    wiredPositions(result) {
        this.wiredPositionsResult = result;
        if (result.data) {
            this.positions = result.data;
            this.prepareChartData();
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.showToast('Error', 'Failed to load positions', 'error');
        }
    }

    // Prepare data for pie chart
    prepareChartData() {
        this.chartData = this.positions.map(pos => ({
            label: pos.stockSymbol,
            value: pos.currentValue || 0,
            color: this.getRandomColor()
        }));
    }

    // Generate random colors for chart
    getRandomColor() {
        const colors = [
            '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
            '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
        ];
        return colors[Math.floor(Math.random() * colors.length)];
    }

    // Columns for positions datatable
    columns = [
        { 
            label: 'Stock', 
            fieldName: 'stockSymbol', 
            type: 'text',
            cellAttributes: { class: 'slds-text-title_bold' }
        },
        { 
            label: 'Company', 
            fieldName: 'companyName', 
            type: 'text' 
        },
        { 
            label: 'Shares', 
            fieldName: 'shares', 
            type: 'number',
            typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 4 }
        },
        { 
            label: 'Avg Cost', 
            fieldName: 'averageCost', 
            type: 'currency',
            typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 2 }
        },
        { 
            label: 'Current Price', 
            fieldName: 'currentPrice', 
            type: 'currency',
            typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 2 }
        },
        { 
            label: 'Total Value', 
            fieldName: 'currentValue', 
            type: 'currency',
            typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 2 }
        },
        { 
            label: 'Gain/Loss', 
            fieldName: 'gainLoss', 
            type: 'currency',
            typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 2 },
            cellAttributes: { 
                class: { fieldName: 'gainLossClass' }
            }
        },
        { 
            label: 'Gain/Loss %', 
            fieldName: 'gainLossPercent', 
            type: 'percent',
            typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 },
            cellAttributes: { 
                class: { fieldName: 'gainLossClass' }
            }
        },
        {
            type: 'button-icon',
            typeAttributes: {
                iconName: 'utility:refresh',
                name: 'refresh',
                title: 'Refresh Price',
                variant: 'bare',
                alternativeText: 'Refresh'
            }
        }
    ];

    // Computed properties
     get portfolioId() {
        return this.recordId;
    }
    
    get hasPositions() {
        return this.positions && this.positions.length > 0;
    }

    get portfolioValueClass() {
        return this.portfolioSummary.totalValue >= 0 ? 
            'slds-text-heading_large slds-text-color_success' : 
            'slds-text-heading_large slds-text-color_error';
    }

    get gainLossClass() {
        if (!this.portfolioSummary.gainLoss) return '';
        return this.portfolioSummary.gainLoss >= 0 ? 
            'slds-text-color_success' : 
            'slds-text-color_error';
    }

    get gainLossIcon() {
        if (!this.portfolioSummary.gainLoss) return 'utility:dash';
        return this.portfolioSummary.gainLoss >= 0 ? 
            'utility:up' : 
            'utility:down';
    }

    get formattedTotalValue() {
        return this.formatCurrency(this.portfolioSummary.totalValue);
    }

    get formattedGainLoss() {
        const value = this.portfolioSummary.gainLoss || 0;
        return (value >= 0 ? '+' : '') + this.formatCurrency(value);
    }

    get formattedGainLossPercent() {
        const value = this.portfolioSummary.gainLossPercent || 0;
        return (value >= 0 ? '+' : '') + value.toFixed(2) + '%';
    }

    // Handle row actions (refresh button)
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'refresh') {
            this.refreshSingleStock(row.id);
        }
    }

    // Refresh single stock price
    refreshSingleStock(positionId) {
        this.isLoading = true;
        const position = this.positions.find(p => p.id === positionId);
        
        if (!position) return;

        refreshStockPrice({ stockId: position.stockId })
            .then(() => {
                this.showToast('Success', `Refreshed price for ${position.stockSymbol}`, 'success');
                return refreshApex(this.wiredPositionsResult);
            })
            .then(() => {
                return refreshApex(this.wiredSummaryResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // exposing this to parent component - refreshing all prices
    @api
    handleRefreshAll() {
        this.isLoading = true;
        
        // Refresh all positions
        Promise.all([
            refreshApex(this.wiredPositionsResult),
            refreshApex(this.wiredSummaryResult)
        ])
        .then(() => {
            this.showToast('Success', 'Portfolio refreshed', 'success');
        })
        .catch(error => {
            this.showToast('Error', 'Failed to refresh portfolio', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    // Open add stock modal
    handleAddStock() {
        // Fire event to parent to open stock search modal
        this.dispatchEvent(new CustomEvent('addstock'));
    }

    // Format currency
    formatCurrency(value) {
        if (!value && value !== 0) return '$0.00';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 2
        }).format(value);
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
}