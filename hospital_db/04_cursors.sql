-- =====================================================================
--  HOSPITAL MANAGEMENT SYSTEM  -  Oracle PL/SQL
--  04_cursors.sql : 2 cursor programs (stored procedures)
--  Run AFTER 01_schema.sql and 02_data.sql
--  Run with:  SQL> @"E:\hospital_db\04_cursors.sql"
--  Test with: SQL> @"E:\hospital_db\06_test_cursors.sql"
--
--  CURSOR 1  sp_pharmacy_alert_report
--            Explicit cursor with OPEN / FETCH / %NOTFOUND / %ROWCOUNT / CLOSE.
--            Reads every medicine that is expired, expiring soon or low in
--            stock and prints a report for the pharmacy.
--
--  CURSOR 2  sp_revise_doctor_fees
--            Parameterised cursor with FOR UPDATE and WHERE CURRENT OF.
--            Changes the consultation fee of every doctor of one department
--            by a percentage, row by row.
--
--  Error codes: -20061 department not found
--               -20062 percentage must be between -50 and 100
--  Like the other procedures, these do NOT commit.
-- =====================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ---------------------------------------------------------------------
-- CURSOR PROGRAM 1 : sp_pharmacy_alert_report
--   p_months    : medicines that expire within this many months are listed
--   p_min_stock : medicines with less stock than this are listed
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_pharmacy_alert_report (
    p_months    IN NUMBER DEFAULT 3,
    p_min_stock IN NUMBER DEFAULT 50)
IS
    CURSOR c_alert IS
        SELECT medicine_id, medicine_name, stock_qty, unit_price, expiry_date,
               CASE WHEN expiry_date < TRUNC(SYSDATE)                         THEN 'EXPIRED'
                    WHEN expiry_date <= ADD_MONTHS(TRUNC(SYSDATE), p_months)  THEN 'EXPIRING SOON'
                    ELSE 'LOW STOCK'
               END AS alert_type
        FROM   medicine
        WHERE  expiry_date <= ADD_MONTHS(TRUNC(SYSDATE), p_months)
        OR     stock_qty   <  p_min_stock
        ORDER  BY expiry_date;

    v_row           c_alert%ROWTYPE;
    v_total         NUMBER := 0;
    v_expired       NUMBER := 0;
    v_expiring      NUMBER := 0;
    v_low           NUMBER := 0;
    v_expired_value NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('PHARMACY ALERT REPORT  (expiry within ' || p_months
                         || ' months, stock below ' || p_min_stock || ')');
    DBMS_OUTPUT.PUT_LINE(RPAD('ID', 6) || RPAD('MEDICINE', 24) || RPAD('ALERT', 16)
                         || RPAD('EXPIRY DATE', 14) || LPAD('STOCK', 6));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 66, '-'));

    OPEN c_alert;
    LOOP
        FETCH c_alert INTO v_row;
        EXIT WHEN c_alert%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(RPAD(TO_CHAR(v_row.medicine_id), 6)
                             || RPAD(v_row.medicine_name, 24)
                             || RPAD(v_row.alert_type, 16)
                             || RPAD(TO_CHAR(v_row.expiry_date, 'DD-Mon-YYYY'), 14)
                             || LPAD(TO_CHAR(v_row.stock_qty), 6));

        IF v_row.alert_type = 'EXPIRED' THEN
            v_expired       := v_expired + 1;
            v_expired_value := v_expired_value + v_row.stock_qty * v_row.unit_price;
        ELSIF v_row.alert_type = 'EXPIRING SOON' THEN
            v_expiring := v_expiring + 1;
        ELSE
            v_low := v_low + 1;
        END IF;
    END LOOP;
    v_total := c_alert%ROWCOUNT;
    CLOSE c_alert;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 66, '-'));
    IF v_total = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No medicine needs attention.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Medicines listed: ' || v_total
                             || '  (expired ' || v_expired
                             || ', expiring soon ' || v_expiring
                             || ', low stock ' || v_low || ')');
        DBMS_OUTPUT.PUT_LINE('Value of expired stock to be written off: ' || v_expired_value);
    END IF;
END sp_pharmacy_alert_report;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- CURSOR PROGRAM 2 : sp_revise_doctor_fees
--   p_dept_id : department whose doctors get the new fee
--   p_percent : +10 raises the fee by 10 percent, -10 lowers it by 10 percent
--   p_updated : number of doctors changed
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_revise_doctor_fees (
    p_dept_id IN  NUMBER,
    p_percent IN  NUMBER,
    p_updated OUT NUMBER)
IS
    v_cnt     NUMBER;
    v_new_fee doctor.consultation_fee%TYPE;

    CURSOR c_doc (cp_dept NUMBER) IS
        SELECT doctor_id, name, consultation_fee
        FROM   doctor
        WHERE  dept_id = cp_dept
        ORDER  BY doctor_id
        FOR UPDATE OF consultation_fee;
BEGIN
    p_updated := 0;

    SELECT COUNT(*) INTO v_cnt FROM department WHERE dept_id = p_dept_id;
    IF v_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20061, 'Department ' || p_dept_id || ' not found');
    END IF;

    IF p_percent IS NULL OR p_percent < -50 OR p_percent > 100 THEN
        RAISE_APPLICATION_ERROR(-20062, 'Percentage must be between -50 and 100');
    END IF;

    FOR r IN c_doc(p_dept_id) LOOP
        v_new_fee := ROUND(r.consultation_fee * (1 + p_percent / 100), 2);

        UPDATE doctor
        SET    consultation_fee = v_new_fee
        WHERE  CURRENT OF c_doc;

        DBMS_OUTPUT.PUT_LINE(RPAD(r.name, 22) || ' fee ' || r.consultation_fee
                             || ' -> ' || v_new_fee);
        p_updated := p_updated + 1;
    END LOOP;

    IF p_updated = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Department ' || p_dept_id || ' has no doctors. Nothing changed.');
    ELSE
        DBMS_OUTPUT.PUT_LINE(p_updated || ' doctor(s) updated by ' || p_percent || ' percent');
    END IF;
END sp_revise_doctor_fees;
/
SHOW ERRORS

COLUMN object_name FORMAT A28
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name IN ('SP_PHARMACY_ALERT_REPORT', 'SP_REVISE_DOCTOR_FEES');
