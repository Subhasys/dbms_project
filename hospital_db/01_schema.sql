-- =====================================================================
--  HOSPITAL MANAGEMENT SYSTEM  -  Oracle SQL
--  01_schema.sql : tables, constraints, sequences and views
--  Run order: 00_cleanup (optional) -> 01 -> 02 -> 04 -> 03 / 05 / 06
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. DEPARTMENT
-- ---------------------------------------------------------------------
CREATE TABLE department (
    dept_id     NUMBER(3)      CONSTRAINT pk_department PRIMARY KEY,
    dept_name   VARCHAR2(50)   NOT NULL CONSTRAINT uq_dept_name UNIQUE,
    location    VARCHAR2(50)   NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. DOCTOR   (DEPARTMENT 1 : N DOCTOR  -> dept_id FK)
-- ---------------------------------------------------------------------
CREATE TABLE doctor (
    doctor_id         NUMBER(4)      CONSTRAINT pk_doctor PRIMARY KEY,
    name              VARCHAR2(60)   NOT NULL,
    specialization    VARCHAR2(50)   NOT NULL,
    phone             VARCHAR2(15)   NOT NULL,
    email             VARCHAR2(80)   NOT NULL CONSTRAINT uq_doctor_email UNIQUE,
    consultation_fee  NUMBER(8,2)    DEFAULT 500 NOT NULL
                                     CONSTRAINT ck_doctor_fee CHECK (consultation_fee >= 0),
    dept_id           NUMBER(3)      NOT NULL
                                     CONSTRAINT fk_doctor_dept REFERENCES department(dept_id)
);

-- ---------------------------------------------------------------------
-- 3. PATIENT  (composite address stored as street / city / pincode;
--              age is derived -> see view v_patient_age)
-- ---------------------------------------------------------------------
CREATE TABLE patient (
    patient_id       NUMBER(5)      CONSTRAINT pk_patient PRIMARY KEY,
    name             VARCHAR2(60)   NOT NULL,
    dob              DATE           NOT NULL,
    gender           VARCHAR2(10)   NOT NULL
                                    CONSTRAINT ck_patient_gender CHECK (gender IN ('Male','Female','Other')),
    blood_group      VARCHAR2(3)    CONSTRAINT ck_patient_bg
                                    CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    medical_history  VARCHAR2(200)  DEFAULT 'None',
    street           VARCHAR2(80),
    city             VARCHAR2(40)   NOT NULL,
    pincode          VARCHAR2(6)    CONSTRAINT ck_patient_pin CHECK (REGEXP_LIKE(pincode, '^[0-9]{6}$'))
);

-- ---------------------------------------------------------------------
-- 4. PATIENT_PHONE  (multivalued attribute phone_no)
-- ---------------------------------------------------------------------
CREATE TABLE patient_phone (
    patient_id  NUMBER(5)     NOT NULL
                              CONSTRAINT fk_pphone_patient REFERENCES patient(patient_id) ON DELETE CASCADE,
    phone_no    VARCHAR2(15)  NOT NULL,
    CONSTRAINT pk_patient_phone PRIMARY KEY (patient_id, phone_no)
);

-- ---------------------------------------------------------------------
-- 5. EMERGENCY_CONTACT  (weak entity: key = patient_id + contact_name)
-- ---------------------------------------------------------------------
CREATE TABLE emergency_contact (
    patient_id    NUMBER(5)     NOT NULL
                                CONSTRAINT fk_econtact_patient REFERENCES patient(patient_id) ON DELETE CASCADE,
    contact_name  VARCHAR2(60)  NOT NULL,
    relationship  VARCHAR2(30)  NOT NULL,
    phone_no      VARCHAR2(15)  NOT NULL,
    CONSTRAINT pk_emergency_contact PRIMARY KEY (patient_id, contact_name)
);

-- ---------------------------------------------------------------------
-- 6. APPOINTMENT  (DOCTOR 1:N, PATIENT 1:N)
--    A doctor cannot have two appointments at the same date and time.
-- ---------------------------------------------------------------------
CREATE TABLE appointment (
    appointment_id  NUMBER(5)      CONSTRAINT pk_appointment PRIMARY KEY,
    appt_date       DATE           NOT NULL,
    appt_time       VARCHAR2(5)    NOT NULL
                                   CONSTRAINT ck_appt_time CHECK (REGEXP_LIKE(appt_time, '^([01][0-9]|2[0-3]):[0-5][0-9]$')),
    status          VARCHAR2(10)   DEFAULT 'Scheduled' NOT NULL
                                   CONSTRAINT ck_appt_status CHECK (status IN ('Scheduled','Completed','Cancelled')),
    diagnosis       VARCHAR2(200),
    patient_id      NUMBER(5)      NOT NULL
                                   CONSTRAINT fk_appt_patient REFERENCES patient(patient_id),
    doctor_id       NUMBER(4)      NOT NULL
                                   CONSTRAINT fk_appt_doctor REFERENCES doctor(doctor_id),
    CONSTRAINT uq_doctor_slot UNIQUE (doctor_id, appt_date, appt_time)
);

-- ---------------------------------------------------------------------
-- 7. MEDICINE
-- ---------------------------------------------------------------------
CREATE TABLE medicine (
    medicine_id    NUMBER(4)      CONSTRAINT pk_medicine PRIMARY KEY,
    medicine_name  VARCHAR2(60)   NOT NULL,
    manufacturer   VARCHAR2(50)   NOT NULL,
    unit_price     NUMBER(8,2)    NOT NULL CONSTRAINT ck_med_price CHECK (unit_price > 0),
    stock_qty      NUMBER(6)      DEFAULT 0 NOT NULL CONSTRAINT ck_med_stock CHECK (stock_qty >= 0),
    expiry_date    DATE           NOT NULL
);

-- ---------------------------------------------------------------------
-- 8. PRESCRIBES  (M:N between APPOINTMENT and MEDICINE)
-- ---------------------------------------------------------------------
CREATE TABLE prescribes (
    appointment_id  NUMBER(5)     NOT NULL
                                  CONSTRAINT fk_presc_appt REFERENCES appointment(appointment_id) ON DELETE CASCADE,
    medicine_id     NUMBER(4)     NOT NULL
                                  CONSTRAINT fk_presc_med REFERENCES medicine(medicine_id),
    dosage          VARCHAR2(60)  NOT NULL,
    duration_days   NUMBER(3)     NOT NULL CONSTRAINT ck_presc_days CHECK (duration_days > 0),
    quantity        NUMBER(4)     NOT NULL CONSTRAINT ck_presc_qty CHECK (quantity > 0),
    CONSTRAINT pk_prescribes PRIMARY KEY (appointment_id, medicine_id)
);

-- ---------------------------------------------------------------------
-- 9. ROOM
-- ---------------------------------------------------------------------
CREATE TABLE room (
    room_no          NUMBER(4)     CONSTRAINT pk_room PRIMARY KEY,
    room_type        VARCHAR2(20)  NOT NULL
                                   CONSTRAINT ck_room_type CHECK (room_type IN ('General','Semi-Private','Private','ICU')),
    charge_per_day   NUMBER(8,2)   NOT NULL CONSTRAINT ck_room_charge CHECK (charge_per_day > 0),
    status           VARCHAR2(12)  DEFAULT 'Available' NOT NULL
                                   CONSTRAINT ck_room_status CHECK (status IN ('Available','Occupied','Maintenance'))
);

-- ---------------------------------------------------------------------
-- 10. ADMISSION  (PATIENT 1:N, ROOM 1:N; stay_days is derived -> view)
-- ---------------------------------------------------------------------
CREATE TABLE admission (
    admission_id    NUMBER(5)      CONSTRAINT pk_admission PRIMARY KEY,
    admit_date      DATE           NOT NULL,
    discharge_date  DATE,
    reason          VARCHAR2(100)  NOT NULL,
    patient_id      NUMBER(5)      NOT NULL
                                   CONSTRAINT fk_adm_patient REFERENCES patient(patient_id),
    room_no         NUMBER(4)      NOT NULL
                                   CONSTRAINT fk_adm_room REFERENCES room(room_no),
    CONSTRAINT ck_adm_dates CHECK (discharge_date IS NULL OR discharge_date >= admit_date)
);

-- ---------------------------------------------------------------------
-- 11. BILL  (PATIENT 1:N; total_amount is derived -> view)
-- ---------------------------------------------------------------------
CREATE TABLE bill (
    bill_id              NUMBER(5)     CONSTRAINT pk_bill PRIMARY KEY,
    bill_date            DATE          DEFAULT SYSDATE NOT NULL,
    consultation_charge  NUMBER(10,2)  DEFAULT 0 NOT NULL CONSTRAINT ck_bill_cons CHECK (consultation_charge >= 0),
    medicine_charge      NUMBER(10,2)  DEFAULT 0 NOT NULL CONSTRAINT ck_bill_med CHECK (medicine_charge >= 0),
    room_charge          NUMBER(10,2)  DEFAULT 0 NOT NULL CONSTRAINT ck_bill_room CHECK (room_charge >= 0),
    payment_mode         VARCHAR2(10)  CONSTRAINT ck_bill_mode CHECK (payment_mode IN ('Cash','Card','UPI','Insurance')),
    payment_status       VARCHAR2(10)  DEFAULT 'Pending' NOT NULL
                                       CONSTRAINT ck_bill_status CHECK (payment_status IN ('Paid','Pending')),
    patient_id           NUMBER(5)     NOT NULL
                                       CONSTRAINT fk_bill_patient REFERENCES patient(patient_id)
);

-- ---------------------------------------------------------------------
-- Sequences for new rows created from the front-end / procedures
-- (they start after the ids used in 02_data.sql)
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_department   START WITH 11   INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_doctor       START WITH 113  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_patient      START WITH 1013 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_appointment  START WITH 3017 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_medicine     START WITH 213  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_admission    START WITH 5012 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_bill         START WITH 7013 INCREMENT BY 1 NOCACHE;

-- ---------------------------------------------------------------------
-- Views for the DERIVED attributes (not stored in the tables)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_patient_age AS
SELECT patient_id, name, dob,
       TRUNC(MONTHS_BETWEEN(SYSDATE, dob) / 12) AS age
FROM   patient;

CREATE OR REPLACE VIEW v_admission_stay AS
SELECT admission_id, patient_id, room_no, admit_date, discharge_date,
       GREATEST(1, TRUNC(NVL(discharge_date, SYSDATE)) - TRUNC(admit_date)) AS stay_days
FROM   admission;

CREATE OR REPLACE VIEW v_bill_total AS
SELECT bill_id, bill_date, patient_id,
       consultation_charge, medicine_charge, room_charge,
       consultation_charge + medicine_charge + room_charge AS total_amount,
       payment_mode, payment_status
FROM   bill;
