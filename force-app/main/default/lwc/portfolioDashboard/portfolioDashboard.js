import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getPortfolioSummary from '@salesforce/apex/StockSearchController.getPortfolioSummary';
import getPortfolioPositions from '@salesforce/apex/StockSearchController.getPortfolioPositions';
import refreshAllPortfolioStocks from '@salesforce/apex/StockSearchController.refreshAllPortfolioStocks';
import refreshSingleStock from '@salesforce/apex/StockSearchController.refreshSingleStock';

export default class PortfolioDashboard extends LightningElement {
    @api recordId;
    @track portfolioSummary = {};
    @track positions = [];
    @track isLoading = false;
    @track isRefreshing = false;
    @track chartData = [];
    @track totalStocksToRefresh = 0;
    
    wiredPositionsResult;
    wiredSummaryResult;
    
    // Platform Event subscription
    channelName = '/event/Portfolio_Refresh_Complete__e';
    subscription = {};

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

    // Subscribe to Platform Events on component load
    connectedCallback() {
        this.handleSubscribe();
        this.registerErrorListener();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    // Subscribe to portfolio refresh complete events
    handleSubscribe() {
        const messageCallback = (response) => {
            const payload = response.data.payload;
            this.handlePortfolioRefreshComplete(payload);
        };
        
        subscribe(this.channelName, -1, messageCallback).then(response => {
            this.subscription = response;
            console.log('Subscribed to portfolio refresh events');
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed from portfolio refresh events');
        });
    }

    registerErrorListener() {
        onError(error => {
            console.error('Platform Event error:', error);
        });
    }

    // Handle portfolio refresh completion from Platform Event
    handlePortfolioRefreshComplete(payload) {
        // Only process events for this portfolio
        if (payload.Portfolio_Id__c !== this.recordId) {
            return;
        }

        const totalStocks = payload.Total_Stocks__c;
        const successCount = payload.Success_Count__c;
        const failureCount = payload.Failure_Count__c;
        const errorMessages = payload.Error_Messages__c;

        console.log(`Portfolio refresh complete: ${successCount} succeeded, ${failureCount} failed`);

        // Refresh the UI data
        Promise.all([
            refreshApex(this.wiredPositionsResult),
            refreshApex(this.wiredSummaryResult)
        ])
        .then(() => {
            this.isRefreshing = false;
            
            // Show appropriate toast message
            if (failureCount === 0) {
                this.showToast(
                    'Success', 
                    `All ${totalStocks} stocks updated successfully!`, 
                    'success'
                );
            } else if (successCount > 0) {
                this.showToast(
                    'Partial Success', 
                    `${successCount} of ${totalStocks} stocks updated. ${failureCount} failed.`, 
                    'warning'
                );
            } else {
                this.showToast(
                    'Error', 
                    `Failed to update all stocks. ${errorMessages || ''}`, 
                    'error'
                );
            }
        })
        .catch(error => {
            console.error('Refresh error:', error);
            this.isRefreshing = false;
            this.showToast('Error', 'Failed to refresh data', 'error');
        });
    }

    // Handle row actions (refresh button)
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'refresh') {
            this.refreshSingleStockPrice(row.id, row.stockId, row.stockSymbol);
        }
    }

    // Refresh single stock price
    refreshSingleStockPrice(positionId, stockId, stockSymbol) {
        this.isRefreshing = true;
        this.currentStockRefreshing = stockSymbol;
        this.refreshProgress = 0;
        this.totalStocksToRefresh = 1;

        refreshSingleStock({ stockId: stockId, portfolioId: this.recordId })
            .then(() => {
                this.showToast(
                    'Refresh Started', 
                    `${stockSymbol} is updating. This may take up to 30 seconds...`, 
                    'info'
                );
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to start refresh', 'error');
                this.isRefreshing = false;
            });
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

    // Columns for positions datatable (NO REFRESH ICON)
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

    // Refresh all stocks in portfolio
    handleRefreshAll() {
        if (this.isRefreshing) return;

        // Get unique stock count
        const uniqueStocks = new Set();
        this.positions.forEach(pos => uniqueStocks.add(pos.stockId));
        
        this.totalStocksToRefresh = uniqueStocks.size;
        this.isRefreshing = true;

        refreshAllPortfolioStocks({ portfolioId: this.recordId })
            .then(() => {
                this.showToast(
                    'Refresh Started', 
                    `Refreshing ${this.totalStocksToRefresh} stocks. This will take approximately ${Math.ceil(this.totalStocksToRefresh * 0.8)} minutes...`, 
                    'info'
                );
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to start refresh', 'error');
                this.isRefreshing = false;
            });
    }

    // Open add stock modal
    handleAddStock() {
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