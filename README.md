# Backend Case Study – Inventory Management System

This repository contains my solution for the Backend Engineering Intern case study.

## Structure

- `part1_code_review.md`  
  Code review and debugging analysis of the given API endpoint.

- `part2_database_design.sql`  
  Database schema design covering companies, warehouses, products, inventory, suppliers, and transactions.

- `part3_api_implementation.py`  
  Implementation of low-stock alert API with business rules and assumptions documented in comments.

## Assumptions
- Products can exist in multiple warehouses.
- SKUs are unique across the platform.
- Low-stock threshold varies by product type.
- Only products with recent sales activity are considered for alerts.

## Tech Stack
- Language: Python
- Framework: Flask (assumed)
- Database: PostgreSQL (assumed)
