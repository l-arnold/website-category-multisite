-- Category × Website Product Count Matrix
-- This materialized view tracks which categories should be visible on each website
-- based on published products, company assignments, and website assignments.

DROP MATERIALIZED VIEW IF EXISTS category_website_matrix CASCADE;

CREATE MATERIALIZED VIEW category_website_matrix AS
SELECT 
    pc.id as category_id,
    pc.name as category_name,
    pc.sequence as category_sequence,
    pc.parent_id as parent_category_id,
    w.id as website_id,
    w.name as website_name,
    w.company_id as website_company_id,
    COUNT(DISTINCT rel.product_template_id) as total_products_in_category,
    COUNT(DISTINCT pt.id) as products_on_website,
    COUNT(DISTINCT CASE WHEN pt.is_published THEN pt.id END) as published_on_website,
    (pc.website_id = w.id OR pc.website_id IS NULL) as category_allowed_on_website,
    (COUNT(DISTINCT CASE WHEN pt.is_published THEN pt.id END) = 0) as should_hide,
    CASE 
        WHEN pc.website_id = w.id OR pc.website_id IS NULL THEN
            CASE 
                WHEN COUNT(DISTINCT CASE WHEN pt.is_published THEN pt.id END) > 0 
                THEN 'Show (' || COUNT(DISTINCT CASE WHEN pt.is_published THEN pt.id END) || ' products)'
                ELSE 'Hide (empty)'
            END
        ELSE 'Not allowed on this website'
    END as display_status
FROM product_public_category pc
CROSS JOIN website w
LEFT JOIN product_public_category_product_template_rel rel 
    ON rel.product_public_category_id = pc.id
LEFT JOIN product_template pt 
    ON pt.id = rel.product_template_id
    AND pt.active = TRUE
    -- Check single website_id field (takes precedence)
    AND (pt.website_id = w.id OR pt.website_id IS NULL)
    -- Check multi-website assignments
    AND (
        EXISTS (
            SELECT 1 FROM product_template2website_rel ptw
            WHERE ptw.product_id = pt.id AND ptw.website_id = w.id
        )
        OR NOT EXISTS (
            SELECT 1 FROM product_template2website_rel ptw
            WHERE ptw.product_id = pt.id
        )
    )
    AND (
        EXISTS (
            SELECT 1 FROM product_template_res_company_rel ptc
            WHERE ptc.product_template_id = pt.id AND ptc.res_company_id = w.company_id
        )
        OR NOT EXISTS (
            SELECT 1 FROM product_template_res_company_rel ptc
            WHERE ptc.product_template_id = pt.id
        )
    )
WHERE pc.active = TRUE
GROUP BY pc.id, pc.name, pc.sequence, pc.parent_id, w.id, w.name, w.company_id;

-- Refresh after creation
REFRESH MATERIALIZED VIEW category_website_matrix;