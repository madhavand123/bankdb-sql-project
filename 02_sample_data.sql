SET search_path TO bankdb;

-- 1. Branches
INSERT INTO branches (branch_name, city, ifsc_code, contact_number) VALUES
('MG Road Branch',      'Bengaluru', 'BANK0001MGR', '08012345001'),
('Hitech City Branch',  'Hyderabad', 'BANK0002HTC', '04012345002'),
('Andheri Branch',      'Mumbai',    'BANK0003AND', '02212345003'),
('Connaught Place',     'New Delhi', 'BANK0004CNP', '01112345004');

-- 2. Employees
INSERT INTO employees (branch_id, full_name, role, hire_date, email) VALUES
(1, 'Ravi Kumar',     'Manager',       '2018-06-01', 'ravi.kumar@bankdb.com'),
(1, 'Sneha Iyer',     'Teller',        '2021-03-15', 'sneha.iyer@bankdb.com'),
(2, 'Arjun Rao',      'Loan Officer',  '2019-11-20', 'arjun.rao@bankdb.com'),
(2, 'Priya Menon',    'Clerk',         '2022-01-10', 'priya.menon@bankdb.com'),
(3, 'Vikram Shah',    'Manager',       '2017-08-05', 'vikram.shah@bankdb.com'),
(4, 'Ananya Gupta',   'Loan Officer',  '2020-05-18', 'ananya.gupta@bankdb.com');

-- 3. Customers
INSERT INTO customers (full_name, dob, email, phone, address, kyc_status) VALUES
('Aditya Sharma', '1998-04-12', 'aditya.sharma@mail.com', '9876500001', 'Koramangala, Bengaluru', 'Verified'),
('Meera Nair',    '1995-09-23', 'meera.nair@mail.com',    '9876500002', 'Banjara Hills, Hyderabad', 'Verified'),
('Rohan Verma',   '2000-01-30', 'rohan.verma@mail.com',   '9876500003', 'Bandra, Mumbai', 'Verified'),
('Kavya Reddy',   '1997-07-15', 'kavya.reddy@mail.com',   '9876500004', 'Jubilee Hills, Hyderabad', 'Pending'),
('Siddharth Rao', '1993-11-02', 'siddharth.rao@mail.com', '9876500005', 'Indiranagar, Bengaluru', 'Verified'),
('Ishita Bose',   '1999-03-08', 'ishita.bose@mail.com',   '9876500006', 'Salt Lake, Kolkata', 'Verified'),
('Karan Malhotra','1996-12-19', 'karan.malhotra@mail.com','9876500007', 'CP, New Delhi', 'Rejected'),
('Divya Pillai',  '2001-05-27', 'divya.pillai@mail.com',  '9876500008', 'Andheri, Mumbai', 'Verified');

-- 4. Accounts
INSERT INTO accounts (customer_id, branch_id, opened_by, account_type, balance, opened_date, status) VALUES
(1, 1, 2, 'Savings',        150000.00, '2021-01-15', 'Active'),
(1, 1, 2, 'Fixed Deposit',  500000.00, '2022-06-01', 'Active'),
(2, 2, 4, 'Savings',         85000.00, '2020-09-10', 'Active'),
(3, 3, 5, 'Current',        220000.00, '2021-11-05', 'Active'),
(4, 2, 4, 'Savings',         12000.00, '2023-02-20', 'Active'),
(5, 1, 2, 'Savings',        340000.00, '2019-04-18', 'Active'),
(6, 1, 2, 'Current',         67000.00, '2022-08-30', 'Dormant'),
(8, 3, 5, 'Savings',         95000.00, '2023-05-12', 'Active');

-- 5. Cards
INSERT INTO cards (account_id, card_type, card_number_masked, expiry_date, status) VALUES
(1, 'Debit',  'XXXX-XXXX-XXXX-4521', '2028-01-31', 'Active'),
(3, 'Debit',  'XXXX-XXXX-XXXX-7789', '2027-06-30', 'Active'),
(4, 'Credit', 'XXXX-XXXX-XXXX-3345', '2026-12-31', 'Active'),
(6, 'Debit',  'XXXX-XXXX-XXXX-9012', '2027-09-30', 'Active'),
(6, 'Credit', 'XXXX-XXXX-XXXX-6650', '2026-03-31', 'Blocked');

-- 6. Transactions (balance_after must match running balance)
INSERT INTO transactions (account_id, txn_type, amount, balance_after, txn_timestamp, description) VALUES
(1, 'Deposit',    50000.00, 150000.00, '2024-01-05 10:00:00', 'Salary credit'),
(1, 'Withdrawal',  5000.00, 145000.00, '2024-01-10 14:20:00', 'ATM withdrawal'),
(1, 'Deposit',    10000.00, 155000.00, '2024-02-01 09:15:00', 'Salary credit'),
(3, 'Deposit',    20000.00,  85000.00, '2024-01-08 11:00:00', 'Salary credit'),
(3, 'Withdrawal',  3000.00,  82000.00, '2024-01-15 16:40:00', 'Online purchase'),
(4, 'Deposit',   100000.00, 220000.00, '2024-01-12 12:30:00', 'Business receipt'),
(6, 'Deposit',    15000.00, 340000.00, '2024-02-10 08:45:00', 'Salary credit'),
(6, 'Withdrawal',  2000.00, 338000.00, '2024-02-14 19:10:00', 'Utility payment'),
(8, 'Deposit',     5000.00,  95000.00, '2024-03-01 13:00:00', 'Cash deposit');

-- 7. Beneficiaries
INSERT INTO beneficiaries (customer_id, beneficiary_name, bank_name, account_number, ifsc_code, added_date) VALUES
(1, 'Rahul Sharma',  'HDFC Bank',    '50100123456789', 'HDFC0001234', '2023-01-10'),
(1, 'Landlord - Gowda','SBI',        '30201987654321', 'SBIN0005678', '2023-03-22'),
(3, 'Vendor Supplies','ICICI Bank',  '60200456789123', 'ICIC0009876', '2023-06-15'),
(5, 'Amit Traders',   'Axis Bank',   '91100234567890', 'UTIB0001122', '2023-02-05');

-- 8. Loans
INSERT INTO loans (customer_id, branch_id, approved_by, loan_type, principal_amount, interest_rate, tenure_months, status, issued_date) VALUES
(2, 2, 3, 'Home',      3500000.00, 8.50, 240, 'Active', '2022-04-01'),
(3, 3, 5, 'Auto',       800000.00, 9.25,  60, 'Active', '2023-01-15'),
(5, 1, 3, 'Personal',   300000.00, 12.00, 36, 'Active', '2023-07-10'),
(6, 1, 3, 'Education', 1200000.00, 7.50,  84, 'Defaulted', '2021-09-01');

-- 9. Loan Repayments
INSERT INTO loan_repayments (loan_id, amount_paid, payment_date, status) VALUES
(1, 30500.00, '2024-01-05', 'On-time'),
(1, 30500.00, '2024-02-05', 'On-time'),
(1, 30500.00, '2024-03-07', 'Late'),
(2, 16800.00, '2024-01-15', 'On-time'),
(2, 16800.00, '2024-02-15', 'On-time'),
(3, 10000.00, '2024-01-10', 'On-time'),
(3, 10000.00, '2024-02-12', 'Late'),
(4, 18000.00, '2023-10-01', 'On-time'),
(4, 18000.00, '2023-11-05', 'Late');
