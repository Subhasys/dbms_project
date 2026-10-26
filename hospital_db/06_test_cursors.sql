-- =====================================================================
--  06_test_cursors.sql
--  Tests the 2 cursor programs of 04_cursors.sql
--  Run with:  SQL> @"E:\hospital_db\06_test_cursors.sql"
--  Output is saved to E:\hospital_db\06_test_cursors_output.lst
--
--  Ends with ROLLBACK, so your sample data is not changed.
--  Lines that say ORA-200xx are EXPECTED (they prove the checks work).
-- =====================================================================

SET LINESIZE 200
SET PAGESIZE 60
SET FEEDBACK ON
SET ECHO ON
SET DEFINE OFF
SET SERVEROUTPUT ON
SET AUTOCOMMIT OFF

COLUMN name FORMAT A22

SPOOL E:\hospital_db\06_test_cursors_output.lst

VARIABLE v_cnt NUMBER

-- =====================================================================
-- CURSOR 1 : sp_pharmacy_alert_report
-- =====================================================================
PROMPT
PROMPT ===== 1.1 Default report : expiry within 3 months, stock below 50 =====
PROMPT Expected (run on 25-Oct-2026): Azithromycin EXPIRED, ORS Sachet and
PROMPT Salbutamol EXPIRING SOON, Ibuprofen LOW STOCK. The list depends on today's date.
EXEC sp_pharmacy_alert_report;

PROMPT ===== 1.2 Wider report : expiry within 6 months, stock below 100 =====
EXEC sp_pharmacy_alert_report(6, 100);

PROMPT ===== 1.3 Very strict report : nothing expires within 0 months, stock below 10 =====
EXEC sp_pharmacy_alert_report(0, 10);

-- =====================================================================
-- CURSOR 2 : sp_revise_doctor_fees
-- =====================================================================
PROMPT
PROMPT ===== 2.1 Pediatrics fees BEFORE (500 and 500) =====
SELECT doctor_id, name, consultation_fee FROM doctor WHERE dept_id = 4 ORDER BY doctor_id;

PROMPT ===== 2.2 Raise Pediatrics fees by 10 percent =====
EXEC sp_revise_doctor_fees(4, 10, :v_cnt);
PRINT v_cnt

PROMPT ===== 2.3 Pediatrics fees AFTER (550 and 550) =====
SELECT doctor_id, name, consultation_fee FROM doctor WHERE dept_id = 4 ORDER BY doctor_id;

PROMPT ===== 2.4 Lower Cardiology fees by 20 percent (800 -> 640, 750 -> 600) =====
EXEC sp_revise_doctor_fees(1, -20, :v_cnt);
PRINT v_cnt

PROMPT ===== 2.5 Department with no doctors (Emergency, 10) : message and count 0 =====
EXEC sp_revise_doctor_fees(10, 10, :v_cnt);
PRINT v_cnt

PROMPT ===== 2.6 Unknown department : ORA-20061 expected =====
EXEC sp_revise_doctor_fees(99, 10, :v_cnt);

PROMPT ===== 2.7 Percentage too large : ORA-20062 expected =====
EXEC sp_revise_doctor_fees(4, 500, :v_cnt);

PROMPT ===== 2.8 ROLLBACK : all fee changes are undone =====
ROLLBACK;
SELECT doctor_id, name, consultation_fee FROM doctor WHERE dept_id IN (1, 4) ORDER BY doctor_id;
PROMPT Expected: 101=800, 102=750, 105=500, 106=500

SPOOL OFF
