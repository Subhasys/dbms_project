-- =====================================================================
--  HOSPITAL MANAGEMENT SYSTEM  -  Oracle PL/SQL
--  04_functions_procedures.sql : 3 functions + 5 procedures
--  Run AFTER 01_schema.sql and 02_data.sql
--  Run with:  SQL> @"E:\hospital_db\04_functions_procedures.sql"
--  Test with: SQL> @"E:\hospital_db\06_test_functions_procedures.sql"
--
--  FUNCTIONS
--    fn_calc_room_charge(admission_id)       stay days x room charge per day
--    fn_medicine_charge(appointment_id)      SUM(quantity x unit_price)
--    fn_is_slot_free(doctor, date, time)     'Y' if the doctor slot is free
--
--  PROCEDURES  (module: what the front-end calls)
--    sp_book_appointment      Appointment module : book a slot
--    sp_cancel_appointment    Appointment module : cancel a booking
--    sp_prescribe_medicine    Pharmacy module    : prescribe (stock reduced by trigger)
--    sp_admit_patient         Admission module   : admit to a room
--    sp_discharge_and_bill    Billing module     : discharge + create bill
--
--  NOTES
--    * Procedures do NOT commit. The caller decides (SQL*Plus: COMMIT;
--      JDBC: connection.commit() or leave auto-commit on).
--    * Every business-rule failure raises an error in the range
--      -20001 to -20055 (see list below), so the front-end can show
--      a clear message from SQLERRM.
--
--  ERROR CODES
--    -20001 admission not found
--    -20011 patient not found          -20012 doctor not found
--    -20013 date in the past           -20014 doctor slot already taken
--    -20015 time not in HH24:MI format
--    -20021 appointment not found      -20022 not in Scheduled status
--    -20031 appointment not found      -20032 appointment is cancelled
--    -20033 medicine not found         -20034 medicine expired
--    -20035 not enough stock           -20036 already prescribed
--    -20041 patient not found          -20042 room not found
--    -20043 room not available         -20044 patient already admitted
--    -20051 admission not found        -20052 already discharged
--    -20053 appointment not found      -20054 appointment is another patient's
--    -20055 invalid payment mode
-- =====================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ---------------------------------------------------------------------
-- FUNCTION 1 : fn_calc_room_charge
--   Room charge for one admission = stay_days x charge_per_day.
--   For an admission that is still open, the stay runs until today.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_room_charge (p_admission_id IN NUMBER)
RETURN NUMBER
IS
    v_charge NUMBER;
BEGIN
    SELECT s.stay_days * r.charge_per_day
    INTO   v_charge
    FROM   admission a
           JOIN v_admission_stay s ON s.admission_id = a.admission_id
           JOIN room r             ON r.room_no      = a.room_no
    WHERE  a.admission_id = p_admission_id;
    RETURN v_charge;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Admission ' || p_admission_id || ' not found');
END fn_calc_room_charge;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- FUNCTION 2 : fn_medicine_charge
--   Total cost of the medicines prescribed in one appointment.
--   Returns 0 when nothing was prescribed.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_medicine_charge (p_appointment_id IN NUMBER)
RETURN NUMBER
IS
    v_total NUMBER;
BEGIN
    SELECT NVL(SUM(pr.quantity * m.unit_price), 0)
    INTO   v_total
    FROM   prescribes pr
           JOIN medicine m ON m.medicine_id = pr.medicine_id
    WHERE  pr.appointment_id = p_appointment_id;
    RETURN v_total;
END fn_medicine_charge;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- FUNCTION 3 : fn_is_slot_free
--   'Y' if the doctor has no appointment at that date and time, else 'N'.
--   A cancelled appointment still holds its slot, because the table has
--   UNIQUE (doctor_id, appt_date, appt_time).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_is_slot_free (
    p_doctor_id IN NUMBER,
    p_date      IN DATE,
    p_time      IN VARCHAR2)
RETURN VARCHAR2
IS
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO   v_cnt
    FROM   appointment
    WHERE  doctor_id = p_doctor_id
    AND    TRUNC(appt_date) = TRUNC(p_date)
    AND    appt_time = p_time;
    IF v_cnt = 0 THEN
        RETURN 'Y';
    ELSE
        RETURN 'N';
    END IF;
END fn_is_slot_free;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- PROCEDURE 1 : sp_book_appointment
--   Books a Scheduled appointment and returns the new appointment id.
--   Checks: patient and doctor exist, date not in the past, time format
--   HH24:MI, doctor slot free (uses fn_is_slot_free).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_book_appointment (
    p_patient_id     IN  NUMBER,
    p_doctor_id      IN  NUMBER,
    p_date           IN  DATE,
    p_time           IN  VARCHAR2,
    p_appointment_id OUT NUMBER)
IS
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM patient WHERE patient_id = p_patient_id;
    IF v_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Patient ' || p_patient_id || ' not found');
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM doctor WHERE doctor_id = p_doctor_id;
    IF v_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Doctor ' || p_doctor_id || ' not found');
    END IF;

    IF TRUNC(p_date) < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20013, 'Appointment date cannot be in the past');
    END IF;

    IF NOT REGEXP_LIKE(p_time, '^([01][0-9]|2[0-3]):[0-5][0-9]$') THEN
        RAISE_APPLICATION_ERROR(-20015, 'Time must be in HH24:MI format, for example 10:30');
    END IF;

    IF fn_is_slot_free(p_doctor_id, p_date, p_time) = 'N' THEN
        RAISE_APPLICATION_ERROR(-20014, 'Doctor ' || p_doctor_id || ' already has an appointment on '
                                        || TO_CHAR(p_date, 'DD-Mon-YYYY') || ' at ' || p_time);
    END IF;

    SELECT seq_appointment.NEXTVAL INTO p_appointment_id FROM dual;

    INSERT INTO appointment (appointment_id, appt_date, appt_time, status, patient_id, doctor_id)
    VALUES (p_appointment_id, TRUNC(p_date), p_time, 'Scheduled', p_patient_id, p_doctor_id);

    DBMS_OUTPUT.PUT_LINE('Appointment ' || p_appointment_id || ' booked for '
                         || TO_CHAR(p_date, 'DD-Mon-YYYY') || ' at ' || p_time);
END sp_book_appointment;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- PROCEDURE 2 : sp_cancel_appointment
--   Only a Scheduled appointment can be cancelled.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cancel_appointment (p_appointment_id IN NUMBER)
IS
    v_status appointment.status%TYPE;
BEGIN
    BEGIN
        SELECT status
        INTO   v_status
        FROM   appointment
        WHERE  appointment_id = p_appointment_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20021, 'Appointment ' || p_appointment_id || ' not found');
    END;

    IF v_status <> 'Scheduled' THEN
        RAISE_APPLICATION_ERROR(-20022, 'Only Scheduled appointments can be cancelled (current status: '
                                        || v_status || ')');
    END IF;

    UPDATE appointment
    SET    status = 'Cancelled'
    WHERE  appointment_id = p_appointment_id;

    DBMS_OUTPUT.PUT_LINE('Appointment ' || p_appointment_id || ' cancelled');
END sp_cancel_appointment;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- PROCEDURE 3 : sp_prescribe_medicine
--   Adds a medicine to an appointment. The pharmacy stock is reduced by
--   the trigger trg_prescribe_update_stock (07_triggers.sql).
--   Checks: appointment exists and is not cancelled, medicine exists,
--   not expired, enough stock, not already prescribed in this visit.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_prescribe_medicine (
    p_appointment_id IN NUMBER,
    p_medicine_id    IN NUMBER,
    p_dosage         IN VARCHAR2,
    p_duration_days  IN NUMBER,
    p_quantity       IN NUMBER)
IS
    v_status appointment.status%TYPE;
    v_name   medicine.medicine_name%TYPE;
    v_stock  medicine.stock_qty%TYPE;
    v_expiry medicine.expiry_date%TYPE;
BEGIN
    BEGIN
        SELECT status
        INTO   v_status
        FROM   appointment
        WHERE  appointment_id = p_appointment_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20031, 'Appointment ' || p_appointment_id || ' not found');
    END;

    IF v_status = 'Cancelled' THEN
        RAISE_APPLICATION_ERROR(-20032, 'Cannot prescribe for a cancelled appointment');
    END IF;

    BEGIN
        SELECT medicine_name, stock_qty, expiry_date
        INTO   v_name, v_stock, v_expiry
        FROM   medicine
        WHERE  medicine_id = p_medicine_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20033, 'Medicine ' || p_medicine_id || ' not found');
    END;

    IF v_expiry < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20034, v_name || ' expired on ' || TO_CHAR(v_expiry, 'DD-Mon-YYYY'));
    END IF;

    IF v_stock < p_quantity THEN
        RAISE_APPLICATION_ERROR(-20035, 'Not enough stock of ' || v_name
                                        || ' (available ' || v_stock || ', needed ' || p_quantity || ')');
    END IF;

    BEGIN
        INSERT INTO prescribes (appointment_id, medicine_id, dosage, duration_days, quantity)
        VALUES (p_appointment_id, p_medicine_id, p_dosage, p_duration_days, p_quantity);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20036, v_name || ' is already prescribed in appointment ' || p_appointment_id);
    END;

    -- The stock is reduced by the trigger trg_prescribe_update_stock
    -- (07_triggers.sql) when the row above is inserted, so it must NOT
    -- be reduced here as well.

    DBMS_OUTPUT.PUT_LINE(v_name || ' prescribed (qty ' || p_quantity || '). Stock left: '
                         || (v_stock - p_quantity));
END sp_prescribe_medicine;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- PROCEDURE 4 : sp_admit_patient
--   Admits a patient to a room and returns the new admission id.
--   Checks: patient exists, room exists and is 'Available',
--   patient is not already admitted.
--   (The room status itself is changed by the trigger of Step 7.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_admit_patient (
    p_patient_id   IN  NUMBER,
    p_room_no      IN  NUMBER,
    p_reason       IN  VARCHAR2,
    p_admission_id OUT NUMBER)
IS
    v_cnt         NUMBER;
    v_room_status room.status%TYPE;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM patient WHERE patient_id = p_patient_id;
    IF v_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20041, 'Patient ' || p_patient_id || ' not found');
    END IF;

    BEGIN
        SELECT status INTO v_room_status FROM room WHERE room_no = p_room_no;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20042, 'Room ' || p_room_no || ' not found');
    END;

    IF v_room_status <> 'Available' THEN
        RAISE_APPLICATION_ERROR(-20043, 'Room ' || p_room_no || ' is not available (status: '
                                        || v_room_status || ')');
    END IF;

    SELECT COUNT(*)
    INTO   v_cnt
    FROM   admission
    WHERE  patient_id = p_patient_id
    AND    discharge_date IS NULL;
    IF v_cnt > 0 THEN
        RAISE_APPLICATION_ERROR(-20044, 'Patient ' || p_patient_id || ' is already admitted');
    END IF;

    SELECT seq_admission.NEXTVAL INTO p_admission_id FROM dual;

    INSERT INTO admission (admission_id, admit_date, discharge_date, reason, patient_id, room_no)
    VALUES (p_admission_id, SYSDATE, NULL, p_reason, p_patient_id, p_room_no);

    DBMS_OUTPUT.PUT_LINE('Patient ' || p_patient_id || ' admitted to room ' || p_room_no
                         || ' (admission ' || p_admission_id || ')');
END sp_admit_patient;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- PROCEDURE 5 : sp_discharge_and_bill
--   Discharges the patient (discharge_date = now) and creates the bill:
--     consultation_charge = fee of the doctor of the given appointment
--     medicine_charge     = fn_medicine_charge(appointment)
--     room_charge         = fn_calc_room_charge(admission)
--   p_appointment_id is optional (NULL = no consultation / medicine).
--   p_payment_mode   is optional (NULL = bill stays 'Pending',
--                     otherwise the bill is 'Paid').
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_discharge_and_bill (
    p_admission_id   IN  NUMBER,
    p_appointment_id IN  NUMBER   DEFAULT NULL,
    p_payment_mode   IN  VARCHAR2 DEFAULT NULL,
    p_bill_id        OUT NUMBER)
IS
    v_patient_id   admission.patient_id%TYPE;
    v_discharge    admission.discharge_date%TYPE;
    v_appt_patient appointment.patient_id%TYPE;
    v_consult      NUMBER := 0;
    v_medicine     NUMBER := 0;
    v_room         NUMBER := 0;
    v_pay_status   bill.payment_status%TYPE;
BEGIN
    IF p_payment_mode IS NOT NULL
       AND p_payment_mode NOT IN ('Cash', 'Card', 'UPI', 'Insurance') THEN
        RAISE_APPLICATION_ERROR(-20055, 'Payment mode must be Cash, Card, UPI or Insurance');
    END IF;

    BEGIN
        SELECT patient_id, discharge_date
        INTO   v_patient_id, v_discharge
        FROM   admission
        WHERE  admission_id = p_admission_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20051, 'Admission ' || p_admission_id || ' not found');
    END;

    IF v_discharge IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20052, 'Admission ' || p_admission_id || ' is already discharged');
    END IF;

    IF p_appointment_id IS NOT NULL THEN
        BEGIN
            SELECT a.patient_id, d.consultation_fee
            INTO   v_appt_patient, v_consult
            FROM   appointment a
                   JOIN doctor d ON d.doctor_id = a.doctor_id
            WHERE  a.appointment_id = p_appointment_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20053, 'Appointment ' || p_appointment_id || ' not found');
        END;
        IF v_appt_patient <> v_patient_id THEN
            RAISE_APPLICATION_ERROR(-20054, 'Appointment ' || p_appointment_id
                                            || ' belongs to a different patient');
        END IF;
        v_medicine := fn_medicine_charge(p_appointment_id);
    END IF;

    UPDATE admission
    SET    discharge_date = SYSDATE
    WHERE  admission_id = p_admission_id;

    v_room := fn_calc_room_charge(p_admission_id);

    IF p_payment_mode IS NULL THEN
        v_pay_status := 'Pending';
    ELSE
        v_pay_status := 'Paid';
    END IF;

    SELECT seq_bill.NEXTVAL INTO p_bill_id FROM dual;

    INSERT INTO bill (bill_id, bill_date, consultation_charge, medicine_charge, room_charge,
                      payment_mode, payment_status, patient_id)
    VALUES (p_bill_id, SYSDATE, v_consult, v_medicine, v_room,
            p_payment_mode, v_pay_status, v_patient_id);

    DBMS_OUTPUT.PUT_LINE('Bill ' || p_bill_id || ' created: consultation ' || v_consult
                         || ' + medicine ' || v_medicine || ' + room ' || v_room
                         || ' = ' || (v_consult + v_medicine + v_room) || ' (' || v_pay_status || ')');
END sp_discharge_and_bill;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- Check: every object must be VALID
-- ---------------------------------------------------------------------
COLUMN object_name FORMAT A28
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_type IN ('FUNCTION', 'PROCEDURE')
ORDER  BY object_type, object_name;
