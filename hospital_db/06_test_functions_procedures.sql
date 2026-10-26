-- =====================================================================
--  06_test_functions_procedures.sql
--  Tests the 3 functions and 5 procedures of 04_functions_procedures.sql
--  Run with:  SQL> @"E:\hospital_db\06_test_functions_procedures.sql"
--  Output is saved to E:\hospital_db\06_test_functions_procedures_output.lst
--
--  The script ends with ROLLBACK, so your sample data is not changed.
--  Lines that say "ORA-200xx" are EXPECTED: they prove that the
--  business rules reject wrong input.
-- =====================================================================

SET LINESIZE 200
SET PAGESIZE 60
SET FEEDBACK ON
SET ECHO ON
SET DEFINE OFF
SET SERVEROUTPUT ON
SET AUTOCOMMIT OFF

COLUMN patient_name FORMAT A20
COLUMN table_name   FORMAT A18

SPOOL E:\hospital_db\06_test_functions_procedures_output.lst

VARIABLE v_appt1 NUMBER
VARIABLE v_appt2 NUMBER
VARIABLE v_adm   NUMBER
VARIABLE v_bill  NUMBER

-- =====================================================================
-- PART A : FUNCTIONS
-- =====================================================================
PROMPT
PROMPT ===== A1 fn_calc_room_charge : same values as the stored room charges =====
PROMPT Expected: 5001=20000, 5002=7500, 5003=3000, 5004=4000, 5005=7500, 5006=5000, 5007=12500, 5008=3000
SELECT admission_id, patient_id, fn_calc_room_charge(admission_id) AS room_charge
FROM   admission
WHERE  discharge_date IS NOT NULL
ORDER  BY admission_id;

PROMPT ===== A2 fn_calc_room_charge on an open admission (still staying) =====
SELECT admission_id, patient_id, fn_calc_room_charge(admission_id) AS charge_so_far
FROM   admission
WHERE  discharge_date IS NULL
ORDER  BY admission_id;

PROMPT ===== A3 fn_medicine_charge : Expected 3001=240, 3002=59.5, 3005=269, 3010=0 =====
SELECT appointment_id, fn_medicine_charge(appointment_id) AS medicine_charge
FROM   appointment
WHERE  appointment_id IN (3001, 3002, 3005, 3010)
ORDER  BY appointment_id;

PROMPT ===== A4 fn_is_slot_free : Expected N (taken), Y (free), N (cancelled slot still held) =====
SELECT fn_is_slot_free(101, DATE '2026-08-01', '10:00') AS taken_slot,
       fn_is_slot_free(101, DATE '2026-11-02', '10:00') AS free_slot,
       fn_is_slot_free(111, DATE '2026-10-17', '10:30') AS cancelled_slot
FROM   dual;

-- =====================================================================
-- PART B : sp_book_appointment and sp_cancel_appointment
-- =====================================================================
PROMPT
PROMPT ===== B1 Book an appointment (Divya Lakshmi with Dr. Anjali Nair) =====
EXEC sp_book_appointment(1004, 106, DATE '2026-10-31', '11:00', :v_appt1);
PRINT v_appt1

PROMPT ===== B2 Same doctor, same slot again : ORA-20014 expected =====
EXEC sp_book_appointment(1005, 106, DATE '2026-10-31', '11:00', :v_appt2);

PROMPT ===== B3 Date in the past : ORA-20013 expected =====
EXEC sp_book_appointment(1004, 106, DATE '2026-01-01', '11:00', :v_appt2);

PROMPT ===== B4 Wrong time format : ORA-20015 expected =====
EXEC sp_book_appointment(1004, 106, DATE '2026-11-03', '25:99', :v_appt2);

PROMPT ===== B5 Unknown patient / unknown doctor : ORA-20011 and ORA-20012 expected =====
EXEC sp_book_appointment(9999, 106, DATE '2026-11-03', '10:00', :v_appt2);
EXEC sp_book_appointment(1004, 999, DATE '2026-11-03', '10:00', :v_appt2);

PROMPT ===== B6 Cancel the booking =====
EXEC sp_cancel_appointment(:v_appt1);
SELECT appointment_id, status FROM appointment WHERE appointment_id = :v_appt1;

PROMPT ===== B7 Cancel again : ORA-20022 expected =====
EXEC sp_cancel_appointment(:v_appt1);

PROMPT ===== B8 Cancel a Completed appointment (3001) : ORA-20022 expected =====
EXEC sp_cancel_appointment(3001);

PROMPT ===== B9 Book a second appointment that will be used below =====
EXEC sp_book_appointment(1004, 106, DATE '2026-11-02', '09:00', :v_appt2);
PRINT v_appt2

-- =====================================================================
-- PART C : sp_prescribe_medicine
-- =====================================================================
PROMPT
PROMPT ===== C1 Stock of Paracetamol BEFORE prescribing (500) =====
SELECT medicine_id, medicine_name, stock_qty FROM medicine WHERE medicine_id = 201;

PROMPT ===== C2 Prescribe Paracetamol, quantity 6 =====
EXEC sp_prescribe_medicine(:v_appt2, 201, '500mg twice daily', 3, 6);

PROMPT ===== C3 Stock AFTER prescribing (494) and the prescription row =====
SELECT medicine_id, medicine_name, stock_qty FROM medicine WHERE medicine_id = 201;
SELECT appointment_id, medicine_id, dosage, duration_days, quantity
FROM   prescribes WHERE appointment_id = :v_appt2;

PROMPT ===== C4 Same medicine again : ORA-20036 expected =====
EXEC sp_prescribe_medicine(:v_appt2, 201, '500mg once daily', 2, 2);

PROMPT ===== C5 Expired medicine (Azithromycin) : ORA-20034 expected =====
EXEC sp_prescribe_medicine(:v_appt2, 212, '500mg once daily', 3, 3);

PROMPT ===== C6 Not enough stock (Ibuprofen has 45) : ORA-20035 expected =====
EXEC sp_prescribe_medicine(:v_appt2, 209, '400mg twice daily', 5, 100);

PROMPT ===== C7 Cancelled appointment : ORA-20032 expected =====
EXEC sp_prescribe_medicine(:v_appt1, 206, '10mg at night', 5, 5);

PROMPT ===== C8 Unknown appointment / unknown medicine : ORA-20031 and ORA-20033 expected =====
EXEC sp_prescribe_medicine(9999, 201, '500mg', 1, 1);
EXEC sp_prescribe_medicine(:v_appt2, 999, '500mg', 1, 1);

-- =====================================================================
-- PART D : sp_admit_patient
-- =====================================================================
PROMPT
PROMPT ===== D1 Admit Divya Lakshmi to general room 101 =====
EXEC sp_admit_patient(1004, 101, 'Observation after consultation', :v_adm);
PRINT v_adm
SELECT admission_id, patient_id, room_no, discharge_date, reason
FROM   admission WHERE admission_id = :v_adm;

PROMPT ===== D2 Admit the same patient again : ORA-20044 expected =====
EXEC sp_admit_patient(1004, 102, 'Second admission', :v_adm);

PROMPT ===== D3 Occupied room 105 : ORA-20043 expected =====
EXEC sp_admit_patient(1006, 105, 'Fever', :v_adm);

PROMPT ===== D4 Unknown room / unknown patient : ORA-20042 and ORA-20041 expected =====
EXEC sp_admit_patient(1006, 999, 'Fever', :v_adm);
EXEC sp_admit_patient(9999, 102, 'Fever', :v_adm);

-- =====================================================================
-- PART E : sp_discharge_and_bill
-- =====================================================================
PROMPT
PROMPT ===== E1 Invalid payment mode : ORA-20055 expected =====
EXEC sp_discharge_and_bill(5001, NULL, 'Bitcoin', :v_bill);

PROMPT ===== E2 Admission 5001 is already discharged : ORA-20052 expected =====
EXEC sp_discharge_and_bill(5001, NULL, 'Cash', :v_bill);

PROMPT ===== E3 Appointment of another patient (3001 is Arjun Nair's) : ORA-20054 expected =====
EXEC sp_discharge_and_bill(5011, 3001, 'Cash', :v_bill);

PROMPT ===== E4 Unknown admission / unknown appointment : ORA-20051 and ORA-20053 expected =====
EXEC sp_discharge_and_bill(9999, NULL, 'Cash', :v_bill);
EXEC sp_discharge_and_bill(5011, 9999, 'Cash', :v_bill);

PROMPT ===== E5 Discharge Divya Lakshmi and create the bill paid in Cash =====
PROMPT Expected: consultation 500 + medicine 15 + room 1000 = 1515
EXEC sp_discharge_and_bill(:v_adm, :v_appt2, 'Cash', :v_bill);
PRINT v_bill
SELECT bill_id, consultation_charge, medicine_charge, room_charge, total_amount,
       payment_mode, payment_status
FROM   v_bill_total WHERE bill_id = :v_bill;
SELECT admission_id, admit_date, discharge_date FROM admission WHERE admission_id = :v_adm;

PROMPT ===== E6 Discharge the same admission again : ORA-20052 expected =====
EXEC sp_discharge_and_bill(:v_adm, :v_appt2, 'Cash', :v_bill);

-- =====================================================================
-- PART F : undo everything and check that the data is unchanged
-- =====================================================================
PROMPT
PROMPT ===== F1 ROLLBACK : none of the test data is kept =====
ROLLBACK;

SELECT 'appointment' AS table_name, COUNT(*) AS total_rows FROM appointment
UNION ALL SELECT 'prescribes', COUNT(*) FROM prescribes
UNION ALL SELECT 'admission',  COUNT(*) FROM admission
UNION ALL SELECT 'bill',       COUNT(*) FROM bill;

PROMPT Expected: appointment 16, prescribes 19, admission 11, bill 12
SELECT medicine_id, medicine_name, stock_qty FROM medicine WHERE medicine_id = 201;
PROMPT Expected stock of Paracetamol: 500

SPOOL OFF
