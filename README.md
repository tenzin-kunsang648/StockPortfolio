# Stock Portfolio Tracker

Real-time stock portfolio management platform built on Salesforce

<!-- ![Portfolio Dashboard](images/portfolio-dashboard.png) -->

## Features (What I have and what I am envisioning in next phases)
- DONE Real-time stock data via Alpha Vantage API
- DONE Multiple portfolio management
- DONE Interactive portfolio dashboard with live updates
- HAVEN'T STARTED YET Advanced analytics with Tableau CRM
- HAVEN'T STARTED YET Dual portal architecture (investor + advisor)
- DONE Automated price updates

## What is done so far
- DONE Complete Data model - 4 custom objects with relationships
- DONE API Integration layer - StockAPIService connecting to Alpha Vantage 
- DONE Business Logic - StockDataService & PortfolioService for all operations
- DONE Batch Processing - Scheduled job for automatic price updates
- DONE LWC Component - Stock search with add-to-portfolio functionality
- DONE Portfolio Dashboard LWC - Main dashboard showing positions, performance, and allocation
- DONE Apex Controller - Backend support for all LWC operations

## Tech Stack
- Salesforce Lightning Platform
- Apex (REST API, Batch Processing, Triggers)
- Lightning Web Components
- Tableau CRM/Einstein Analytics (In Progress)
- Experience Cloud (Planned)

## Architecture

![Data Model](images/data_model.png)
