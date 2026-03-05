-- Product Visibility Trigger Function
-- Computes which websites a product should appear on
-- Populates: vis_check_*, visible_websites, assigned_companies fields

CREATE OR REPLACE FUNCTION public.compute_product_visibility()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    website_list TEXT;
    blocks TEXT := '';
    company_list TEXT;
BEGIN
    -- Check 1: Published?
    NEW.vis_check_published := (NEW.is_published = TRUE);
    IF NOT NEW.vis_check_published THEN
        blocks := blocks || 'Not published; ';
    END IF;

    -- Check 2: Has visible categories?
    NEW.vis_check_categories := EXISTS (
        SELECT 1
        FROM product_public_category_product_template_rel
        WHERE product_template_id = NEW.id
    );
    IF NOT NEW.vis_check_categories THEN
        blocks := blocks || 'No categories; ';
    END IF;

    -- Check 3: Website assignment
    NEW.vis_check_websites := TRUE;

    -- Check 4: Company assignments
    NEW.vis_check_company := EXISTS (
        SELECT 1 
        FROM product_template_res_company_rel 
        WHERE product_template_id = NEW.id
    );
    
    -- Get company names for assigned_companies field
    SELECT string_agg(c.name, ', ' ORDER BY c.name)
    INTO company_list
    FROM product_template_res_company_rel ptc
    JOIN res_company c ON c.id = ptc.res_company_id
    WHERE ptc.product_template_id = NEW.id;
    
    NEW.assigned_companies := COALESCE(company_list, 'No company assigned');
    
    -- Add to blocks if no company
    IF NOT NEW.vis_check_company THEN
        blocks := blocks || 'No company assigned; ';
    END IF;

    -- Compute visible websites
    SELECT string_agg(DISTINCT w.name, ', ' ORDER BY w.name)
    INTO website_list
    FROM website w
    WHERE NEW.is_published = TRUE
      AND (
          EXISTS (
              SELECT 1 
              FROM product_template_res_company_rel ptc
              WHERE ptc.product_template_id = NEW.id 
                AND ptc.res_company_id = w.company_id
          )
          OR NOT EXISTS (
              SELECT 1 
              FROM product_template_res_company_rel ptc
              WHERE ptc.product_template_id = NEW.id
          )
      )
      AND (
          EXISTS (
              SELECT 1
              FROM product_template2website_rel ptw
              WHERE ptw.product_id = NEW.id
                AND ptw.website_id = w.id
          )
          OR NOT EXISTS (
              SELECT 1
              FROM product_template2website_rel ptw
              WHERE ptw.product_id = NEW.id
          )
      )
      AND EXISTS (
          SELECT 1
          FROM product_public_category_product_template_rel crel
          JOIN product_public_category c ON c.id = crel.product_public_category_id
          WHERE crel.product_template_id = NEW.id
            AND (c.website_id = w.id OR c.website_id IS NULL)
      );

    NEW.visible_websites := COALESCE(website_list, '');
    NEW.is_visible_anywhere := (website_list IS NOT NULL AND website_list != '');
    NEW.visibility_blocks := NULLIF(TRIM(TRAILING '; ' FROM blocks), '');

    RETURN NEW;
END;
$$;

-- Create trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'product_visibility_trigger'
    ) THEN
        CREATE TRIGGER product_visibility_trigger
        BEFORE INSERT OR UPDATE ON product_template
        FOR EACH ROW
        EXECUTE FUNCTION compute_product_visibility();
    END IF;
END $$;