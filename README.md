# CarePlus Hospital Management System (HMS)

A complete, full-stack Hospital Management System built on **Oracle Database 21c XE** and **Python Flask**, featuring full CRUD operations, complex SQL joins, subqueries, analytical functions, PL/SQL stored procedures, explicit cursor programs, and database triggers.

---

## 1. Project Structure (Self-Contained in `dbms_project`)

Everything is located directly inside this folder:

```
dbms_project/
├── hospital_db/                 # Oracle PL/SQL Scripts
│   ├── 01_schema.sql            # Tables, constraints, sequences, and derived views
│   ├── 02_data.sql              # Clean sample dataset (10-12 records per entity)
│   ├── 03_queries (1).sql       # 24 standard DBMS curriculum queries
│   ├── 04_functions_procedures.sql # 3 Functions + 5 Stored Procedures
│   ├── 04_cursors.sql           # 2 Explicit Cursor programs
│   ├── 05_ddl_dml_tcl_clean.sql # DDL/DML/TCL demonstration script
│   └── 07_triggers.sql          # 5 Automatic integrity triggers
│
├── app/                         # Flask Backend & UI
│   ├── db.py                    # Oracle connection pool & error parser
│   ├── routes/                  # Blueprint controllers (Patient, Appt, Admission, Pharmacy)
│   └── templates/               # Jinja2 + Bootstrap 5 responsive UI
├── package.json                 # pnpm / npm run scripts
├── requirements.txt             # Python dependencies (flask, oracledb, python-dotenv)
├── run.py                       # Application entry point
├── secrets.env                  # Database credentials (gitignored)
└── test_app.py                  # Automated test verification suite
```

---

## 2. Prerequisites

1. **Oracle Database XE** (Express Edition 21c, 18c, or 11g)
   - Listener Port: `1521`
   - Service Name: `xe`
2. **Python 3.10+** (Python 3.11, 3.12, or 3.13)
3. **Node.js & pnpm** *(Optional, for running with `pnpm start`)*

---

## 3. Setting Up the Local Oracle Database

Follow this exact order in **SQL\*Plus** to build the database objects and sample data.

### Step 3.1 — Verify Oracle Services are Running (Windows)
1. Press `Win + R`, type `services.msc`, and press Enter.
2. Confirm that **`OracleServiceXE`** and **`OracleOraDB21Home1TNSListener`** status is **Running**.

### Step 3.2 — Connect to SQL\*Plus from the project folder
Open your terminal inside `dbms_project`:
```powershell
sqlplus SYSTEM/<your_oracle_password>@localhost:1521/xe
```

*(Note: Connect to the root `xe` service. Do **not** use `xepdb1`)*.

### Step 3.3 — Execute the SQL Scripts
Since you are already in the project folder, run the scripts using relative paths:

```sql
-- 1. Create Tables, Constraints, Sequences, and Derived Views
@hospital_db\01_schema.sql;

-- 2. Insert Base Sample Data
@hospital_db\02_data.sql;

-- 3. Compile Stored Functions & Procedures
@hospital_db\04_functions_procedures.sql;

-- 4. Compile Explicit Cursor Procedures
@hospital_db\04_cursors.sql;

-- 5. Compile Database Triggers (MUST be compiled AFTER loading data)
@hospital_db\07_triggers.sql;
```

> **Important**: The order matters: `02_data.sql` must be loaded before `07_triggers.sql`, so the triggers do not block initial seed data insertion.

### Step 3.4 — Verify Setup
Verify that all 5 triggers and PL/SQL procedures are compiled and **VALID**:
```sql
SELECT object_name, object_type, status 
FROM user_objects 
WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'TRIGGER')
ORDER BY object_type, object_name;
```

---

## 4. Configuring Credentials (`secrets.env`)

In the `dbms_project/` folder, ensure **`secrets.env`** exists with your local Oracle password:
```ini
DB_USER=SYSTEM
DB_PASSWORD=your_actual_oracle_password
DB_DSN=localhost:1521/xe
PORT=5000
SECRET_KEY=hospital-hms-secret-key-2026
```

---

## 5. Installing Dependencies

If you haven't installed dependencies yet, activate the virtual environment and install:

```powershell
# Activate virtual environment
.\.env\Scripts\activate

# Install requirements
pip install -r requirements.txt
```

---

## 6. Running the Website

You can start the web app with either **pnpm** or **Python**:

### Using pnpm
```powershell
pnpm start
# or
pnpm dev
```

### Using Python directly
```powershell
python run.py
```

Then open your browser to:
👉 **`http://localhost:5000`**

---

## 7. Running the Test Suite

To verify that all routes and database connections work:
```powershell
pnpm test
# or
python test_app.py
```

---

## 8. Summary of Features & Oracle PL/SQL Implemented

- **Dashboard**: Live KPI statistics + Q12 (Room status `CASE`) + Q8 (Department doctor fees `AVG`/`MAX`).
- **Patients**: Full CRUD, search by name/city, `v_patient_age` view, multivalued phone numbers (`PATIENT_PHONE`), and weak entity emergency contacts.
- **Appointments**: 3-table join, booking slot via `sp_book_appointment` (validates `fn_is_slot_free`), cancelling via `sp_cancel_appointment`.
- **Admissions**: Inpatient stay tracking via `v_admission_stay` (Q6), admitting patient via `sp_admit_patient` (Trigger `trg_admission_occupy_room` marks room `Occupied`).
- **Discharge & Billing**: Discharging via `sp_discharge_and_bill` (Trigger `trg_admission_free_room` returns room to `Available`; calculates room stay charge via `fn_calc_room_charge`), settling bills with Trigger `trg_bill_payment_check`.
- **Pharmacy**: Inventory shelf life and expiry detection via Q22 (`CASE`), adding medicine (`seq_medicine.NEXTVAL`), dispensing medicine via `sp_prescribe_medicine` (Trigger `trg_prescribe_update_stock` deducts inventory and blocks expired medicines).
- **Batch Fee Revision**: Parameterized Explicit Cursor Procedure `sp_revise_doctor_fees` using `FOR UPDATE` / `WHERE CURRENT OF`.
- **Stock Alert Report**: Live streaming Oracle `DBMS_OUTPUT` console from `sp_pharmacy_alert_report`.
