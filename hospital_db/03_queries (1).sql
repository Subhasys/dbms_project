-- =====================================================================
--  HOSPITAL MANAGEMENT SYSTEM  -  Oracle SQL*Plus
--  03_queries.sql : 24 SELECT queries
--  Run AFTER 01_schema.sql and 02_data.sql
--  Run with:  SQL> @03_queries.sql
--  Output is saved to 03_queries_output.lst (use it in the report)
--
--  QUERY INDEX
--  No  Module            Type
--  --  ----------------  -------------------------------------------
--  1   Patient           Simple (WHERE, ORDER BY)
--  2   Patient           Simple on a view (derived attribute age)
--  3   Appointment       Join (3 tables)
--  4   Department        Outer join (LEFT JOIN)
--  5   Prescription      Join (4 tables) + arithmetic
--  6   Admission         Join (4 tables, uses view)
--  7   Appointment       Aggregate: GROUP BY + HAVING
--  8   Department        Aggregate: outer join + COUNT/AVG/MAX
--  9   Prescription      Aggregate: SUM over a join
--  10  Pharmacy          Aggregate: COUNT/SUM, ORDER BY
--  11  Patient           Aggregate: HAVING COUNT > 1
--  12  Room              Aggregate: SUM(CASE ...)
--  13  Billing           Aggregate on a view
--  14  Billing           Aggregate with NVL
--  15  Doctor            Nested: scalar subquery (AVG)
--  16  Admission         Nested: IN subquery with join
--  17  Doctor            Nested: NOT EXISTS
--  18  Billing           Nested: subquery on a view
--  19  Appointment       Nested: correlated scalar subquery
--  20  Patient           Set operator: MINUS
--  21  Doctor            SQL functions: string
--  22  Pharmacy          SQL functions: date + CASE
--  23  Appointment       SQL functions: TO_CHAR + GROUP BY
--  24  Billing           Analytic function: RANK()
-- =====================================================================

SET LINESIZE 200
SET PAGESIZE 60
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF

COLUMN name            FORMAT A22
COLUMN patient_name    FORMAT A22
COLUMN doctor_name     FORMAT A22
COLUMN dept_name       FORMAT A18
COLUMN location        FORMAT A26
COLUMN specialization  FORMAT A20
COLUMN medicine_name   FORMAT A20
COLUMN diagnosis       FORMAT A28
COLUMN city            FORMAT A12
COLUMN room_type       FORMAT A12
COLUMN username        FORMAT A16
COLUMN domain          FORMAT A18
COLUMN masked_phone    FORMAT A12
COLUMN dosage          FORMAT A24
COLUMN shelf_status    FORMAT A14

SPOOL 03_queries_output.lst

-- ---------------------------------------------------------------------
-- Q1. SIMPLE: patients living in Vellore, sorted by name
-- ---------------------------------------------------------------------
SELECT patient_id, name, gender, blood_group, city
FROM   patient
WHERE  city = 'Vellore'
ORDER  BY name;

-- ---------------------------------------------------------------------
-- Q2. SIMPLE (view): patients aged 50 or above (age is a derived value)
-- ---------------------------------------------------------------------
SELECT patient_id, name, dob, age
FROM   v_patient_age
WHERE  age >= 50
ORDER  BY age DESC;

-- ---------------------------------------------------------------------
-- Q3. JOIN: appointment details with patient and doctor names
-- ---------------------------------------------------------------------
SELECT a.appointment_id, a.appt_date, a.appt_time,
       p.name AS patient_name, d.name AS doctor_name, a.status
FROM   appointment a
       JOIN patient p ON p.patient_id = a.patient_id
       JOIN doctor  d ON d.doctor_id  = a.doctor_id
ORDER  BY a.appt_date, a.appt_time;

-- ---------------------------------------------------------------------
-- Q4. OUTER JOIN: every department with its doctors
--     (Emergency has no doctor, so it still appears with NULLs)
-- ---------------------------------------------------------------------
SELECT dep.dept_name, dep.location, doc.name AS doctor_name, doc.specialization
FROM   department dep
       LEFT JOIN doctor doc ON doc.dept_id = dep.dept_id
ORDER  BY dep.dept_id, doc.name;

-- ---------------------------------------------------------------------
-- Q5. JOIN (4 tables): prescription lines with the cost of each line
-- ---------------------------------------------------------------------
SELECT pr.appointment_id, p.name AS patient_name, m.medicine_name,
       pr.dosage, pr.quantity, m.unit_price,
       pr.quantity * m.unit_price AS line_cost
FROM   prescribes pr
       JOIN medicine    m ON m.medicine_id    = pr.medicine_id
       JOIN appointment a ON a.appointment_id = pr.appointment_id
       JOIN patient     p ON p.patient_id     = a.patient_id
ORDER  BY pr.appointment_id, m.medicine_name;

-- ---------------------------------------------------------------------
-- Q6. JOIN (view): patients currently admitted (not yet discharged)
--     with days stayed so far and the room charge accumulated
-- ---------------------------------------------------------------------
SELECT a.admission_id, p.name AS patient_name, r.room_no, r.room_type,
       a.admit_date, s.stay_days,
       s.stay_days * r.charge_per_day AS charge_so_far
FROM   admission a
       JOIN patient          p ON p.patient_id   = a.patient_id
       JOIN room             r ON r.room_no      = a.room_no
       JOIN v_admission_stay s ON s.admission_id = a.admission_id
WHERE  a.discharge_date IS NULL
ORDER  BY a.admit_date;

-- ---------------------------------------------------------------------
-- Q7. GROUP BY + HAVING: doctors who have two or more appointments
-- ---------------------------------------------------------------------
SELECT d.doctor_id, d.name AS doctor_name, d.specialization,
       COUNT(*) AS total_appointments
FROM   appointment a
       JOIN doctor d ON d.doctor_id = a.doctor_id
GROUP  BY d.doctor_id, d.name, d.specialization
HAVING COUNT(*) >= 2
ORDER  BY total_appointments DESC, d.name;

-- ---------------------------------------------------------------------
-- Q8. AGGREGATE + OUTER JOIN: doctors and fees per department
-- ---------------------------------------------------------------------
SELECT dep.dept_name,
       COUNT(doc.doctor_id)                       AS doctors,
       NVL(ROUND(AVG(doc.consultation_fee), 2), 0) AS avg_fee,
       NVL(MAX(doc.consultation_fee), 0)          AS max_fee
FROM   department dep
       LEFT JOIN doctor doc ON doc.dept_id = dep.dept_id
GROUP  BY dep.dept_name
ORDER  BY doctors DESC, dep.dept_name;

-- ---------------------------------------------------------------------
-- Q9. AGGREGATE: medicine charge per appointment = SUM(quantity x price)
--     (matches bill.medicine_charge in the sample data)
-- ---------------------------------------------------------------------
SELECT pr.appointment_id, p.name AS patient_name,
       SUM(pr.quantity * m.unit_price) AS medicine_total
FROM   prescribes pr
       JOIN medicine    m ON m.medicine_id    = pr.medicine_id
       JOIN appointment a ON a.appointment_id = pr.appointment_id
       JOIN patient     p ON p.patient_id     = a.patient_id
GROUP  BY pr.appointment_id, p.name
ORDER  BY pr.appointment_id;

-- ---------------------------------------------------------------------
-- Q10. AGGREGATE: most prescribed medicines
-- ---------------------------------------------------------------------
SELECT m.medicine_name,
       COUNT(*)           AS times_prescribed,
       SUM(pr.quantity)   AS total_quantity
FROM   prescribes pr
       JOIN medicine m ON m.medicine_id = pr.medicine_id
GROUP  BY m.medicine_name
ORDER  BY times_prescribed DESC, total_quantity DESC;

-- ---------------------------------------------------------------------
-- Q11. HAVING: patients who registered more than one phone number
--      (multivalued attribute)
-- ---------------------------------------------------------------------
SELECT p.patient_id, p.name AS patient_name, COUNT(*) AS phone_count
FROM   patient p
       JOIN patient_phone ph ON ph.patient_id = p.patient_id
GROUP  BY p.patient_id, p.name
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- Q12. AGGREGATE with CASE: room availability by room type
-- ---------------------------------------------------------------------
SELECT room_type,
       MIN(charge_per_day)                                  AS daily_charge,
       COUNT(*)                                             AS total_rooms,
       SUM(CASE WHEN status = 'Available'   THEN 1 ELSE 0 END) AS available,
       SUM(CASE WHEN status = 'Occupied'    THEN 1 ELSE 0 END) AS occupied,
       SUM(CASE WHEN status = 'Maintenance' THEN 1 ELSE 0 END) AS maintenance
FROM   room
GROUP  BY room_type
ORDER  BY daily_charge;

-- ---------------------------------------------------------------------
-- Q13. AGGREGATE (view): bills and amount by payment status
-- ---------------------------------------------------------------------
SELECT payment_status,
       COUNT(*)          AS no_of_bills,
       SUM(total_amount) AS total_amount
FROM   v_bill_total
GROUP  BY payment_status;

-- ---------------------------------------------------------------------
-- Q14. AGGREGATE + NVL: revenue by payment mode
--      (bills with no mode yet are shown as 'Not yet paid')
-- ---------------------------------------------------------------------
SELECT NVL(payment_mode, 'Not yet paid') AS payment_mode,
       COUNT(*)                          AS no_of_bills,
       SUM(total_amount)                 AS total_amount
FROM   v_bill_total
GROUP  BY NVL(payment_mode, 'Not yet paid')
ORDER  BY total_amount DESC;

-- ---------------------------------------------------------------------
-- Q15. NESTED (scalar subquery): doctors charging more than the average fee
-- ---------------------------------------------------------------------
SELECT doctor_id, name AS doctor_name, specialization, consultation_fee
FROM   doctor
WHERE  consultation_fee > (SELECT AVG(consultation_fee) FROM doctor)
ORDER  BY consultation_fee DESC;

-- ---------------------------------------------------------------------
-- Q16. NESTED (IN): patients who have ever been admitted to an ICU room
-- ---------------------------------------------------------------------
SELECT patient_id, name AS patient_name, blood_group, medical_history
FROM   patient
WHERE  patient_id IN (SELECT a.patient_id
                      FROM   admission a
                             JOIN room r ON r.room_no = a.room_no
                      WHERE  r.room_type = 'ICU');

-- ---------------------------------------------------------------------
-- Q17. NESTED (NOT EXISTS): doctors who have no appointment yet
-- ---------------------------------------------------------------------
SELECT d.doctor_id, d.name AS doctor_name, d.specialization
FROM   doctor d
WHERE  NOT EXISTS (SELECT 1
                   FROM   appointment a
                   WHERE  a.doctor_id = d.doctor_id);

-- ---------------------------------------------------------------------
-- Q18. NESTED (view): bills above the average bill amount
-- ---------------------------------------------------------------------
SELECT b.bill_id, p.name AS patient_name, b.total_amount, b.payment_status
FROM   v_bill_total b
       JOIN patient p ON p.patient_id = b.patient_id
WHERE  b.total_amount > (SELECT AVG(total_amount) FROM v_bill_total)
ORDER  BY b.total_amount DESC;

-- ---------------------------------------------------------------------
-- Q19. NESTED (correlated scalar subquery): last appointment date
--      and number of visits for every patient
-- ---------------------------------------------------------------------
SELECT p.patient_id, p.name AS patient_name,
       (SELECT MAX(a.appt_date)
        FROM   appointment a
        WHERE  a.patient_id = p.patient_id) AS last_visit,
       (SELECT COUNT(*)
        FROM   appointment a
        WHERE  a.patient_id = p.patient_id) AS visits
FROM   patient p
ORDER  BY last_visit DESC;

-- ---------------------------------------------------------------------
-- Q20. SET OPERATOR (MINUS): patients who booked appointments
--      but were never admitted
-- ---------------------------------------------------------------------
SELECT patient_id, name AS patient_name, city
FROM   patient
WHERE  patient_id IN (SELECT patient_id FROM appointment
                      MINUS
                      SELECT patient_id FROM admission)
ORDER  BY patient_id;

-- ---------------------------------------------------------------------
-- Q21. SQL FUNCTIONS (string): UPPER, LENGTH, SUBSTR, INSTR, ||
-- ---------------------------------------------------------------------
SELECT UPPER(name)                              AS doctor_name,
       LENGTH(name)                             AS name_length,
       SUBSTR(email, 1, INSTR(email, '@') - 1)  AS username,
       SUBSTR(email, INSTR(email, '@') + 1)     AS domain,
       'XXXXXX' || SUBSTR(phone, -4)            AS masked_phone
FROM   doctor
ORDER  BY name;

-- ---------------------------------------------------------------------
-- Q22. SQL FUNCTIONS (date) + CASE: medicines that are expired or
--      will expire within 6 months of today (depends on SYSDATE)
-- ---------------------------------------------------------------------
SELECT medicine_name, expiry_date, stock_qty,
       TRUNC(expiry_date - SYSDATE) AS days_left,
       CASE WHEN expiry_date < SYSDATE               THEN 'EXPIRED'
            WHEN expiry_date <= ADD_MONTHS(SYSDATE,3) THEN 'EXPIRING SOON'
            ELSE 'WATCH'
       END AS shelf_status
FROM   medicine
WHERE  expiry_date <= ADD_MONTHS(SYSDATE, 6)
ORDER  BY expiry_date;

-- ---------------------------------------------------------------------
-- Q23. SQL FUNCTIONS (TO_CHAR) + GROUP BY: appointments per month
-- ---------------------------------------------------------------------
SELECT TO_CHAR(appt_date, 'YYYY-MM')                          AS appt_month,
       COUNT(*)                                               AS total,
       SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END)  AS completed,
       SUM(CASE WHEN status = 'Scheduled' THEN 1 ELSE 0 END)  AS scheduled,
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END)  AS cancelled
FROM   appointment
GROUP  BY TO_CHAR(appt_date, 'YYYY-MM')
ORDER  BY appt_month;

-- ---------------------------------------------------------------------
-- Q24. ANALYTIC FUNCTION: rank patients by total amount billed
-- ---------------------------------------------------------------------
SELECT *
FROM  (SELECT p.name AS patient_name,
              SUM(b.total_amount) AS total_billed,
              RANK() OVER (ORDER BY SUM(b.total_amount) DESC) AS bill_rank
       FROM   v_bill_total b
              JOIN patient p ON p.patient_id = b.patient_id
       GROUP  BY p.name)
WHERE bill_rank <= 5
ORDER BY bill_rank;

SPOOL OFF
