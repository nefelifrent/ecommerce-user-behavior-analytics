# E-Commerce User Behavior Analytics

Business Intelligence project built with **Google BigQuery** and **Looker Studio** to analyze customer behavior, conversion, revenue, and retention using real-world e-commerce event data.

## Dashboard Preview

![Dashboard](dashboard.png)

🔗 **[View Interactive Dashboard](https://datastudio.google.com/reporting/2246edc2-0e4c-46c9-85e6-1bba481e9018)**

## Project Overview

This project analyzes customer behavior in a large multi-category e-commerce store using SQL, Google BigQuery, and Looker Studio.

The analysis is based on the "eCommerce Behavior Data from Multi Category Store" dataset published on [Kaggle](https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store). The original dataset contains approximately 285 million user events collected over seven months (October 2019 – April 2020). For this project, the analysis focuses on October and November 2019, allowing month-over-month comparisons of user engagement, revenue, conversion, and retention.

Each row in the dataset represents a user interaction with the platform, including events such as:

* Product View
* Add to Cart
* Purchase

The project demonstrates how event-level data can be transformed into business metrics and interactive dashboards that support data-driven decision making.

## Business Questions

- How many users actively use the platform each month?
- How has revenue changed from October to November?
- What percentage of active users complete a purchase?
- Which product categories generate the highest revenue?
- Which brands contribute the most to total sales?
- Where do users drop off in the purchase funnel?
- How many users return the following month?
- What is the monthly retention rate?

## Tech Stack 

- ☁️ Google Cloud Storage
- 📊 Google BigQuery
- 🗄️ SQL (Standard SQL)
- 📈 Looker Studio
- 🐙 GitHub

## Project Architecture

The project follows a modern cloud-based analytics pipeline, transforming raw event data into business insights through Google Cloud and Looker Studio.

```text
Kaggle Dataset (CSV)
        │
        ▼
Google Cloud Storage
        │
        ▼
BigQuery Raw Tables
        │
        ▼
Partitioned Analytics Table
        │
        ▼
SQL Analysis & Dashboard Views
        │
        ▼
Looker Studio Dashboard
```

### Pipeline Overview

1. **Kaggle Dataset** – The project uses the *eCommerce Behavior Data from Multi Category Store* dataset containing real-world e-commerce event data.

2. **Google Cloud Storage** – The CSV files were uploaded to Google Cloud Storage because they exceeded the BigQuery Sandbox local upload limit.

3. **BigQuery Raw Tables** – The original October and November datasets were imported into separate raw tables without modifications.

4. **Partitioned Analytics Table** – The raw tables were combined into a single partitioned table to improve query performance and reduce the amount of data scanned.

5. **SQL Analysis & Dashboard Views** – Exploratory analysis, KPI calculations, funnel analysis, retention analysis, and dashboard views were created using Standard SQL.

6. **Looker Studio Dashboard** – The final interactive dashboard visualizes the key business metrics and insights generated from the analytical views.

