# BankDB — Core Banking Database System

A compact, resume-ready DBMS project modeling a bank's core operations:
customers, branches, accounts, cards, transactions, loans, and repayments.
Built to be **fully explainable in an interview** — every design choice
below is something you should be able to defend out loud.

Engine: **PostgreSQL 14+**. Files run in order 01 → 04.

---

## 1. Files

| File | Contents |
|---|---|
| `01_schema.sql` | All 10 tables, PK/FK constraints, CHECK constraints, indexes |
| `02_sample_data.sql` | Realistic seed data (8 customers, 8 accounts, loans, transactions...) |
| `03_views_triggers_procedures.sql` | 3 views, 2 triggers, 1 stored procedure, 1 function |
| `04_analytical_queries.sql` | 9 queries showcasing windows, CTEs, subqueries, joins |

Run them locally:
```bash
psql -U postgres -f 01_schema.sql
psql -U postgres -f 02_sample_data.sql
psql -U postgres -f 03_views_triggers_procedures.sql
psql -U postgres -f 04_analytical_queries.sql
```
All four were tested end-to-end (including the trigger and procedure logic)
before being handed to you — they run cleanly with no errors.

---

## 2. Entities and relationships (ER diagram)

10 entities: **Branches, Employees, Customers, Accounts, Cards,
Transactions, Beneficiaries, Loans, Loan_Repayments, Account_Audit_Log**.

Key relationships (all 1:N):
- A **Branch** employs many **Employees**, hosts many **Accounts**, issues many **Loans**.
- A **Customer** owns many **Accounts**, takes many **Loans**, adds many **Beneficiaries**.
- An **Employee** opens **Accounts** and approves **Loans** (two separate FKs into `employees`).
- An **Account** has many **Cards**, generates many **Transactions**, and accumulates
  audit rows whenever its balance changes.
- A **Loan** has many **Loan_Repayments**.

This is intentionally a **star-ish, mostly-1:N** shape — no many-to-many
relationships, so there are no junction/bridge tables to explain. That's a
deliberate simplicity choice, not an oversight — flag it if asked.

---

## 3. Why this schema is in BCNF (not just 3NF)

**BCNF definition:** for every non-trivial functional dependency `X → Y`
in a table, `X` must be a superkey of that table.

Walk through the logic table by table:

- **branches**: `branch_id` is the PK and determines every other column.
  `ifsc_code` is also `UNIQUE`, so it's a second candidate key that
  likewise determines every other column. Both determinants (`branch_id`,
  `ifsc_code`) are superkeys → no violation.
- **employees**: same pattern — `employee_id` (PK) and `email` (UNIQUE)
  are the only two determinants, both are candidate keys.
- **customers**: `customer_id` (PK), `email` (UNIQUE), `phone` (UNIQUE) —
  three candidate keys, all superkeys, no partial or transitive dependency
  among non-key attributes (e.g. `kyc_status` doesn't determine anything
  else and isn't determined by anything except the key).
- **accounts, cards, transactions, beneficiaries, loans, loan_repayments,
  account_audit_log**: each has exactly **one** candidate key (its
  surrogate `..._id`), and every other attribute is a plain fact about
  that one entity with no attribute-to-attribute dependency. E.g. in
  `accounts`, `balance` doesn't determine `account_type`, and neither
  determines `customer_id` — the only determinant is `account_id`.

**The violation this design deliberately avoids:** if `accounts` stored
`branch_name` and `city` directly (instead of just `branch_id`), you'd
have `branch_id → branch_name, city` inside the `accounts` table — a
functional dependency whose left side (`branch_id`) is *not* a key of
`accounts`. That's a textbook BCNF violation (it's how the classic
"branch inside a loan/account table" example from every DBMS textbook
gets built) and it causes update anomalies: rename a branch and you must
find/update every account row that mentions it, and if a branch has zero
accounts temporarily, you lose the fact that the branch exists at all.
Keeping `branch_name`/`city` only in `branches` and referencing it by
`branch_id` (a foreign key) is exactly how BCNF says to fix that. This
schema does that everywhere: attribute names never get duplicated across
tables — only IDs (foreign keys) cross table boundaries.

If an interviewer pushes further: the one place with a soft, real-world
assumption is `beneficiaries` (name + bank + account number could in
theory always co-occur the same way for the same external account, which
would argue for pulling them into their own `external_accounts` table).
It's left as one table here on purpose, since these are facts about an
*external* bank we don't control or query independently — splitting it
further would add a table without adding any query or integrity benefit,
which is its own valid data-modeling judgment call worth mentioning.

---

## 4. Concepts this project lets you talk about

- **Normalization**: 3NF → BCNF reasoning above (section 3).
- **Constraints as business rules**: `CHECK` constraints for age ≥ 18,
  non-negative balances, positive transaction amounts, enum-like status
  columns — pushing validation into the DB, not just the app layer.
- **Indexing**: every FK column is indexed (Postgres doesn't do this
  automatically, unlike PKs); `transactions.txn_timestamp` is indexed
  since time-range queries on a ledger table are the most common access
  pattern.
- **Views**: `vw_customer_account_summary`, `vw_loan_status`,
  `vw_branch_deposit_book` — pre-built aggregations that hide JOIN
  complexity from consumers.
- **Triggers**: `trg_check_sufficient_balance` (BEFORE INSERT — blocks
  overdrafts at the data layer) and `trg_apply_transaction` (AFTER
  INSERT — keeps `accounts.balance` in sync with the transaction ledger
  and writes an audit trail). Together they show enforcement +
  side-effect propagation.
- **Stored procedure**: `sp_transfer_funds` — a debit and a credit
  wrapped as one atomic call. If the credit insert fails or the trigger
  rejects the debit for insufficient funds, the whole call rolls back —
  a live example of the **A**tomicity in ACID.
- **Function**: `fn_calculate_emi` — a pure calculation (reducing-balance
  EMI formula) exposed as reusable SQL, callable from any query.
- **Window functions**: running balance (`SUM() OVER`), `DENSE_RANK()`
  for a wealth leaderboard.
- **CTEs & subqueries**: `WITH` for outstanding-loan calculation,
  correlated `NOT EXISTS` for customers with no active loans.
- **Aggregation**: `GROUP BY` / `HAVING`, `FILTER`, `STRING_AGG`,
  `CASE`-based conditional aggregation for late-payment percentages.

---

## 5. One honest caveat worth knowing (don't get caught off guard)

`02_sample_data.sql` inserts accounts already at their **final** balance
and transactions with a matching pre-computed `balance_after` — it seeds
a snapshot, not a replayed history. The triggers in `03_...sql` are
written for the **live/ongoing** system: new transactions inserted after
setup will correctly update `accounts.balance` and log to
`account_audit_log`. If you re-ran the seed transactions *through* the
trigger, balances would double-count. This is a normal real-world
seeding pattern (seed = current state, triggers = future deltas) but
say so proactively if asked — it shows you understand *why* the split
exists rather than having missed it.
