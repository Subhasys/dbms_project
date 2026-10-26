-- =====================================================================
--  08_test_triggers.sql : tests all 5 triggers
--  Everything done here is UNDONE by the ROLLBACK at the end,
--  so your data is left exactly as it was.
-- =====================================================================
COMMIT;
SET SERVEROUTPUT ON
SET LINESIZE 150

PROMPT
PROMPT ===== Triggers that exist =====
SELECT trigger_name, triggering_event, table_name, status
FROM   user_triggers
ORDER  BY trigger_name;

PROMPT
PROMPT ===== Room status BEFORE the tests =====
SELECT status, COUNT(*) AS no_of_rooms FROM room GROUP BY status ORDER BY status;

PROMPT
PROMPT ===== Tests 1 to 4: admission and room triggers =====
DECLARE
    v_room     room.room_no%TYPE;
    v_patient  patient.patient_id%TYPE;
    v_status   room.status%TYPE;
BEGIN
    SELECT MIN(room_no) INTO v_room FROM room WHERE status = 'Available';
    SELECT MIN(patient_id) INTO v_patient FROM patient
    WHERE  patient_id NOT IN (SELECT patient_id FROM admission WHERE discharge_date IS NULL);
    DBMS_OUTPUT.PUT_LINE('Using room ' || v_room || ' and patient ' || v_patient);

    SELECT status INTO v_status FROM room WHERE room_no = v_room;
    DBMS_OUTPUT.PUT_LINE('1. Room status before admission  : ' || v_status);

    INSERT INTO admission (admission_id, admit_date, discharge_date, reason, patient_id, room_no)
    VALUES (seq_admission.NEXTVAL, SYSDATE, NULL, 'Trigger test admission', v_patient, v_room);

    SELECT status INTO v_status FROM room WHERE room_no = v_room;
    DBMS_OUTPUT.PUT_LINE('2. Room status after admission   : ' || v_status || '  (trigger 2 set it)');

    BEGIN
        INSERT INTO admission (admission_id, admit_date, discharge_date, reason, patient_id, room_no)
        VALUES (seq_admission.NEXTVAL, SYSDATE, NULL, 'Should be blocked', v_patient, v_room);
        DBMS_OUTPUT.PUT_LINE('ERROR: second admission to the same room was allowed');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('3. Second admission, same room    : ' || SQLERRM);
    END;

    UPDATE admission SET discharge_date = SYSDATE
    WHERE  reason = 'Trigger test admission' AND patient_id = v_patient AND discharge_date IS NULL;

    SELECT status INTO v_status FROM room WHERE room_no = v_room;
    DBMS_OUTPUT.PUT_LINE('4. Room status after discharge   : ' || v_status || '  (trigger 3 set it)');
END;
/

PROMPT
PROMPT ===== Tests 5 to 7: prescription trigger =====
DECLARE
    v_appt    appointment.appointment_id%TYPE;
    v_before  medicine.stock_qty%TYPE;
    v_after   medicine.stock_qty%TYPE;
BEGIN
    SELECT MIN(a.appointment_id) INTO v_appt
    FROM   appointment a
    WHERE  NOT EXISTS (SELECT 1 FROM prescribes p
                       WHERE  p.appointment_id = a.appointment_id AND p.medicine_id = 201);

    SELECT stock_qty INTO v_before FROM medicine WHERE medicine_id = 201;
    INSERT INTO prescribes VALUES (v_appt, 201, '500mg twice daily', 3, 6);
    SELECT stock_qty INTO v_after FROM medicine WHERE medicine_id = 201;
    DBMS_OUTPUT.PUT_LINE('5. Paracetamol stock: before ' || v_before || ', after prescribing 6 = ' || v_after);

    BEGIN
        INSERT INTO prescribes VALUES (v_appt, 212, '500mg once daily', 3, 3);
        DBMS_OUTPUT.PUT_LINE('ERROR: expired medicine was allowed');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('6. Expired medicine               : ' || SQLERRM);
    END;

    BEGIN
        INSERT INTO prescribes VALUES (v_appt, 209, '400mg twice daily', 10, 1000);
        DBMS_OUTPUT.PUT_LINE('ERROR: quantity above stock was allowed');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('7. Quantity above stock           : ' || SQLERRM);
    END;
END;
/

PROMPT
PROMPT ===== Tests 8 and 9: bill trigger =====
BEGIN
    BEGIN
        INSERT INTO bill (bill_id, bill_date, consultation_charge, medicine_charge, room_charge,
                          payment_mode, payment_status, patient_id)
        VALUES (seq_bill.NEXTVAL, SYSDATE, 100, 0, 0, NULL, 'Paid', 1001);
        DBMS_OUTPUT.PUT_LINE('ERROR: paid bill without a mode was allowed');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('8. Paid bill, no payment mode     : ' || SQLERRM);
    END;

    INSERT INTO bill (bill_id, bill_date, consultation_charge, medicine_charge, room_charge,
                      payment_mode, payment_status, patient_id)
    VALUES (seq_bill.NEXTVAL, SYSDATE, 100, 0, 0, 'Cash', 'Paid', 1001);
    DBMS_OUTPUT.PUT_LINE('9. Paid bill with mode Cash       : accepted');
END;
/

PROMPT
PROMPT ===== Undo everything done by this test =====
ROLLBACK;

PROMPT
PROMPT ===== Room status AFTER the rollback (same as before the tests) =====
SELECT status, COUNT(*) AS no_of_rooms FROM room GROUP BY status ORDER BY status;
SELECT medicine_id, medicine_name, stock_qty FROM medicine WHERE medicine_id = 201;
