-- =====================================================================
--  07_triggers.sql : 5 triggers (automatic actions)
--  Run once, after 01_schema.sql and 02_data.sql.
--  Expected: "Trigger created." five times.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger 1: stop an admission into a room that is not Available
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_admission_check_room
BEFORE INSERT ON admission
FOR EACH ROW
DECLARE
    v_status room.status%TYPE;
BEGIN
    IF :NEW.discharge_date IS NULL THEN
        SELECT status INTO v_status FROM room WHERE room_no = :NEW.room_no;
        IF v_status <> 'Available' THEN
            RAISE_APPLICATION_ERROR(-20101,
                'Room ' || :NEW.room_no || ' is not available (status: ' || v_status || ')');
        END IF;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;   -- a missing room is reported by the foreign key instead
END;
/

-- ---------------------------------------------------------------------
-- Trigger 2: when a patient is admitted, mark the room as Occupied
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_admission_occupy_room
AFTER INSERT ON admission
FOR EACH ROW
WHEN (NEW.discharge_date IS NULL)
BEGIN
    UPDATE room SET status = 'Occupied' WHERE room_no = :NEW.room_no;
END;
/

-- ---------------------------------------------------------------------
-- Trigger 3: when a patient is discharged, mark the room as Available
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_admission_free_room
AFTER UPDATE OF discharge_date ON admission
FOR EACH ROW
WHEN (OLD.discharge_date IS NULL AND NEW.discharge_date IS NOT NULL)
BEGIN
    UPDATE room SET status = 'Available' WHERE room_no = :NEW.room_no;
END;
/

-- ---------------------------------------------------------------------
-- Trigger 4: when a medicine is prescribed, reduce its stock.
--            Block expired medicines and quantities above the stock.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_prescribe_update_stock
BEFORE INSERT ON prescribes
FOR EACH ROW
DECLARE
    v_stock   medicine.stock_qty%TYPE;
    v_expiry  medicine.expiry_date%TYPE;
    v_name    medicine.medicine_name%TYPE;
BEGIN
    SELECT stock_qty, expiry_date, medicine_name
    INTO   v_stock, v_expiry, v_name
    FROM   medicine
    WHERE  medicine_id = :NEW.medicine_id
    FOR UPDATE;

    IF v_expiry < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20102, v_name || ' has expired and cannot be prescribed');
    ELSIF v_stock < :NEW.quantity THEN
        RAISE_APPLICATION_ERROR(-20103, 'Only ' || v_stock || ' units of ' || v_name || ' are in stock');
    END IF;

    UPDATE medicine
    SET    stock_qty = stock_qty - :NEW.quantity
    WHERE  medicine_id = :NEW.medicine_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;   -- a missing medicine is reported by the foreign key instead
END;
/

-- ---------------------------------------------------------------------
-- Trigger 5: a bill marked Paid must have a payment mode
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bill_payment_check
BEFORE INSERT OR UPDATE ON bill
FOR EACH ROW
BEGIN
    IF :NEW.payment_status = 'Paid' AND :NEW.payment_mode IS NULL THEN
        RAISE_APPLICATION_ERROR(-20104, 'A paid bill must have a payment mode');
    END IF;
END;
/
