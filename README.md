# Stock Portfolio Tracker

Real-time stock portfolio management platform built on Salesforce

## Screenshots

![Portfolio Dashboard](images/portfolio-dashboard-full.png)

<table>
  <tr>
    <td width="50%"><img src="images/stock-search-results.png" alt="Stock Search" /></td>
    <td width="50%"><img src="images/add-stock-form.png" alt="Add Stock Form" /></td>
  </tr>
</table>

📖 [User Guide](docs/USER_GUIDE.md) | 🔧 [Technical Guide](docs/TECHNICAL_GUIDE.md)

---

## Features

**Completed:**
- Real-time stock data via Alpha Vantage API
- Portfolio dashboard with live updates
- Stock search and add functionality
- Automated price updates via scheduled batch jobs

**In Progress:**
- 🔔 Real-time price alerts using Platform Events

**Planned:**
- Tableau CRM analytics
- Dual portal (investor + advisor)

---

## Tech Stack

- Salesforce Lightning Platform
- Apex (REST API, Batch Processing, Triggers)
- Lightning Web Components
- Alpha Vantage API
- Platform Events (for real-time notifications)

---

## Architecture

![Data Model](images/data_model.png)

**Core Components:**
- **Portfolio Management** - Track multiple portfolios with positions and transactions
- **Real-time Pricing** - Automated batch updates from Alpha Vantage API
- **Price Alerts** *(Coming Soon)* - Platform Event-driven notifications when stocks hit target prices

---

## Quick Start

1. Clone repo
2. Deploy: `sfdx force:source:deploy -p force-app/main/default`
3. Setup → Custom Metadata Types → Add API key
4. Add "Portfolio Container" to Portfolio record page

[Full setup instructions →](docs/TECHNICAL_GUIDE.md)

---

## Roadmap

### Phase 1: Core Portfolio Tracking ✅
- [x] Data model with custom objects
- [x] Alpha Vantage API integration
- [x] Portfolio dashboard LWC
- [x] Stock search and add functionality
- [x] Automated price refresh batch job

### Phase 2: Real-time Features 🚧
- [ ] Price alert system with Platform Events
- [ ] Live notifications in UI
- [ ] Multi-user collaboration updates

### Phase 3: Analytics & Insights 📋
- [ ] Tableau CRM dashboards
- [ ] Portfolio performance analytics
- [ ] Sector allocation visualizations

### Phase 4: Portal & Advisor Features 📋
- [ ] Experience Cloud investor portal
- [ ] Advisor dashboard
- [ ] Client portfolio management

---

⭐ Star if useful!