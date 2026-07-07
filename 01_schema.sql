DROP SCHEMA IF EXISTS bankdb CASCADE;
CREATE SCHEMA bankdb;
SET search_path TO bankdb;

-- ---------------------------------------------------------------------
-- 1. BRANCHES
-- ---------------------------------------------------------------------
CREATE TABLE branches (
    branch_id       SERIAL PRIMARY KEY,
    branch_name     VARCHAR(100) NOT NULL,
    city            VARCHAR(50)  NOT NULL,
    ifsc_code       CHAR(11) UNIQUE NOT NULL,
    contact_number  VARCHAR(15)
);

-- ---------------------------------------------------------------------
-- 2. EMPLOYEES
-- ---------------------------------------------------------------------
CREATE TABLE employees (
    employee_id     SERIAL PRIMARY KEY,
    branch_id       INT NOT NULL REFERENCES branches(branch_id),
    full_name       VARCHAR(100) NOT NULL,
    role            VARCHAR(30)  NOT NULL
                        CHECK (role IN ('Manager','Clerk','Loan Officer','Teller')),
    hire_date       DATE NOT NULL,
    email           VARCHAR(100) UNIQUE NOT NULL
);
CREATE INDEX idx_employees_branch ON employees(branch_id);

-- ---------------------------------------------------------------------
-- 3. CUSTOMERS
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id     SERIAL PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    dob             DATE NOT NULL,
    email           VARCHAR(100) UNIQUE NOT NULL,
    phone           VARCHAR(15)  UNIQUE NOT NULL,
    address         TEXT,
    kyc_status      VARCHAR(20) NOT NULL DEFAULT 'Pending'
                        CHECK (kyc_status IN ('Pending','Verified','Rejected')),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_customer_age CHECK (dob <= CURRENT_DATE - INTERVAL '18 years')
);
CREATE INDEX idx_customers_email ON customers(email);

-- ---------------------------------------------------------------------
-- 4. ACCOUNTS
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
    account_id      SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(customer_id),
    branch_id       INT NOT NULL REFERENCES branches(branch_id),
    opened_by       INT REFERENCES employees(employee_id),
    account_type    VARCHAR(20) NOT NULL
                        CHECK (account_type IN ('Savings','Current','Fixed Deposit')),
    balance         NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    opened_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'Active'
                        CHECK (status IN ('Active','Dormant','Closed'))
);
CREATE INDEX idx_accounts_customer ON accounts(customer_id);
CREATE INDEX idx_accounts_branch   ON accounts(branch_id);

-- ---------------------------------------------------------------------
-- 5. CARDS
-- ---------------------------------------------------------------------
CREATE TABLE cards (
    card_id             SERIAL PRIMARY KEY,
    account_id          INT NOT NULL REFERENCES accounts(account_id),
    card_type           VARCHAR(20) NOT NULL CHECK (card_type IN ('Debit','Credit')),
    card_number_masked  CHAR(19) UNIQUE NOT NULL,     -- e.g. XXXX-XXXX-XXXX-1234
    expiry_date         DATE NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'Active'
                            CHECK (status IN ('Active','Blocked','Expired'))
);
CREATE INDEX idx_cards_account ON cards(account_id);

-- ---------------------------------------------------------------------
-- 6. TRANSACTIONS  (high volume table -> BIGSERIAL, timestamp index)
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id  BIGSERIAL PRIMARY KEY,
    account_id      INT NOT NULL REFERENCES accounts(account_id),
    txn_type        VARCHAR(20) NOT NULL
                        CHECK (txn_type IN ('Deposit','Withdrawal','Transfer-In','Transfer-Out')),
    amount          NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    balance_after   NUMERIC(15,2) NOT NULL,
    txn_timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description     VARCHAR(255)
);
CREATE INDEX idx_txn_account   ON transactions(account_id);
CREATE INDEX idx_txn_timestamp ON transactions(txn_timestamp);

-- ---------------------------------------------------------------------
-- 7. BENEFICIARIES
-- ---------------------------------------------------------------------
CREATE TABLE beneficiaries (
    beneficiary_id   SERIAL PRIMARY KEY,
    customer_id      INT NOT NULL REFERENCES customers(customer_id),
    beneficiary_name VARCHAR(100) NOT NULL,
    bank_name        VARCHAR(100) NOT NULL,
    account_number   VARCHAR(30)  NOT NULL,
    ifsc_code        CHAR(11) NOT NULL,
    added_date       DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE INDEX idx_beneficiaries_customer ON beneficiaries(customer_id);

-- ---------------------------------------------------------------------
-- 8. LOANS
-- ---------------------------------------------------------------------
CREATE TABLE loans (
    loan_id           SERIAL PRIMARY KEY,
    customer_id       INT NOT NULL REFERENCES customers(customer_id),
    branch_id         INT NOT NULL REFERENCES branches(branch_id),
    approved_by       INT REFERENCES employees(employee_id),
    loan_type         VARCHAR(30) NOT NULL
                          CHECK (loan_type IN ('Home','Personal','Auto','Education')),
    principal_amount  NUMERIC(15,2) NOT NULL CHECK (principal_amount > 0),
    interest_rate     NUMERIC(5,2)  NOT NULL CHECK (interest_rate > 0),
    tenure_months     INT NOT NULL CHECK (tenure_months > 0),
    status            VARCHAR(20) NOT NULL DEFAULT 'Active'
                          CHECK (status IN ('Active','Closed','Defaulted')),
    issued_date       DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE INDEX idx_loans_customer ON loans(customer_id);
CREATE INDEX idx_loans_branch   ON loans(branch_id);

-- ---------------------------------------------------------------------
-- 9. LOAN_REPAYMENTS
-- ---------------------------------------------------------------------
CREATE TABLE loan_repayments (
    repayment_id   SERIAL PRIMARY KEY,
    loan_id        INT NOT NULL REFERENCES loans(loan_id),
    amount_paid    NUMERIC(15,2) NOT NULL CHECK (amount_paid > 0),
    payment_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    status         VARCHAR(20) NOT NULL DEFAULT 'On-time'
                       CHECK (status IN ('On-time','Late','Missed'))
);
CREATE INDEX idx_repayments_loan ON loan_repayments(loan_id);

-- ---------------------------------------------------------------------
-- 10. ACCOUNT_AUDIT_LOG  (populated by trigger, see 03_views_triggers_procedures.sql)
-- ---------------------------------------------------------------------
CREATE TABLE account_audit_log (
    audit_id     BIGSERIAL PRIMARY KEY,
    account_id   INT NOT NULL REFERENCES accounts(account_id),
    old_balance  NUMERIC(15,2) NOT NULL,
    new_balance  NUMERIC(15,2) NOT NULL,
    operation    VARCHAR(20) NOT NULL,
    changed_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_audit_account ON account_audit_log(account_id);
