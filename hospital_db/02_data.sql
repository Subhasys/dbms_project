-- =====================================================================
--  02_data.sql : sample data (10+ records per table)
--  Load order follows the foreign keys: parents first, children last.
--  Load this BEFORE 04_plsql.sql so the triggers do not fire on it.
-- =====================================================================

-- ---------------------------- DEPARTMENT (10) ------------------------
INSERT INTO department VALUES (1,  'Cardiology',       'Block A, Floor 2');
INSERT INTO department VALUES (2,  'Neurology',        'Block A, Floor 3');
INSERT INTO department VALUES (3,  'Orthopedics',      'Block B, Floor 1');
INSERT INTO department VALUES (4,  'Pediatrics',       'Block C, Floor 1');
INSERT INTO department VALUES (5,  'General Medicine', 'Block B, Floor 2');
INSERT INTO department VALUES (6,  'Dermatology',      'Block C, Floor 2');
INSERT INTO department VALUES (7,  'Gynecology',       'Block D, Floor 1');
INSERT INTO department VALUES (8,  'ENT',              'Block D, Floor 2');
INSERT INTO department VALUES (9,  'Oncology',         'Block A, Floor 4');
INSERT INTO department VALUES (10, 'Emergency',        'Main Block, Ground Floor');

-- ---------------------------- DOCTOR (12) ----------------------------
INSERT INTO doctor VALUES (101, 'Dr. Arvind Menon',   'Cardiologist',      '9840011101', 'arvind.menon@careplus.in',   800,  1);
INSERT INTO doctor VALUES (102, 'Dr. Kavya Rangan',   'Cardiologist',      '9840011102', 'kavya.rangan@careplus.in',   750,  1);
INSERT INTO doctor VALUES (103, 'Dr. Suresh Iyer',    'Neurologist',       '9840011103', 'suresh.iyer@careplus.in',    900,  2);
INSERT INTO doctor VALUES (104, 'Dr. Meena Pillai',   'Orthopedic Surgeon','9840011104', 'meena.pillai@careplus.in',   700,  3);
INSERT INTO doctor VALUES (105, 'Dr. Rohit Sharma',   'Pediatrician',      '9840011105', 'rohit.sharma@careplus.in',   500,  4);
INSERT INTO doctor VALUES (106, 'Dr. Anjali Nair',    'Pediatrician',      '9840011106', 'anjali.nair@careplus.in',    500,  4);
INSERT INTO doctor VALUES (107, 'Dr. Farhan Ali',     'General Physician', '9840011107', 'farhan.ali@careplus.in',     400,  5);
INSERT INTO doctor VALUES (108, 'Dr. Lakshmi Devi',   'General Physician', '9840011108', 'lakshmi.devi@careplus.in',   400,  5);
INSERT INTO doctor VALUES (109, 'Dr. Vikram Reddy',   'Dermatologist',     '9840011109', 'vikram.reddy@careplus.in',   600,  6);
INSERT INTO doctor VALUES (110, 'Dr. Sneha Kulkarni', 'Gynecologist',      '9840011110', 'sneha.kulkarni@careplus.in', 650,  7);
INSERT INTO doctor VALUES (111, 'Dr. Imran Khan',     'ENT Specialist',    '9840011111', 'imran.khan@careplus.in',     550,  8);
INSERT INTO doctor VALUES (112, 'Dr. Priya Raman',    'Oncologist',        '9840011112', 'priya.raman@careplus.in',   1000,  9);

-- ---------------------------- PATIENT (12) ---------------------------
INSERT INTO patient VALUES (1001, 'Ravi Kumar',          DATE '1985-03-14', 'Male',   'O+',  'Type 2 diabetes',          '12 Gandhi Road',  'Vellore',    '632001');
INSERT INTO patient VALUES (1002, 'Priya Sharma',        DATE '1992-07-22', 'Female', 'A+',  'Asthma',                   '45 Anna Nagar',   'Chennai',    '600040');
INSERT INTO patient VALUES (1003, 'Mohammed Irfan',      DATE '1978-11-05', 'Male',   'B+',  'Hypertension',             '7 Mill Street',   'Ambur',      '635802');
INSERT INTO patient VALUES (1004, 'Divya Lakshmi',       DATE '2001-01-30', 'Female', 'O-',  'None',                     '23 Temple Road',  'Katpadi',    '632007');
INSERT INTO patient VALUES (1005, 'Arjun Nair',          DATE '1969-09-18', 'Male',   'AB+', 'Coronary artery disease',  '88 Lake View',    'Vellore',    '632004');
INSERT INTO patient VALUES (1006, 'Sneha Reddy',         DATE '1995-12-02', 'Female', 'B-',  'Thyroid disorder',         '5 MG Road',       'Bengaluru',  '560001');
INSERT INTO patient VALUES (1007, 'Karthik Subramanian', DATE '1988-06-11', 'Male',   'A-',  'None',                     '31 Bazaar Street','Ranipet',    '632401');
INSERT INTO patient VALUES (1008, 'Fatima Begum',        DATE '1957-04-25', 'Female', 'O+',  'Arthritis, hypertension',  '14 Fort Road',    'Vellore',    '632001');
INSERT INTO patient VALUES (1009, 'Aadhya Venkat',       DATE '2020-08-09', 'Female', 'B+',  'Seasonal allergies',       '9 Park Avenue',   'Chennai',    '600017');
INSERT INTO patient VALUES (1010, 'Rajesh Gupta',        DATE '1973-02-17', 'Male',   'AB-', 'Migraine',                 '67 Station Road', 'Tirupattur', '635601');
INSERT INTO patient VALUES (1011, 'Lakshmi Narayanan',   DATE '1962-10-08', 'Female', 'A+',  'Knee replacement in 2019', '19 Nehru Street', 'Gudiyatham', '632602');
INSERT INTO patient VALUES (1012, 'Sanjay Patel',        DATE '1999-05-29', 'Male',   'O+',  'None',                     '2 College Road',  'Katpadi',    '632007');

-- ---------------------------- PATIENT_PHONE (14) ---------------------
INSERT INTO patient_phone VALUES (1001, '9841100001');
INSERT INTO patient_phone VALUES (1001, '9841100101');
INSERT INTO patient_phone VALUES (1002, '9841100002');
INSERT INTO patient_phone VALUES (1003, '9841100003');
INSERT INTO patient_phone VALUES (1004, '9841100004');
INSERT INTO patient_phone VALUES (1004, '9841100104');
INSERT INTO patient_phone VALUES (1005, '9841100005');
INSERT INTO patient_phone VALUES (1006, '9841100006');
INSERT INTO patient_phone VALUES (1007, '9841100007');
INSERT INTO patient_phone VALUES (1008, '9841100008');
INSERT INTO patient_phone VALUES (1009, '9841100009');
INSERT INTO patient_phone VALUES (1010, '9841100010');
INSERT INTO patient_phone VALUES (1011, '9841100011');
INSERT INTO patient_phone VALUES (1012, '9841100012');

-- ---------------------------- EMERGENCY_CONTACT (13) -----------------
INSERT INTO emergency_contact VALUES (1001, 'Sunita Kumar',      'Wife',    '9841200001');
INSERT INTO emergency_contact VALUES (1001, 'Mohan Kumar',       'Brother', '9841200101');
INSERT INTO emergency_contact VALUES (1002, 'Anil Sharma',       'Father',  '9841200002');
INSERT INTO emergency_contact VALUES (1003, 'Zainab Irfan',      'Wife',    '9841200003');
INSERT INTO emergency_contact VALUES (1004, 'Lakshmi Devi',      'Mother',  '9841200004');
INSERT INTO emergency_contact VALUES (1005, 'Meera Nair',        'Wife',    '9841200005');
INSERT INTO emergency_contact VALUES (1006, 'Ramesh Reddy',      'Father',  '9841200006');
INSERT INTO emergency_contact VALUES (1007, 'Anitha Karthik',    'Wife',    '9841200007');
INSERT INTO emergency_contact VALUES (1008, 'Salim Ahmed',       'Son',     '9841200008');
INSERT INTO emergency_contact VALUES (1009, 'Venkat Raman',      'Father',  '9841200009');
INSERT INTO emergency_contact VALUES (1010, 'Pooja Gupta',       'Wife',    '9841200010');
INSERT INTO emergency_contact VALUES (1011, 'Narayanan Iyer',    'Husband', '9841200011');
INSERT INTO emergency_contact VALUES (1012, 'Kiran Patel',       'Brother', '9841200012');

-- ---------------------------- MEDICINE (12) --------------------------
INSERT INTO medicine VALUES (201, 'Paracetamol 500mg',   'Cipla',        2.50,  500, DATE '2028-03-31');
INSERT INTO medicine VALUES (202, 'Amoxicillin 250mg',   'Sun Pharma',   8.00,  300, DATE '2027-11-30');
INSERT INTO medicine VALUES (203, 'Metformin 500mg',     'Dr. Reddy''s', 3.20,  400, DATE '2027-06-30');
INSERT INTO medicine VALUES (204, 'Atorvastatin 10mg',   'Zydus',        6.50,  250, DATE '2027-09-30');
INSERT INTO medicine VALUES (205, 'Amlodipine 5mg',      'Lupin',        4.00,  350, DATE '2027-12-31');
INSERT INTO medicine VALUES (206, 'Cetirizine 10mg',     'Cipla',        1.80,  600, DATE '2027-04-30');
INSERT INTO medicine VALUES (207, 'Salbutamol Inhaler',  'GSK',        120.00,   60, DATE '2026-12-15');
INSERT INTO medicine VALUES (208, 'Pantoprazole 40mg',   'Alkem',        5.50,  280, DATE '2027-08-31');
INSERT INTO medicine VALUES (209, 'Ibuprofen 400mg',     'Abbott',       2.20,   45, DATE '2027-02-28');
INSERT INTO medicine VALUES (210, 'Aspirin 75mg',        'Bayer',        1.50,  700, DATE '2027-10-31');
INSERT INTO medicine VALUES (211, 'ORS Sachet',          'Dr. Reddy''s',18.00,  150, DATE '2026-11-20');
INSERT INTO medicine VALUES (212, 'Azithromycin 500mg',  'Pfizer',      22.00,  200, DATE '2026-08-31');

-- ---------------------------- ROOM (12) ------------------------------
INSERT INTO room VALUES (101, 'General', 1000, 'Available');
INSERT INTO room VALUES (102, 'General', 1000, 'Available');
INSERT INTO room VALUES (103, 'General', 1000, 'Available');
INSERT INTO room VALUES (104, 'General', 1000, 'Available');
INSERT INTO room VALUES (105, 'General', 1000, 'Occupied');
INSERT INTO room VALUES (106, 'General', 1000, 'Maintenance');
INSERT INTO room VALUES (201, 'Private', 2500, 'Available');
INSERT INTO room VALUES (202, 'Private', 2500, 'Available');
INSERT INTO room VALUES (203, 'Private', 2500, 'Available');
INSERT INTO room VALUES (204, 'Private', 2500, 'Occupied');
INSERT INTO room VALUES (301, 'ICU',     5000, 'Available');
INSERT INTO room VALUES (302, 'ICU',     5000, 'Occupied');

-- ---------------------------- APPOINTMENT (16) -----------------------
INSERT INTO appointment VALUES (3001, DATE '2026-08-01', '10:00', 'Completed', 'Chest pain, abnormal ECG',   1005, 101);
INSERT INTO appointment VALUES (3002, DATE '2026-08-14', '11:30', 'Completed', 'Wrist fracture',             1011, 104);
INSERT INTO appointment VALUES (3003, DATE '2026-08-31', '09:30', 'Completed', 'Bronchial asthma',           1002, 107);
INSERT INTO appointment VALUES (3004, DATE '2026-09-09', '10:15', 'Completed', 'Viral fever',                1009, 105);
INSERT INTO appointment VALUES (3005, DATE '2026-09-17', '14:00', 'Completed', 'Type 2 diabetes, high sugar',1001, 107);
INSERT INTO appointment VALUES (3006, DATE '2026-09-24', '09:00', 'Completed', 'Hypertension stage 2',       1003, 102);
INSERT INTO appointment VALUES (3007, DATE '2026-10-02', '15:30', 'Completed', 'Osteoarthritis',             1008, 104);
INSERT INTO appointment VALUES (3008, DATE '2026-10-09', '10:00', 'Completed', 'Chronic migraine',           1010, 103);
INSERT INTO appointment VALUES (3009, DATE '2026-10-12', '12:00', 'Completed', 'Skin allergy',               1004, 109);
INSERT INTO appointment VALUES (3010, DATE '2026-10-15', '16:00', 'Completed', 'Thyroid review',             1006, 108);
INSERT INTO appointment VALUES (3011, DATE '2026-10-17', '10:30', 'Cancelled', NULL,                         1007, 111);
INSERT INTO appointment VALUES (3012, DATE '2026-10-19', '11:00', 'Completed', 'Cardiac follow-up',          1005, 101);
INSERT INTO appointment VALUES (3013, DATE '2026-10-26', '10:00', 'Scheduled', NULL,                         1002, 107);
INSERT INTO appointment VALUES (3014, DATE '2026-10-27', '09:30', 'Scheduled', NULL,                         1006, 110);
INSERT INTO appointment VALUES (3015, DATE '2026-10-28', '11:00', 'Scheduled', NULL,                         1001, 108);
INSERT INTO appointment VALUES (3016, DATE '2026-10-21', '10:00', 'Completed', 'Viral fever',                1012, 108);

-- ---------------------------- PRESCRIBES (19) ------------------------
INSERT INTO prescribes VALUES (3001, 210, '75mg once daily',            30, 30);
INSERT INTO prescribes VALUES (3001, 204, '10mg at night',              30, 30);
INSERT INTO prescribes VALUES (3002, 201, '500mg thrice daily',          5, 15);
INSERT INTO prescribes VALUES (3002, 209, '400mg twice daily',           5, 10);
INSERT INTO prescribes VALUES (3003, 207, '2 puffs when needed',        30,  1);
INSERT INTO prescribes VALUES (3003, 206, '10mg once daily',            10, 10);
INSERT INTO prescribes VALUES (3004, 201, '5 ml thrice daily',           3,  9);
INSERT INTO prescribes VALUES (3004, 211, '1 sachet after loose stool',  3,  6);
INSERT INTO prescribes VALUES (3005, 203, '500mg twice daily',          30, 60);
INSERT INTO prescribes VALUES (3005, 208, '40mg before breakfast',      14, 14);
INSERT INTO prescribes VALUES (3006, 205, '5mg once daily',             30, 30);
INSERT INTO prescribes VALUES (3006, 210, '75mg once daily',            30, 30);
INSERT INTO prescribes VALUES (3007, 209, '400mg twice daily',          10, 20);
INSERT INTO prescribes VALUES (3007, 208, '40mg before breakfast',      10, 10);
INSERT INTO prescribes VALUES (3008, 201, '500mg when needed',           7, 10);
INSERT INTO prescribes VALUES (3009, 206, '10mg at night',               7,  7);
INSERT INTO prescribes VALUES (3012, 204, '10mg at night',              30, 30);
INSERT INTO prescribes VALUES (3012, 210, '75mg once daily',            30, 30);
INSERT INTO prescribes VALUES (3016, 201, '500mg thrice daily',          3,  9);

-- ---------------------------- ADMISSION (11) -------------------------
INSERT INTO admission VALUES (5001, DATE '2026-08-02', DATE '2026-08-06', 'Chest pain observation',   1005, 301);
INSERT INTO admission VALUES (5002, DATE '2026-08-15', DATE '2026-08-18', 'Fracture surgery recovery',1011, 201);
INSERT INTO admission VALUES (5003, DATE '2026-09-01', DATE '2026-09-04', 'Asthma exacerbation',      1002, 101);
INSERT INTO admission VALUES (5004, DATE '2026-09-10', DATE '2026-09-14', 'High fever',               1009, 102);
INSERT INTO admission VALUES (5005, DATE '2026-09-18', DATE '2026-09-21', 'Uncontrolled diabetes',    1001, 202);
INSERT INTO admission VALUES (5006, DATE '2026-09-25', DATE '2026-09-30', 'Hypertensive crisis',      1003, 103);
INSERT INTO admission VALUES (5007, DATE '2026-10-03', DATE '2026-10-08', 'Joint pain management',    1008, 203);
INSERT INTO admission VALUES (5008, DATE '2026-10-10', DATE '2026-10-13', 'Severe migraine',          1010, 104);
INSERT INTO admission VALUES (5009, DATE '2026-10-18', NULL,              'Cardiac monitoring',       1005, 302);
INSERT INTO admission VALUES (5010, DATE '2026-10-20', NULL,              'Post-operative care',      1011, 204);
INSERT INTO admission VALUES (5011, DATE '2026-10-22', NULL,              'Viral fever',              1012, 105);

-- ---------------------------- BILL (12) ------------------------------
--  consultation = doctor fee, medicine = SUM(unit_price x quantity),
--  room = stay_days x charge_per_day
INSERT INTO bill VALUES (7001, DATE '2026-08-06',  800,  240.00, 20000, 'Insurance', 'Paid',    1005);
INSERT INTO bill VALUES (7002, DATE '2026-08-18',  700,   59.50,  7500, 'Card',      'Paid',    1011);
INSERT INTO bill VALUES (7003, DATE '2026-09-04',  400,  138.00,  3000, 'UPI',       'Paid',    1002);
INSERT INTO bill VALUES (7004, DATE '2026-09-14',  500,  130.50,  4000, 'Cash',      'Paid',    1009);
INSERT INTO bill VALUES (7005, DATE '2026-09-21',  400,  269.00,  7500, 'Card',      'Paid',    1001);
INSERT INTO bill VALUES (7006, DATE '2026-09-30',  750,  165.00,  5000, 'Insurance', 'Paid',    1003);
INSERT INTO bill VALUES (7007, DATE '2026-10-08',  700,   99.00, 12500, NULL,        'Pending', 1008);
INSERT INTO bill VALUES (7008, DATE '2026-10-13',  900,   25.00,  3000, 'Cash',      'Paid',    1010);
INSERT INTO bill VALUES (7009, DATE '2026-10-12',  600,   12.60,     0, 'UPI',       'Paid',    1004);
INSERT INTO bill VALUES (7010, DATE '2026-10-15',  400,    0.00,     0, NULL,        'Pending', 1006);
INSERT INTO bill VALUES (7011, DATE '2026-10-19',  800,  240.00,     0, 'Card',      'Paid',    1005);
INSERT INTO bill VALUES (7012, DATE '2026-10-21',  400,   22.50,     0, NULL,        'Pending', 1012);

COMMIT;
