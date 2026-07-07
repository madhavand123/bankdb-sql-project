SET search_path TO bankdb;

-- =====================================================================
-- VIEWS
-- =====================================================================

-- View 1: Customer-level summary across all their accounts.
-- Talking point: views encapsulate a repeated JOIN + aggregation so
-- application code / BI tools can query it like a simple table.
CREATE OR REPLACE VIEW vw_customer_account_summary AS
SELECT
    c.customer_id,
    c.full_name,
    c.kyc_status,
    COUNT(a.account_id)               AS total_accounts,
    COALESCE(SUM(a.balance), 0)       AS total_balance,
    COALESCE(MAX(a.balance), 0)       AS largest_account_balance
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.kyc_status;

-- View 2: Loan health - principal, total repaid, and outstanding balance.
CREATE OR REPLACE VIEW vw_loan_status AS
SELECT
    l.loan_id,
    c.full_name              AS customer_name,
    l.loan_type,
    l.principal_amount,
    l.interest_rate,
    l.status,
    COALESCE(SUM(r.amount_paid), 0)                       AS total_repaid,
    l.principal_amount - COALESCE(SUM(r.amount_paid), 0)  AS outstanding_balance,
    COUNT(r.repayment_id) FILTER (WHERE r.status = 'Late') AS late_payment_count
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
LEFT JOIN loan_repayments r ON r.loan_id = l.loan_id
GROUP BY l.loan_id, c.full_name, l.loan_type, l.principal_amount, l.interest_rate, l.status;

-- View 3: Branch-wise deposit book (sum of active account balances per branch).
CREATE OR REPLACE VIEW vw_branch_deposit_book AS
SELECT
    b.branch_id,
    b.branch_name,
    b.city,
    COUNT(a.account_id)         AS active_accounts,
    COALESCE(SUM(a.balance), 0) AS total_deposits
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id AND a.status = 'Active'
GROUP BY b.branch_id, b.branch_name, b.city;


-- =====================================================================
-- TRIGGERS
-- =====================================================================

-- Trigger 1: Prevent a withdrawal / transfer-out from overdrawing an account.
-- Talking point: enforcing this in a trigger means NO code path (app bug,
-- ad-hoc script, another service) can ever bypass the rule - it's guaranteed
-- at the data layer.
CREATE OR REPLACE FUNCTION fn_check_sufficient_balance()
RETURNS TRIGGER AS $$
DECLARE
    current_balance NUMERIC(15,2);
BEGIN
    IF NEW.txn_type IN ('Withdrawal', 'Transfer-Out') THEN
        SELECT balance INTO current_balance FROM accounts WHERE account_id = NEW.account_id;
        IF current_balance < NEW.amount THEN
            RAISE EXCEPTION 'Insufficient balance: account % has %, tried to withdraw %',
                NEW.account_id, current_balance, NEW.amount;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_sufficient_balance
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_sufficient_balance();

-- Trigger 2: After a transaction is inserted, update the account's balance
-- and write an audit row. Keeps accounts.balance always in sync with the
-- transaction ledger without relying on the application to do two writes.
CREATE OR REPLACE FUNCTION fn_apply_transaction()
RETURNS TRIGGER AS $$
DECLARE
    old_bal NUMERIC(15,2);
    new_bal NUMERIC(15,2);
BEGIN
    SELECT balance INTO old_bal FROM accounts WHERE account_id = NEW.account_id;

    IF NEW.txn_type IN ('Deposit', 'Transfer-In') THEN
        new_bal := old_bal + NEW.amount;
    ELSE
        new_bal := old_bal - NEW.amount;
    END IF;

    UPDATE accounts SET balance = new_bal WHERE account_id = NEW.account_id;

    INSERT INTO account_audit_log (account_id, old_balance, new_balance, operation)
    VALUES (NEW.account_id, old_bal, new_bal, NEW.txn_type);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apply_transaction
    AFTER INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION fn_apply_transaction();



-- =====================================================================
-- STORED PROCEDURE: fund transfer between two accounts
-- =====================================================================

CREATE OR REPLACE PROCEDURE sp_transfer_funds(
    p_from_account INT,
    p_to_account   INT,
    p_amount       NUMERIC(15,2),
    p_description  VARCHAR(255) DEFAULT 'Fund transfer'
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_from_account = p_to_account THEN
        RAISE EXCEPTION 'Source and destination accounts must differ';
    END IF;

    -- Debit leg (trigger validates balance & updates accounts.balance)
    INSERT INTO transactions (account_id, txn_type, amount, balance_after, description)
    VALUES (
        p_from_account, 'Transfer-Out', p_amount,
        (SELECT balance FROM accounts WHERE account_id = p_from_account) - p_amount,
        p_description
    );

    -- Credit leg
    INSERT INTO transactions (account_id, txn_type, amount, balance_after, description)
    VALUES (
        p_to_account, 'Transfer-In', p_amount,
        (SELECT balance FROM accounts WHERE account_id = p_to_account) + p_amount,
        p_description
    );
END;
$$;

-- Example call (run as its own statement - Postgres auto-commits it,
-- and if either insert above fails/raises, both are rolled back together):
-- CALL sp_transfer_funds(1, 3, 5000.00, 'Rent payment');


-- =====================================================================
-- FUNCTION: EMI calculator (standard reducing-balance formula)
-- =====================================================================
-- EMI = P * r * (1+r)^n / ((1+r)^n - 1), where r = monthly interest rate
CREATE OR REPLACE FUNCTION fn_calculate_emi(
    p_principal NUMERIC,
    p_annual_rate NUMERIC,
    p_tenure_months INT
)
RETURNS NUMERIC(15,2) AS $$
DECLARE
    r NUMERIC := p_annual_rate / 12 / 100;
    emi NUMERIC;
BEGIN
    IF r = 0 THEN
        RETURN ROUND(p_principal / p_tenure_months, 2);
    END IF;
    emi := p_principal * r * POWER(1 + r, p_tenure_months) / (POWER(1 + r, p_tenure_months) - 1);
    RETURN ROUND(emi, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

