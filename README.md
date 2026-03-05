# website-category-multisite
Module 1:  Fix category hiding for multi-website Odoo installations
Other modules may be added to this repository in the future

# Website Category Multi-Site Fix

Fixes category visibility for multi-website, multi-company Odoo 14 installations.

## Problem

The OCA `website_sale_hide_empty_category` module only checks if categories have products *anywhere*, not if they have products on the *current website*.

## Solution

This module:
- Creates a PostgreSQL materialized view tracking category/website product counts
- Overrides `has_product_recursive` to be website-aware
- Respects company assignments via `product_template_res_company_rel`

## Installation

1. **Install PostgreSQL view:**
```bash
   psql -U postgres -d your_database < sql/category_website_matrix.sql
```

2. **Deploy module:**
```bash
   cp -r website_category_visibility_fix /opt/odoo/addons_extra/
   sudo chown -R odoo:odoo /opt/odoo/addons_extra/website_category_visibility_fix
   sudo systemctl restart odoo
```

3. **Install in Odoo:**
   - Apps → Update Apps List
   - Search: "Website Category Visibility Fix"
   - Install

## Dependencies

- `website_sale`
- `website_sale_hide_empty_category` (OCA)

## License

LGPL-3.0
```

---

## **Step 4: Commit and Push**

**In GitHub Desktop:**
```
1. You'll see all new files listed
2. Summary: "Initial commit - Category visibility fix"
3. Description: "Multi-website category hiding module with materialized view"
4. Click "Commit to main"
5. Click "Push origin"