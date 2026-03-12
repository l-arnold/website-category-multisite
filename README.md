# website-category-multisite
Module 1:  Fix category hiding for multi-website Odoo installations
Other modules may be added to this repository in the future

# Website Category Multi-Site Fix

Fixes category visibility for multi-website, multi-company Odoo 14 installations.

## Problem

The OCA `website_sale_hide_empty_category` module only checks if categories have products *anywhere*, not if they have products on the *current website*.  This means that Categories will display in the tree of Websites where no products are configured to show on that specific website.  

## Solution

This module:
- Creates a PostgreSQL materialized view tracking category/website product counts
- Overrides `has_product_recursive` to be website-aware
- Respects company assignments via `product_template_res_company_rel`
      
### Installing OCA Dependencies

If not already installed:
```bash
# Add OCA multi-company repository
cd /opt/odoo/addons_oca
git clone -b 14.0 https://github.com/OCA/multi-company.git

# Add OCA e-commerce repository
git clone -b 14.0 https://github.com/OCA/e-commerce.git

# Update odoo.conf
sudo nano /etc/odoo/odoo.conf
# Add paths to addons_path:
# /opt/odoo/addons_oca/multi-company,
# /opt/odoo/addons_oca/e-commerce,

# Restart Odoo
sudo systemctl restart odoo

# Install required modules
# Apps → Update Apps List
# Search and install:
#   - Product Multi Company
#   - Website Sale Hide Empty Category
```

**Then install this module.**
   
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
   
## Use Case Example

**Scenario:**
- Multiple companies in one Odoo instance
- Multiple websites per company
- Products assigned to specific companies/websites
- Categories should only show where they have relevant products

**Example:**
```
Company A:
├─ Website 1 (primary e-commerce)
├─ Website 2 (legacy site)
└─ Website 3 (brand showcase)

Company B:
└─ Website 4 (separate brand)

Product: "Premium Widget"
├─ Assigned to: Company A only
├─ Visible on: Website 1, Website 2
└─ Hidden on: Website 4 (different company)

Category: "Premium Products"
├─ On Website 4: HIDE (0 products for Company B)
└─ On Website 1: SHOW (15 products for Company A)
```

**Result:**
- Category "Premium Products" automatically hides on Website 4 (Company B)
- Category remains visible on Websites 1-3 (Company A)
- No manual category management needed
   
## Known Issues

### Product website_id Field Conflicts

**Problem:** Odoo supports two methods for website assignment:
1. `product_template.website_id` (legacy single-website field)
2. `product_template2website_rel` table (current multi-website approach)

If both are set, `website_id` takes precedence and overrides multi-website assignments, causing products to not appear on expected websites.

**Solution:** Run the migration script to convert all legacy assignments:
```bash
psql -U odoo nomadic < sql/migrate_website_id_to_multi.sql
```

**Best Practice:** Always use the multi-website relationship table. Keep `website_id` = NULL for all products.

## Related Modules in Production

**Multi-Company:**
- `product_multi_company` - Product company assignments
- `base_multi_company` - Core multi-company infrastructure
- `account_multicompany_easy_creation` - Company setup helpers

**Website/E-commerce:**
- `website_sale_hide_empty_category` - Base category hiding (extended by this module)
- `website_sale_product_multiwebsite` - Product website assignments
- `website_blog_backend_editor` - Blog management

**Other Custom:**
- `website_recaptcha_v2` - reCAPTCHA v2 backport
- `fedex_shipping_odoo_integration` - Shipping integration
-  (placeholder, will add others relevant modules in future updates to this document)

---

## Maintenance

### Refresh Materialized View

After bulk product updates, category changes, or website assignments:
```bash
psql -U odoo nomadic -c "REFRESH MATERIALIZED VIEW category_website_matrix;"
```

### Recalculate Product Visibility

After company assignments or trigger updates:
```bash
psql -U odoo nomadic << EOF
UPDATE product_template SET write_date = NOW();
REFRESH MATERIALIZED VIEW category_website_matrix;
EOF
```

### Troubleshooting

**Categories not hiding on website:**
1. Refresh materialized view (see above)
2. Clear Odoo cache: Settings → Technical → Database Structure → Clear Assets Cache
3. Check Odoo logs: `sudo tail -f /var/log/odoo/odoo-server.log`

**Product not appearing on expected website:**
1. Check for legacy website_id: 
```sql
   SELECT id, name, website_id FROM product_template WHERE id = XXX;
```
   If not NULL, run migration script
2. Verify multi-website assignments:
```sql
   SELECT w.name FROM website w
   JOIN product_template2website_rel ptw ON ptw.website_id = w.id
   WHERE ptw.product_id = XXX;
```
3. Check company assignment:
```sql
   SELECT c.name FROM res_company c
   JOIN product_template_res_company_rel ptc ON ptc.res_company_id = c.id
   WHERE ptc.product_template_id = XXX;
```

## Module Dependencies & Architecture

### Required Odoo Modules

**Core Dependencies:**
- `website_sale` (Odoo standard)
- `website_sale_hide_empty_category` (OCA e-commerce)

**Multi-Company Dependencies:**
- `product_multi_company` (OCA multi-company)
  - Provides `product_template_res_company_rel` relationship table
  - Required for company-based product filtering
- `base_multi_company` (OCA multi-company)
- `web_multi_company` (OCA multi-company)

**Website Management:**
- `website` (Odoo standard)
- `website_sale_product_multiwebsite` (or similar - enables product-to-website assignments)

### How It Works

This module extends the OCA `website_sale_hide_empty_category` module to make it **website-aware** and **multi-company aware**.

**Without this module:**
- OCA module checks if category has products globally
- Categories show on ALL websites if they have ANY published products
- No consideration for company assignments

**With this module:**
- Categories hide/show based on products available on THAT specific website
- Respects multi-company product assignments
- Uses PostgreSQL materialized view for performance
- Trigger functions maintain product visibility fields

### Architecture
```
PostgreSQL Layer:
├─ category_website_matrix (materialized view)
│  └─ Pre-computes category visibility per website
├─ compute_product_visibility() (trigger function)
│  └─ Calculates which websites show each product
└─ update_product_on_company_change() (trigger function)
   └─ Cascades company assignment changes

Odoo Module Layer:
└─ product_public_category.py
   └─ Overrides _compute_has_product_recursive
   └─ Queries materialized view for current website
```

**Data Flow:**
1. Product published/company assigned → Trigger fires
2. Trigger updates product visibility fields
3. Category viewed on website → Module checks materialized view
4. Returns TRUE/FALSE for has_product_recursive
5. OCA module hides category if FALSE

### Compatibility

**Tested with:**
- Odoo 14.0
- OCA multi-company modules (14.0)
- TurnkeyLinux 17.1 (Debian 11)
- PostgreSQL 13+

**Should work with:**
- Any Odoo 14.x installation
- Standard multi-company setup
- Multi-website configurations

**Not compatible with:**
- Single-company installations (module works but is unnecessary)
- Odoo versions < 14 (different OCA module versions)

## License

LGPL-3.0

## Copyright

Landis Arnold
Nomadic, Inc
2026
```

---
