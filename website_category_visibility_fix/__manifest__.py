{
    'name': 'Website Category Visibility Fix',
    'version': '14.0.1.0.0',
    'category': 'Website/Website',
    'summary': 'Fix category hiding for multi-website installations',
    'description': """
        Fixes the website_sale_hide_empty_category module to work correctly
        with multi-website and multi-company setups.
        
        Uses the category_website_matrix materialized view to determine
        category visibility per website.
    """,
    'author': 'Nomadic Inc',
    'license': 'LGPL-3',
    'depends': [
        'website_sale',
        'website_sale_hide_empty_category',
    ],
    'installable': True,
    'auto_install': False,
}