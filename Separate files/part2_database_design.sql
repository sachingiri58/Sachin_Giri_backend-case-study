Part 2: Database Design 

## i) Company Table: 

CREATE TABLE companies (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    legal_name VARCHAR(255),
    tax_id VARCHAR(50),
    
    -- Contact information
    email VARCHAR(255),
    phone VARCHAR(50),
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state_province VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT,
    updated_by BIGINT,
    
    CONSTRAINT companies_name_unique UNIQUE (name)
);

CREATE INDEX idx_companies_status ON companies(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_companies_country ON companies(country) WHERE is_deleted = FALSE;


## II) Warehouse Table  
CREATE TABLE warehouses (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    
    -- Location details
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) NOT NULL,
    
    -- Geographic coordinates
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    
    -- Warehouse capabilities
    total_capacity_sqft DECIMAL(12, 2),
    temperature_controlled BOOLEAN DEFAULT FALSE,
    hazmat_certified BOOLEAN DEFAULT FALSE,
    
    -- Contact
    manager_name VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance', 'closed')),
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT,
    updated_by BIGINT,
    
    CONSTRAINT warehouses_company_code_unique UNIQUE (company_id, code)
);

CREATE INDEX idx_warehouses_company ON warehouses(company_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_warehouses_status ON warehouses(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_warehouses_location ON warehouses(country, state_province, city);

## III) . PRODUCT_CATEGORIES TABLE
CREATE TABLE product_categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Hierarchical structure
    parent_category_id BIGINT REFERENCES product_categories(id) ON DELETE SET NULL,
    
    category_code VARCHAR(50) UNIQUE,
    display_order INT DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_parent ON product_categories(parent_category_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_categories_active ON product_categories(is_active) WHERE is_deleted = FALSE;


## IV) PRODUCT_TABLE
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    category_id BIGINT REFERENCES product_categories(id) ON DELETE SET NULL,
    
    -- Basic information
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(100) NOT NULL,
    barcode VARCHAR(100),
    
    -- Product type
    product_type VARCHAR(20) DEFAULT 'simple' CHECK (product_type IN ('simple', 'bundle', 'variant')),
    
    -- Physical attributes
    weight DECIMAL(10, 3),
    weight_unit VARCHAR(10) DEFAULT 'kg',
    length DECIMAL(10, 2),
    width DECIMAL(10, 2),
    height DECIMAL(10, 2),
    dimension_unit VARCHAR(10) DEFAULT 'cm',
    
    -- Pricing
    cost_price DECIMAL(15, 2) CHECK (cost_price IS NULL OR cost_price >= 0),
    selling_price DECIMAL(15, 2) CHECK (selling_price IS NULL OR selling_price >= 0),
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Inventory management
    reorder_point INT DEFAULT 10,
    reorder_quantity INT DEFAULT 50,
    min_order_quantity INT DEFAULT 1,
    max_order_quantity INT,
    
    -- Storage requirements
    requires_refrigeration BOOLEAN DEFAULT FALSE,
    is_hazardous BOOLEAN DEFAULT FALSE,
    fragile BOOLEAN DEFAULT FALSE,
    
    -- Product lifecycle
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued', 'draft')),
    is_deleted BOOLEAN DEFAULT FALSE,
    discontinued_date DATE,
    
    -- Expiration tracking
    has_expiration BOOLEAN DEFAULT FALSE,
    shelf_life_days INT,
    
    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT,
    updated_by BIGINT,
    
    CONSTRAINT products_company_sku_unique UNIQUE (company_id, sku)
);

CREATE INDEX idx_products_company ON products(company_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_products_sku ON products(sku) WHERE is_deleted = FALSE;
CREATE INDEX idx_products_barcode ON products(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_type ON products(product_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_products_status ON products(status) WHERE is_deleted = FALSE;

## V) PRODUCT_BUNDLES_TABLE CREATE TABLE 
product_bundles (
    id BIGSERIAL PRIMARY KEY,
    bundle_product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    component_product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    quantity INT NOT NULL CHECK (quantity > 0),
    is_optional BOOLEAN DEFAULT FALSE,
    display_order INT DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT product_bundles_unique UNIQUE (bundle_product_id, component_product_id),
    CONSTRAINT product_bundles_no_self_reference CHECK (bundle_product_id != component_product_id)
);

CREATE INDEX idx_bundles_bundle_product ON product_bundles(bundle_product_id);
CREATE INDEX idx_bundles_component_product ON product_bundles(component_product_id);

## VI) SUPPLIERS TABLE
CREATE TABLE suppliers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    supplier_code VARCHAR(50) UNIQUE,
    email VARCHAR(255),
    phone VARCHAR(50),
    country VARCHAR(100),
    rating DECIMAL(3,2) CHECK (rating BETWEEN 0 AND 5),
    status VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended', 'blacklisted')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_suppliers_status ON suppliers(status);
CREATE INDEX idx_suppliers_country ON suppliers(country);
CREATE INDEX idx_suppliers_rating ON suppliers(rating);

## VII) COMPANY_SUPPLIERS TABLE
CREATE TABLE company_suppliers (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    supplier_id BIGINT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    relationship_start_date DATE,
    relationship_end_date DATE,
    payment_terms VARCHAR(100),
    credit_limit DECIMAL(15,2),
    total_orders INT DEFAULT 0,
    total_spent DECIMAL(15,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('active','inactive','suspended')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT company_suppliers_unique UNIQUE (company_id, supplier_id)
);

CREATE INDEX idx_company_suppliers_company ON company_suppliers(company_id);
CREATE INDEX idx_company_suppliers_supplier ON company_suppliers(supplier_id);

## VIII) CREATE TABLE 
product_suppliers (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    supplier_id BIGINT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    supplier_sku VARCHAR(100),
    supplier_product_name VARCHAR(255),
    unit_cost DECIMAL(15,2) NOT NULL CHECK (unit_cost >= 0),
    currency VARCHAR(3) DEFAULT 'USD',
    lead_time_days INT,
    moq INT DEFAULT 1,
    is_preferred_supplier BOOLEAN DEFAULT FALSE,
    priority_rank INT,
    contract_start_date DATE,
    contract_end_date DATE,
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('active','inactive','discontinued')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT product_suppliers_unique UNIQUE (product_id, supplier_id)
);

CREATE INDEX idx_product_suppliers_product ON product_suppliers(product_id);
CREATE INDEX idx_product_suppliers_supplier ON product_suppliers(supplier_id);
CREATE INDEX idx_product_suppliers_preferred ON product_suppliers(is_preferred_supplier);
IX)INVERNTORY TABLE 
CREATE TABLE inventory (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    warehouse_id BIGINT NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    
    -- Quantity tracking
    quantity_on_hand INT NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INT DEFAULT 0 CHECK (quantity_reserved >= 0),
    quantity_available INT GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,
    
    -- Location within warehouse
    zone VARCHAR(50),
    aisle VARCHAR(50),
    rack VARCHAR(50),
    shelf VARCHAR(50),
    bin VARCHAR(50),
    
    -- Batch/lot tracking
    lot_number VARCHAR(100),
    batch_number VARCHAR(100),
    
    -- Expiration
    manufacturing_date DATE,
    expiration_date DATE,
    
    -- Stock value
    unit_cost DECIMAL(15, 2),
    total_value DECIMAL(15, 2) GENERATED ALWAYS AS (quantity_on_hand * unit_cost) STORED,
    
    -- Status
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'quarantined', 'damaged', 'recalled')),
    
    -- Last count
    last_counted_at TIMESTAMP,
    last_counted_quantity INT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by BIGINT,
    
    CONSTRAINT inventory_unique UNIQUE (product_id, warehouse_id, lot_number, batch_number),
    CONSTRAINT inventory_reserved_check CHECK (quantity_reserved <= quantity_on_hand)
);

CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_inventory_warehouse ON inventory(warehouse_id);
CREATE INDEX idx_inventory_available ON inventory(warehouse_id, quantity_available) WHERE status = 'available';
CREATE INDEX idx_inventory_expiration ON inventory(expiration_date) WHERE expiration_date IS NOT NULL;
CREATE INDEX idx_inventory_low_stock ON inventory(warehouse_id, quantity_on_hand) 
    WHERE quantity_on_hand > 0 AND quantity_on_hand <= 10;

## X) Inverntory_transactions_table 

CREATE TABLE inventory_transactions (
    id BIGSERIAL PRIMARY KEY,
    inventory_id BIGINT NOT NULL REFERENCES inventory(id) ON DELETE RESTRICT,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    warehouse_id BIGINT NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN (
        'purchase_receipt','sale','transfer_out','transfer_in',
        'adjustment_increase','adjustment_decrease',
        'return_from_customer','return_to_supplier',
        'manufacturing_use','sample','write_off'
    )),
    
    quantity_change INT NOT NULL,
    quantity_before INT NOT NULL,
    quantity_after INT NOT NULL,
    
    reference_type VARCHAR(50),
    reference_id BIGINT,
    
    from_warehouse_id BIGINT REFERENCES warehouses(id) ON DELETE SET NULL,
    to_warehouse_id BIGINT REFERENCES warehouses(id) ON DELETE SET NULL,
    
    unit_cost DECIMAL(15,2),
    total_value DECIMAL(15,2),
    
    reason TEXT,
    notes TEXT,
    lot_number VARCHAR(100),
    batch_number VARCHAR(100),
    
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT NOT NULL,
    
    CONSTRAINT inventory_transactions_quantity_check CHECK (
        (transaction_type IN ('purchase_receipt','transfer_in','adjustment_increase','return_from_customer') 
         AND quantity_change > 0)
        OR
        (transaction_type IN ('sale','transfer_out','adjustment_decrease','return_to_supplier',
         'manufacturing_use','sample','write_off') 
         AND quantity_change < 0)
    )
);

CREATE INDEX idx_inv_trans_inventory ON inventory_transactions(inventory_id);
CREATE INDEX idx_inv_trans_product ON inventory_transactions(product_id, transaction_date DESC);
CREATE INDEX idx_inv_trans_warehouse ON inventory_transactions(warehouse_id, transaction_date DESC);
CREATE INDEX idx_inv_trans_date ON inventory_transactions(transaction_date DESC);
CREATE INDEX idx_inv_trans_type ON inventory_transactions(transaction_type, transaction_date DESC);
CREATE INDEX idx_inv_trans_reference ON inventory_transactions(reference_type, reference_id);

