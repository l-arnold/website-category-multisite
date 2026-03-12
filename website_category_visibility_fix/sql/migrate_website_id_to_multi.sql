-- Migration Script: Convert website_id to Multi-Website Table
-- 
-- Purpose: Migrate products using the legacy website_id field to the 
--          product_template2website_rel relationship table
--
-- When to run: 
--   - After discovering products with website_id set
--   - Before deploying updated category_website_matrix.sql and 
--     product_visibility_trigger.sql
--
-- Safe to run multiple times (uses INSERT ... ON CONFLICT DO NOTHING pattern)

BEGIN;

-- Count products needing migration
SELECT COUNT(*) as products_to_migrate
FROM product_template
WHERE website_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM product_template2website_rel ptw
      WHERE ptw.product_id = product_template.id
  );

-- Insert multi-website assignments from website_id field
INSERT INTO product_template2website_rel (product_id, website_id)
SELECT id, website_id
FROM product_template
WHERE website_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM product_template2website_rel ptw
      WHERE ptw.product_id = product_template.id
  );

-- Show what was migrated
SELECT pt.id, pt.name, w.name as website
FROM product_template pt
JOIN website w ON w.id = pt.website_id
WHERE pt.website_id IS NOT NULL
ORDER BY pt.name;

-- Clear website_id field after successful migration
UPDATE product_template
SET website_id = NULL
WHERE website_id IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM product_template2website_rel ptw
      WHERE ptw.product_id = product_template.id
  );

-- Verify migration success (should return 0)
SELECT COUNT(*) as remaining_website_id_assignments
FROM product_template
WHERE website_id IS NOT NULL;

-- Refresh materialized view with new assignments
REFRESH MATERIALIZED VIEW category_website_matrix;

-- Trigger product visibility recalculation
UPDATE product_template SET write_date = NOW() WHERE active = TRUE;

COMMIT;

-- Post-migration verification queries
-- Uncomment to run after COMMIT:

-- SELECT 'Migration complete!' as status;
-- 
-- -- Show products now in multi-website table
-- SELECT COUNT(*) as migrated_products
-- FROM product_template2website_rel;