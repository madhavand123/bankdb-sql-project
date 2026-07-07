-- =====================================================================
-- BankDB: Analytical / Showcase Queries
-- File: 04_analytical_queries.sql
-- These are the queries worth walking through in an interview - each
-- demonstrates a distinct SQL concept.
-- =====================================================================
SET search_path TO bankdb;

-- ---------------------------------------------------------------------
-- 1. WINDOW FUNCTION: running balance per account over time
-- ---------------------------------------------------------------------
SELECT
    account_id,
    txn_timestamp,
    txn_type,
    amount,
    SUM(CASE WHEN txn_type IN ('Deposit','Transfer-In') THEN amount ELSE -amount END)
        OVER (PARTITION BY account_id ORDER BY txn_timestamp
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_net_change
FROM transactions
ORDER BY account_id, txn_timestamp;

-- ---------------------------------------------------------------------
-- 2. WINDOW FUNCTION: rank customers by total balance (dense_rank)
-- ---------------------------------------------------------------------
SELECT
    c.customer_id,
    c.full_name,
    SUM(a.balance) AS total_balance,
    DENSE_RANK() OVER (ORDER BY SUM(a.balance) DESC) AS wealth_rank
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name
ORDER BY wealth_rank;

-- ---------------------------------------------------------------------
-- 3. CTE + JOIN: top borrowers with their outstanding loan balance
-- ---------------------------------------------------------------------
WITH loan_totals AS (
    SELECT
        loan_id,
        customer_id,
        principal_amount,
        principal_amount - COALESCE((
            SELECT SUM(amount_paid) FROM loan_repayments r WHERE r.loan_id = l.loan_id
        ), 0) AS outstanding
    FROM loans l
)
SELECT
    c.full_name,
    lt.outstanding
FROM loan_totals lt
JOIN customers c ON c.customer_id = lt.customer_id
WHERE lt.outstanding > 0
ORDER BY lt.outstanding DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- 4. CORRELATED SUBQUERY: customers with no active loans
-- ---------------------------------------------------------------------
SELECT c.customer_id, c.full_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM loans l
    WHERE l.customer_id = c.customer_id AND l.status = 'Active'
);

-- ---------------------------------------------------------------------
-- 5. MULTI-TABLE JOIN: full customer 360 view (accounts + cards + loans)
-- ---------------------------------------------------------------------
SELECT
    c.full_name,
    a.account_type,
    a.balance,
    b.branch_name,
    STRING_AGG(DISTINCT ca.card_type, ', ')  AS card_types,
    COUNT(DISTINCT l.loan_id)                AS active_loans
FROM customers c
JOIN accounts a  ON a.customer_id = c.customer_id
JOIN branches b  ON b.branch_id = a.branch_id
LEFT JOIN cards ca ON ca.account_id = a.account_id
LEFT JOIN loans l  ON l.customer_id = c.customer_id AND l.status = 'Active'
GROUP BY c.full_name, a.account_type, a.balance, b.branch_name
ORDER BY c.full_name;

-- ---------------------------------------------------------------------
-- 6. AGGREGATE + HAVING: branches whose total deposits exceed 3,00,000
-- ---------------------------------------------------------------------
SELECT
    b.branch_name,
    SUM(a.balance) AS total_deposits
FROM branches b
JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_name
HAVING SUM(a.balance) > 300000
ORDER BY total_deposits DESC;

-- ---------------------------------------------------------------------
-- 7. CASE + aggregate: loan repayment discipline per customer
-- ---------------------------------------------------------------------
SELECT
    c.full_name,
    COUNT(r.repayment_id) AS total_payments,
    SUM(CASE WHEN r.status = 'Late' THEN 1 ELSE 0 END)   AS late_payments,
    ROUND(100.0 * SUM(CASE WHEN r.status = 'Late' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(r.repayment_id), 0), 1) AS late_pct
FROM customers c
JOIN loans l ON l.customer_id = c.customer_id
JOIN loan_repayments r ON r.loan_id = l.loan_id
GROUP BY c.full_name
ORDER BY late_pct DESC;

-- ---------------------------------------------------------------------
-- 8. SELF-CONTAINED EXAMPLE: use the EMI function against a what-if loan
-- ---------------------------------------------------------------------
SELECT fn_calculate_emi(500000, 8.75, 120) AS monthly_emi;

-- ---------------------------------------------------------------------
-- 9. Using the views (simple SELECTs once the view exists)
-- ---------------------------------------------------------------------
SELECT * FROM vw_customer_account_summary ORDER BY total_balance DESC;
SELECT * FROM vw_loan_status WHERE outstanding_balance > 0;
SELECT * FROM vw_branch_deposit_book ORDER BY total_deposits DESC;
