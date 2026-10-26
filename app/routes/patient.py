from datetime import datetime
from flask import Blueprint, render_template, request, redirect, url_for, flash
from app.db import get_db, rows_to_dicts, parse_db_error

patient_bp = Blueprint('patient', __name__)

@patient_bp.route('/')
def list_patients():
    search = request.args.get('search', '').strip()
    city_filter = request.args.get('city', '').strip()

    query = """
        SELECT p.patient_id, p.name, p.dob, v.age, p.gender, p.blood_group,
               p.street, p.city, p.pincode, p.medical_history,
               (SELECT LISTAGG(phone_no, ', ') WITHIN GROUP (ORDER BY phone_no)
                FROM patient_phone WHERE patient_id = p.patient_id) AS phone_numbers
        FROM patient p
        JOIN v_patient_age v ON v.patient_id = p.patient_id
        WHERE 1=1
    """
    params = {}
    if search:
        query += " AND (UPPER(p.name) LIKE :search OR UPPER(p.city) LIKE :search)"
        params['search'] = f"%{search.upper()}%"
    if city_filter:
        query += " AND UPPER(p.city) = :city"
        params['city'] = city_filter.upper()

    query += " ORDER BY p.patient_id"

    patients = []
    cities = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                patients = rows_to_dicts(cur)

                cur.execute("SELECT DISTINCT city FROM patient ORDER BY city")
                cities = [r[0] for r in cur.fetchall()]
    except Exception as e:
        flash(f"Error fetching patients: {parse_db_error(e)}", "danger")

    return render_template('patient/list.html', patients=patients, search=search, city_filter=city_filter, cities=cities)

@patient_bp.route('/<int:patient_id>')
def view_patient(patient_id):
    patient = None
    phones = []
    contacts = []
    appointments = []
    admissions = []
    bills = []

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT p.*, v.age
                    FROM patient p
                    JOIN v_patient_age v ON v.patient_id = p.patient_id
                    WHERE p.patient_id = :id
                """, {'id': patient_id})
                rows = rows_to_dicts(cur)
                if not rows:
                    flash(f"Patient with ID {patient_id} not found.", "warning")
                    return redirect(url_for('patient.list_patients'))
                patient = rows[0]

                # Phone numbers
                cur.execute("SELECT phone_no FROM patient_phone WHERE patient_id = :id", {'id': patient_id})
                phones = [r[0] for r in cur.fetchall()]

                # Emergency contacts
                cur.execute("SELECT contact_name, relationship, phone_no FROM emergency_contact WHERE patient_id = :id", {'id': patient_id})
                contacts = rows_to_dicts(cur)

                # Appointments
                cur.execute("""
                    SELECT a.appointment_id, a.appt_date, a.appt_time, a.status, a.diagnosis, d.name AS doctor_name
                    FROM appointment a
                    JOIN doctor d ON d.doctor_id = a.doctor_id
                    WHERE a.patient_id = :id
                    ORDER BY a.appt_date DESC
                """, {'id': patient_id})
                appointments = rows_to_dicts(cur)

                # Admissions
                cur.execute("""
                    SELECT a.admission_id, a.admit_date, a.discharge_date, a.reason,
                           r.room_no, r.room_type, s.stay_days
                    FROM admission a
                    JOIN room r ON r.room_no = a.room_no
                    JOIN v_admission_stay s ON s.admission_id = a.admission_id
                    WHERE a.patient_id = :id
                    ORDER BY a.admit_date DESC
                """, {'id': patient_id})
                admissions = rows_to_dicts(cur)

                # Bills
                cur.execute("""
                    SELECT b.*, b.consultation_charge + b.medicine_charge + b.room_charge AS total_amount
                    FROM bill b
                    WHERE b.patient_id = :id
                    ORDER BY b.bill_date DESC
                """, {'id': patient_id})
                bills = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading patient profile: {parse_db_error(e)}", "danger")
        return redirect(url_for('patient.list_patients'))

    return render_template(
        'patient/view.html',
        patient=patient,
        phones=phones,
        contacts=contacts,
        appointments=appointments,
        admissions=admissions,
        bills=bills
    )

@patient_bp.route('/add', methods=['GET', 'POST'])
def add_patient():
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        dob_str = request.form.get('dob', '').strip()
        gender = request.form.get('gender', '').strip()
        blood_group = request.form.get('blood_group', '').strip() or None
        medical_history = request.form.get('medical_history', '').strip() or 'None'
        street = request.form.get('street', '').strip() or None
        city = request.form.get('city', '').strip()
        pincode = request.form.get('pincode', '').strip() or None
        phone = request.form.get('phone', '').strip()
        emergency_name = request.form.get('emergency_name', '').strip()
        emergency_rel = request.form.get('emergency_rel', '').strip()
        emergency_phone = request.form.get('emergency_phone', '').strip()

        try:
            dob = datetime.strptime(dob_str, '%Y-%m-%d').date()
            with get_db() as conn:
                with conn.cursor() as cur:
                    # Get next ID from sequence
                    cur.execute("SELECT seq_patient.NEXTVAL FROM dual")
                    patient_id = cur.fetchone()[0]

                    # Insert patient
                    cur.execute("""
                        INSERT INTO patient (patient_id, name, dob, gender, blood_group, medical_history, street, city, pincode)
                        VALUES (:id, :name, :dob, :gender, :bg, :history, :street, :city, :pin)
                    """, {
                        'id': patient_id,
                        'name': name,
                        'dob': dob,
                        'gender': gender,
                        'bg': blood_group,
                        'history': medical_history,
                        'street': street,
                        'city': city,
                        'pin': pincode
                    })

                    # Insert phone number
                    if phone:
                        cur.execute("""
                            INSERT INTO patient_phone (patient_id, phone_no)
                            VALUES (:id, :phone)
                        """, {'id': patient_id, 'phone': phone})

                    # Insert emergency contact if provided
                    if emergency_name and emergency_rel and emergency_phone:
                        cur.execute("""
                            INSERT INTO emergency_contact (patient_id, contact_name, relationship, phone_no)
                            VALUES (:id, :cname, :rel, :cphone)
                        """, {
                            'id': patient_id,
                            'cname': emergency_name,
                            'rel': emergency_rel,
                            'cphone': emergency_phone
                        })

                conn.commit()
                flash(f"Patient '{name}' successfully registered with ID {patient_id}!", "success")
                return redirect(url_for('patient.view_patient', patient_id=patient_id))
        except Exception as e:
            flash(f"Failed to register patient: {parse_db_error(e)}", "danger")

    return render_template('patient/form.html', patient=None, action='Register')

@patient_bp.route('/<int:patient_id>/edit', methods=['GET', 'POST'])
def edit_patient(patient_id):
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                if request.method == 'POST':
                    name = request.form.get('name', '').strip()
                    city = request.form.get('city', '').strip()
                    street = request.form.get('street', '').strip() or None
                    pincode = request.form.get('pincode', '').strip() or None
                    medical_history = request.form.get('medical_history', '').strip() or 'None'
                    blood_group = request.form.get('blood_group', '').strip() or None
                    new_phone = request.form.get('new_phone', '').strip()

                    cur.execute("""
                        UPDATE patient
                        SET name = :name,
                            city = :city,
                            street = :street,
                            pincode = :pincode,
                            medical_history = :history,
                            blood_group = :bg
                        WHERE patient_id = :id
                    """, {
                        'name': name,
                        'city': city,
                        'street': street,
                        'pincode': pincode,
                        'history': medical_history,
                        'bg': blood_group,
                        'id': patient_id
                    })

                    if new_phone:
                        try:
                            cur.execute("""
                                INSERT INTO patient_phone (patient_id, phone_no)
                                VALUES (:id, :phone)
                            """, {'id': patient_id, 'phone': new_phone})
                        except Exception:
                            pass # Phone might already exist

                    conn.commit()
                    flash(f"Patient #{patient_id} details updated successfully.", "success")
                    return redirect(url_for('patient.view_patient', patient_id=patient_id))

                # GET
                cur.execute("SELECT * FROM patient WHERE patient_id = :id", {'id': patient_id})
                rows = rows_to_dicts(cur)
                if not rows:
                    flash(f"Patient {patient_id} not found.", "warning")
                    return redirect(url_for('patient.list_patients'))
                patient = rows[0]
                return render_template('patient/form.html', patient=patient, action='Update')
    except Exception as e:
        flash(f"Error updating patient: {parse_db_error(e)}", "danger")
        return redirect(url_for('patient.list_patients'))

@patient_bp.route('/<int:patient_id>/delete', methods=['POST'])
def delete_patient(patient_id):
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # CASCADE deletes phones & emergency contacts automatically per schema foreign keys.
                # If the patient has appointments, admissions, or bills, Oracle foreign key will protect it.
                cur.execute("DELETE FROM patient WHERE patient_id = :id", {'id': patient_id})
            conn.commit()
            flash(f"Patient #{patient_id} has been deleted.", "success")
    except Exception as e:
        flash(f"Cannot delete Patient #{patient_id}: {parse_db_error(e)}", "danger")

    return redirect(url_for('patient.list_patients'))

@patient_bp.route('/analytics')
def analytics():
    senior_patients = []
    multiple_phones = []
    never_admitted = []
    city_patients = []
    patient_visits = []

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Q2: Patients aged 50+
                cur.execute("""
                    SELECT patient_id, name, dob, age
                    FROM   v_patient_age
                    WHERE  age >= 50
                    ORDER  BY age DESC
                """)
                senior_patients = rows_to_dicts(cur)

                # Q11: Patients with multiple phones
                cur.execute("""
                    SELECT p.patient_id, p.name AS patient_name, COUNT(*) AS phone_count,
                           LISTAGG(ph.phone_no, ', ') WITHIN GROUP (ORDER BY ph.phone_no) AS phones
                    FROM   patient p
                           JOIN patient_phone ph ON ph.patient_id = p.patient_id
                    GROUP  BY p.patient_id, p.name
                    HAVING COUNT(*) > 1
                """)
                multiple_phones = rows_to_dicts(cur)

                # Q20: MINUS set operator — Booked appointment but never admitted
                cur.execute("""
                    SELECT patient_id, name AS patient_name, city
                    FROM   patient
                    WHERE  patient_id IN (
                               SELECT patient_id FROM appointment
                               MINUS
                               SELECT patient_id FROM admission
                           )
                    ORDER  BY patient_id
                """)
                never_admitted = rows_to_dicts(cur)

                # Q1: Vellore patients
                cur.execute("""
                    SELECT patient_id, name, gender, blood_group, city
                    FROM   patient
                    WHERE  city = 'Vellore'
                    ORDER  BY name
                """)
                city_patients = rows_to_dicts(cur)

                # Q19: Correlated subquery — Visits and last visit
                cur.execute("""
                    SELECT p.patient_id, p.name AS patient_name,
                           (SELECT MAX(a.appt_date)
                            FROM   appointment a
                            WHERE  a.patient_id = p.patient_id) AS last_visit,
                           (SELECT COUNT(*)
                            FROM   appointment a
                            WHERE  a.patient_id = p.patient_id) AS visits
                    FROM   patient p
                    ORDER  BY last_visit DESC NULLS LAST
                """)
                patient_visits = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error executing analytics: {parse_db_error(e)}", "danger")

    return render_template(
        'patient/analytics.html',
        senior_patients=senior_patients,
        multiple_phones=multiple_phones,
        never_admitted=never_admitted,
        city_patients=city_patients,
        patient_visits=patient_visits
    )

