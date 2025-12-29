Part 1: Code Review & Debugging

Issue 1: No Input Validation
Description:
The API directly accesses request.json without validating the presence, structure, or data types of required fields.

Production Impact:
Invalid or malformed requests can cause server crashes, return 500 errors, and lead to poor API reliability in production.

Fix:
Validate request body, required fields, data types, and acceptable value ranges before processing the request.


Issue 2: No Error Handling
Description:
The function lacks try-except blocks to handle database errors, constraint violations, or unexpected runtime failures.

Production Impact:
Unhandled exceptions will crash the request and return generic 500 errors, making debugging and user experience worse.

Fix:
Wrap database operations in a try-except block and handle failures gracefully with proper rollback and error
responses.


Issue 3: Missing SKU Uniqueness Check
Description:
The code does not verify whether a product with the same SKU already exists, violating the business rule of SKU uniqueness.

Production Impact:
Duplicate SKUs can cause incorrect inventory tracking, reporting errors, and confusion across the platform.

Fix:
Check for existing SKU before product creation and return a meaningful error response if it already exists.



Issue 4: Race Condition (TOCTOU)
Description:
Even with an application-level SKU check, concurrent requests can still create duplicate SKUs due to race conditions.

Production Impact:
High-traffic systems may end up with duplicate products despite validation logic.

Fix:
Enforce SKU uniqueness at the database level using a UNIQUE constraint and handle constraint violations gracefully.



Issue 5: No Transaction Atomicity
Description:
The code commits the product and inventory in two separate transactions.

Production Impact:
Partial data may be saved if inventory creation fails, leading to inconsistent database state.

Fix:
Use a single transaction to ensure atomicity and rollback on failure.


Issue 6: Incorrect Multi-Warehouse Business Logic.
Description:
The implementation assumes a product belongs to only one warehouse, conflicting with the requirement that products can exist in multiple warehouses.

Production Impact:
The system cannot correctly manage inventory across multiple warehouses for the same product.


Fix:
Decouple product creation from inventory creation and allow inventory records per warehouse.



Issue 7: Missing HTTP Status Codes
Description:
The API response does not specify HTTP status codes explicitly.

Production Impact:
Clients cannot reliably determine success or failure based on response status.

Fix:
Return appropriate HTTP status codes such as 201 (Created), 400 (Bad Request), and 409 (Conflict).



Issue 8: Missing REST Response Headers
Description:
The response lacks a Location header pointing to the newly created resource.

Production Impact:
Violates REST best practices and reduces API usability for clients.

Fix:
Include a Location header with the URI of the created product.


Issue 9: Lack of Logging
Description:
No logging is implemented for successful operations or failures.


Production Impact:
Troubleshooting, auditing, and monitoring become difficult in production.

Fix:
Add structured logging for product creation events and error cases.


//Program Code (Solve the Issue)


export default ThemeToggleBtn;
from flask import request, jsonify
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from decimal import Decimal, InvalidOperation

import logging

# Configure logging
logger = logging.getLogger(__name__)
@app.route('/api/products', methods=['POST'])
def create_product():

# Create a new product or add inventory to existing product in a warehouse.

Expected JSON payload:

{
"name": "Product Name",
"sku": "UNIQUE-SKU",
"price": 99.99,
"warehouse_id": 1,
"initial_quantity": 100
}

Returns:

201: Product created successfully
400: Invalid input data
409: SKU already exists (when trying to create new product)
500: Server error

# STEP 1: VALIDATE REQUEST FORMAT
# Check if request has JSON content type

if not request.is_json:

logger.warning("Request received without JSON content type")
return jsonify(
  {
"error": "Content-Type must be application/json"
}), 
400

data = request.get_json()

# Check if JSON is valid (not None or empty)
if not data:
logger.warning("Empty JSON payload received")
return jsonify(
  {
"error": "Request body cannot be empty"
}), 400


# STEP 2: VALIDATE REQUIRED FIELDS
required_fields = ['name', 'sku', 'price', 'warehouse_id', 'initial_quantity']
missing_fields = [field for field in required_fields if field not in data]
if missing_fields:
logger.warning(f"Missing required fields: {missing_fields}")
return jsonify({
"error": "Missing required fields",
"missing_fields": missing_fields
}), 400

# STEP 3: VALIDATE DATA TYPES AND VALUE
errors = []
# Validate name (string, not empty)
if not isinstance(data['name'], str) or not data['name'].strip():
errors.append("name must be a non-empty string")

# Validate SKU (string, not empty, reasonable length)
if not isinstance(data['sku'], str) or not data['sku'].strip():
errors.append("sku must be a non-empty string")
elif len(data['sku']) > 50:
errors.append("sku must be 50 characters or less")

# Validate price (positive decimal/float)
try:
price = Decimal(str(data['price']))
if price <= 0:
errors.append("price must be greater than 0")
elif price > Decimal('999999.99'):
errors.append("price exceeds maximum allowed value")
except (InvalidOperation, ValueError, TypeError):
errors.append("price must be a valid decimal number")

# Validate warehouse_id (positive integer)
if not isinstance(data['warehouse_id'], int) or data['warehouse_id'] <= 0:
errors.append("warehouse_id must be a positive integer")

# Validate initial_quantity (non-negative integer)
if not isinstance(data['initial_quantity'], int) or data['initial_quantity'] < 0:
errors.append("initial_quantity must be a non-negative integer")
if errors:
logger.warning(f"Validation errors: {errors}")
return jsonify({
"error": "Invalid input data",
"validation_errors": errors
}), 400


# STEP 4: SANITIZE INPUT DATA
name = data['name'].strip()
sku = data['sku'].strip().upper() # Normalize SKU to uppercase
price = Decimal(str(data['price']))
warehouse_id = data['warehouse_id']
initial_quantity = data['initial_quantity']

# STEP 5: DATABASE OPERATIONS WITH TRANSACTION
try:
# Start transaction (implicit with session, but we'll be explicit about commit/rollback)
# SUB-STEP 5A: CHECK IF WAREHOUSE EXISTS
warehouse = Warehouse.query.filter_by(id=warehouse_id).first()
if not warehouse:
logger.warning(f"Warehouse {warehouse_id} not found")
return jsonify({
"error": "Warehouse not found",
"warehouse_id": warehouse_id
}), 400

# SUB-STEP 5B: CHECK IF PRODUCT WITH SKU EXISTS
existing_product = Product.query.filter_by(sku=sku).with_for_update().first()
if existing_product:
# Product exists - check if we should add inventory to new warehouse
# or if this is a duplicate creation attempt for same warehouse
existing_inventory = Inventory.query.filter_by(
product_id=existing_product.id,
warehouse_id=warehouse_id
).
first()
if existing_inventory:
# Product already exists in this warehouse
logger.info(f"Product {sku} already exists in warehouse {warehouse_id}")
return jsonify({
"error": "Product already exists in this warehouse",
"product_id": existing_product.id,
"sku": sku,
"warehouse_id": warehouse_id,
"suggestion": "Use PATCH /api/products/{id}/inventory to update quantity"
}), 409
else:
# Product exists but not in this warehouse - add inventory
logger.info(f"Adding product {sku} to warehouse {warehouse_id}")
inventory = Inventory(
product_id=existing_product.id,
warehouse_id=warehouse_id,
quantity=initial_quantity
)db.session.add(inventory)
db.session.commit()
logger.info(f"Successfully added inventory for product {existing_product.id} to warehouse
{warehouse_id}")
return jsonify({
"message": "Product added to warehouse",
"product_id": existing_product.id,
"sku": existing_product.sku,
"warehouse_id": warehouse_id,
"quantity": initial_quantity
}), 201, {
'Location': f'/api/products/{existing_product.id}'
}

# SUB-STEP 5C: CREATE NEW PRODUCT
# Product doesn't exist - create new product and inventory
logger.info(f"Creating new product with SKU {sku}")
product = Product(
name=name, sku=sku, price=price,
warehouse_id=warehouse_id # Note: This field might need review based on multi-warehouse design
)db.session.add(product)
db.session.flush() # Flush to get product.id without committing
# SUB-STEP 5D: CREATE INVENTORY RECORD
inventory = Inventory(
product_id=product.id,
warehouse_id=warehouse_id,
quantity=initial_quantity )
db.session.add(inventory)
# SUB-STEP 5E: COMMIT TRANSACTION (ATOMIC)
# Both product and inventory are committed together
db.session.commit()
logger.info(f"Successfully created product {product.id} with SKU {sku} in warehouse {warehouse_id}")
# STEP 6: RETURN SUCCESS RESPONSE
return jsonify({
"message": "Product created successfully",
"product_id": product.id,
"sku": product.sku,
"name": product.name,
"price": float(product.price),
"warehouse_id": warehouse_id,
"initial_quantity": initial_quantity
}), 201, {
'Location': f'/api/products/{product.id}'
}


# STEP 7: ERROR HANDLIND
except IntegrityError as e:
# Rollback transaction
db.session.rollback()
# This handles UNIQUE constraint violations and foreign key errors
error_msg = str(e.orig)
if 'sku' in error_msg.lower() or 'unique' in error_msg.lower():
# SKU uniqueness violation (race condition caught at database level)
logger.error(f"SKU uniqueness violation for {sku}: {error_msg}")
return jsonify({
"error": "Product with this SKU already exists",
"sku": sku
}), 409
else:
# Other integrity errors (foreign key, etc.)
logger.error(f"Database integrity error: {error_msg}")
return jsonify({
"error": "Database integrity error",
"details": "Invalid reference to related data"
}), 400
except SQLAlchemyError as e:
# Rollback transaction
db.session.rollback()
# General database errors (connection issues, etc.)
logger.error(f"Database error: {str(e)}", exc_info=True)
return jsonify({
"error": "Database error occurred",
"message": "Please try again later"
}), 500
except Exception as e:
# Rollback transaction
db.session.rollback()
# Catch any unexpected errors
logger.error(f"Unexpected error in create_product: {str(e)}", exc_info=True)
return jsonify({
"error": "Internal server error",
"message": "An unexpected error occurred"
}), 500