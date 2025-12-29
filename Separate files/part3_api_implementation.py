Part 3: API Implementation 
Low Stock Alerts API Implementation

ASSUMPTIONS:
1. Database Schema:
   - products: id, name, sku, product_type, company_id
   - inventory: product_id, warehouse_id, quantity, last_updated
   - warehouses: id, name, company_id
   - suppliers: id, name, contact_email
   - product_suppliers: product_id, supplier_id, is_primary
   - sales: product_id, warehouse_id, quantity, sale_date
   - stock_thresholds: product_type, threshold_quantity

2. Business Logic:
   - "Recent sales activity" = sales within last 30 days
   - Days until stockout calculated from average daily sales (last 30 days)
   - Low stock = current_stock < threshold for that product type
   - If multiple suppliers exist, use primary supplier
   - Default threshold = 10 if product type not configured

3. Performance Considerations:
   - Query should use proper indexes on company_id, warehouse_id, product_id
   - Should paginate for companies with many products
   - Consider caching threshold configurations


Program Code :

from flask import Flask, jsonify, request
from datetime import datetime, timedelta

app = Flask(__name__)

class LowStockAlertService:
    def __init__(self, db_session):
        self.db = db_session
        self.recent_days = 30
        self.default_threshold = 10
    
    def get_alerts(self, company_id, warehouse_id=None, limit=100, offset=0):
        try:
            # Get products with recent sales
            recent_date = datetime.now() - timedelta(days=self.recent_days)
            products = self._get_active_products(company_id, recent_date)
            
            if not products:
                return {"alerts": [], "total_alerts": 0}, 200
            
            # Get inventory and thresholds
            inventory = self._get_inventory(company_id, products, warehouse_id)
            thresholds = self._get_thresholds()
            
            # Build alerts
            alerts = []
            for inv in inventory:
                threshold = thresholds.get(inv['product_type'], self.default_threshold)
                
                if inv['current_stock'] < threshold:
                    alerts.append({
                        "product_id": inv['product_id'],
                        "product_name": inv['product_name'],
                        "sku": inv['sku'],
                        "warehouse_id": inv['warehouse_id'],
                        "warehouse_name": inv['warehouse_name'],
                        "current_stock": inv['current_stock'],
                        "threshold": threshold,
                        "days_until_stockout": self._calc_stockout_days(
                            inv['product_id'], inv['warehouse_id'], 
                            inv['current_stock'], recent_date
                        ),
                        "supplier": self._get_supplier(inv['product_id'])
                    })
            
            # Sort by urgency
            alerts.sort(key=lambda x: (x['days_until_stockout'] is None, 
                                      x['days_until_stockout'] or float('inf')))
            
            return {
                "alerts": alerts[offset:offset + limit],
                "total_alerts": len(alerts)
            }, 200
            
        except Exception as e:
            return {"error": str(e)}, 500
    
    def _get_active_products(self, company_id, recent_date):
        query = """
            SELECT DISTINCT p.id FROM products p
            JOIN sales s ON s.product_id = p.id
            WHERE p.company_id = :cid AND s.sale_date >= :date
        """
        result = self.db.execute(query, {"cid": company_id, "date": recent_date})
        return [r[0] for r in result]
    
    def _get_inventory(self, company_id, product_ids, warehouse_id):
        wh_filter = "AND w.id = :wid" if warehouse_id else ""
        params = {"cid": company_id, "pids": tuple(product_ids)}
        if warehouse_id:
            params["wid"] = warehouse_id
            
        query = f"""
            SELECT p.id as product_id, p.name as product_name, p.sku,
                   p.product_type, i.warehouse_id, w.name as warehouse_name,
                   i.quantity as current_stock
            FROM products p
            JOIN inventory i ON i.product_id = p.id
            JOIN warehouses w ON w.id = i.warehouse_id
            WHERE p.company_id = :cid AND p.id IN :pids {wh_filter}
        """
        return [dict(r) for r in self.db.execute(query, params)]
    
    def _get_thresholds(self):
        result = self.db.execute("SELECT product_type, threshold_quantity FROM stock_thresholds")
        return {r[0]: r[1] for r in result}
    
    def _calc_stockout_days(self, product_id, warehouse_id, stock, recent_date):
        query = """
            SELECT COALESCE(SUM(quantity), 0) FROM sales
            WHERE product_id = :pid AND warehouse_id = :wid AND sale_date >= :date
        """
        total_sold = self.db.execute(
            query, {"pid": product_id, "wid": warehouse_id, "date": recent_date}
        ).scalar()
        
        if total_sold == 0:
            return None
        
        days = (datetime.now() - recent_date).days
        avg_daily = total_sold / days
        return int(stock / (avg_daily + 0.001))
    
    def _get_supplier(self, product_id):
        query = """
            SELECT s.id, s.name, s.contact_email FROM suppliers s
            JOIN product_suppliers ps ON ps.supplier_id = s.id
            WHERE ps.product_id = :pid AND ps.is_primary = TRUE LIMIT 1
        """
        row = self.db.execute(query, {"pid": product_id}).fetchone()
        return {"id": row[0], "name": row[1], "contact_email": row[2]} if row else None


@app.route('/api/companies/<int:company_id>/alerts/low-stock')
def get_low_stock_alerts(company_id):
    warehouse_id = request.args.get('warehouse_id', type=int)
    limit = min(request.args.get('limit', 100, type=int), 500)
    offset = max(request.args.get('offset', 0, type=int), 0)
    
    # db_session = get_db_session()  # Your DB session
    db_session = None
    service = LowStockAlertService(db_session)
    response, status = service.get_alerts(company_id, warehouse_id, limit, offset)
    return jsonify(response), status


if __name__ == '__main__':
    app.run(debug=True)
