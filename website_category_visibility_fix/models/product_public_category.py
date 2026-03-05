from odoo import api, models
from odoo.http import request


class ProductPublicCategory(models.Model):
    _inherit = "product.public.category"
    
    @api.depends("product_tmpl_ids", "child_id.has_product_recursive")
    def _compute_has_product_recursive(self):
        """
        Override to make website-aware using category_website_matrix view.
        """
        # Get current website
        website = None
        try:
            if request and hasattr(request, 'website'):
                website = request.website
        except RuntimeError:
            # No request context (backend operations)
            pass
        
        if not website:
            # Fallback to context or first website
            website_id = self.env.context.get('website_id')
            if website_id:
                website = self.env['website'].browse(website_id)
            else:
                website = self.env['website'].search([], limit=1)
        
        if not website:
            # No website context - use original parent behavior
            return super()._compute_has_product_recursive()
        
        # Query the materialized view for website-specific visibility
        for category in self:
            self.env.cr.execute("""
                SELECT published_on_website
                FROM category_website_matrix
                WHERE category_id = %s 
                  AND website_id = %s
            """, (category.id, website.id))
            
            result = self.env.cr.fetchone()
            
            # Has products on this website?
            has_products = bool(result and result[0] > 0)
            
            # Check if children have products (recursive)
            has_children_with_products = any(
                child.has_product_recursive 
                for child in category.child_id
            )
            
            # Category visible if it OR its children have products
            category.has_product_recursive = (
                has_products or has_children_with_products
            )