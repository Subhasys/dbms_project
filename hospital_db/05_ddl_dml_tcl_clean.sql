SET LINESIZE 200
SET PAGESIZE 60
SET FEEDBACK ON
SET ECHO ON
SET DEFINE OFF
SET AUTOCOMMIT OFF

COLUMN name          FORMAT A22
COLUMN city          FORMAT A12
COLUMN diagnosis     FORMAT A20
COLUMN medicine_name FORMAT A22
COLUMN table_name    FORMAT A18

SPOOL 05_ddl_dml_tcl_clean_output.lst

CREATE TABLE doctor_backup AS SELECT * FROM doctor;
SELECT COUNT(*) AS rows_copied FROM doctor_backup;
ALTER TABLE doctor_backup ADD (experience_years NUMBER(2) DEFAULT 0 NOT NULL);
DESC doctor_backup
ALTER TABLE doctor_backup MODIFY (experience_years NUMBER(3));
ALTER TABLE doctor_backup RENAME COLUMN experience_years TO exp_years;
ALTER TABLE doctor_backup DROP COLUMN exp_years;
DESC doctor_backup
RENAME doctor_backup TO doctor_copy;
CREATE INDEX idx_appt_date ON appointment(appt_date);
SELECT index_name, table_name FROM user_indexes WHERE index_name = 'IDX_APPT_DATE';
TRUNCATE TABLE doctor_copy;
SELECT COUNT(*) AS rows_after_truncate FROM doctor_copy;
DROP INDEX idx_appt_date;
DROP TABLE doctor_copy PURGE;

INSERT INTO patient (patient_id, name, dob, gender, blood_group,
                     medical_history, street, city, pincode)
VALUES (seq_patient.NEXTVAL, 'Demo Patient', DATE '1990-01-15', 'Male', 'B+',
        'None', '10 Demo Street', 'Vellore', '632001');
INSERT INTO patient_phone VALUES (seq_patient.CURRVAL, '9841199999');
INSERT INTO emergency_contact VALUES (seq_patient.CURRVAL, 'Demo Relative', 'Brother', '9841188888');
INSERT INTO appointment (appointment_id, appt_date, appt_time, patient_id, doctor_id)
VALUES (seq_appointment.NEXTVAL, DATE '2026-10-30', '10:00', seq_patient.CURRVAL, 106);
INSERT INTO bill (bill_id, consultation_charge, patient_id)
VALUES (seq_bill.NEXTVAL, 500, seq_patient.CURRVAL);
SELECT patient_id, name, city FROM patient WHERE name = 'Demo Patient';
SELECT appointment_id, appt_date, appt_time, status, doctor_id
FROM   appointment WHERE patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
SELECT bill_id, bill_date, consultation_charge, payment_status
FROM   bill WHERE patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
COMMIT;

UPDATE patient
SET    city = 'Katpadi', street = '22 New Colony'
WHERE  name = 'Demo Patient';
UPDATE appointment
SET    status = 'Completed', diagnosis = 'Routine checkup'
WHERE  patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
UPDATE bill
SET    payment_mode = 'UPI', payment_status = 'Paid'
WHERE  patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
SELECT patient_id, name, city FROM patient WHERE name = 'Demo Patient';
SELECT appointment_id, status, diagnosis FROM appointment
WHERE  patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
SELECT bill_id, payment_mode, payment_status FROM bill
WHERE  patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
COMMIT;

SELECT doctor_id, name, consultation_fee FROM doctor WHERE dept_id = 1 ORDER BY doctor_id;
UPDATE doctor SET consultation_fee = consultation_fee * 1.10 WHERE dept_id = 1;
SELECT doctor_id, name, consultation_fee FROM doctor WHERE dept_id = 1 ORDER BY doctor_id;
ROLLBACK;
SELECT doctor_id, name, consultation_fee FROM doctor WHERE dept_id = 1 ORDER BY doctor_id;

INSERT INTO medicine (medicine_id, medicine_name, manufacturer, unit_price, stock_qty, expiry_date)
VALUES (seq_medicine.NEXTVAL, 'Demo Med A', 'Demo Pharma', 10, 100, DATE '2028-12-31');
SAVEPOINT sp1;
INSERT INTO medicine (medicine_id, medicine_name, manufacturer, unit_price, stock_qty, expiry_date)
VALUES (seq_medicine.NEXTVAL, 'Demo Med B', 'Demo Pharma', 20, 50, DATE '2028-12-31');
SAVEPOINT sp2;
UPDATE medicine SET stock_qty = stock_qty - 20 WHERE medicine_name = 'Paracetamol 500mg';
SELECT medicine_id, medicine_name, stock_qty FROM medicine
WHERE  medicine_name IN ('Demo Med A', 'Demo Med B', 'Paracetamol 500mg') ORDER BY medicine_id;
ROLLBACK TO sp2;
SELECT medicine_id, medicine_name, stock_qty FROM medicine
WHERE  medicine_name IN ('Demo Med A', 'Demo Med B', 'Paracetamol 500mg') ORDER BY medicine_id;
ROLLBACK TO sp1;
SELECT medicine_id, medicine_name, stock_qty FROM medicine
WHERE  medicine_name IN ('Demo Med A', 'Demo Med B', 'Paracetamol 500mg') ORDER BY medicine_id;
COMMIT;

DELETE FROM bill WHERE patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
DELETE FROM appointment WHERE patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
DELETE FROM patient WHERE patient_id = (SELECT patient_id FROM patient WHERE name = 'Demo Patient');
DELETE FROM medicine WHERE medicine_name = 'Demo Med A';
COMMIT;

SELECT 'patient'           AS table_name, COUNT(*) AS total_rows FROM patient
UNION ALL SELECT 'patient_phone',      COUNT(*) FROM patient_phone
UNION ALL SELECT 'emergency_contact',  COUNT(*) FROM emergency_contact
UNION ALL SELECT 'appointment',        COUNT(*) FROM appointment
UNION ALL SELECT 'medicine',           COUNT(*) FROM medicine
UNION ALL SELECT 'bill',               COUNT(*) FROM bill;

SPOOL OFF
