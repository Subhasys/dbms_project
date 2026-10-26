from datetime import datetime
from flask import Blueprint, render_template, request, redirect, url_for, flash
import oracledb
from app.db import get_db, rows_to_dicts, parse_db_error

admission_bp = Blueprint('admission', __name__)

@admission_bp.route('/')
def list_admissions():
    # Active admissions (Q6) and past admissions
    filter_status = request.args.get('status', 'active')

    query_active = """
        SELECT a.admission_id, a.admit_date, a.discharge_date, a.reason,
               p.patient_id, p.name AS patient_name,
               r.room_no, r.room_type, r.charge_per_day,
               s.stay_days,
               s.stay_days * r.charge_per_day AS charge_so_far
        FROM   admission a
               JOIN patient          p ON p.patient_id   = a.patient_id
               JOIN room             r ON r.room_no      = a.room_no
               JOIN v_admission_stay s ON s.admission_id = a.admission_id
        WHERE  a.discharge_date IS NULL
        ORDER  BY a.admit_date DESC
    """

    query_all = """
        SELECT a.admission_id, a.admit_date, a.discharge_date, a.reason,
               p.patient_id, p.name AS patient_name,
               r.room_no, r.room_type, r.charge_per_day,
               s.stay_days,
               s.stay_days * r.charge_per_day AS charge_so_far
        FROM   admission a
               JOIN patient          p ON p.patient_id   = a.patient_id
               JOIN room             r ON r.room_no      = a.room_no
               JOIN v_admission_stay s ON s.admission_id = a.admission_id
        ORDER  BY a.admit_date DESC
    """

    admissions = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                if filter_status == 'active':
                    cur.execute(query_active)
                else:
                    cur.execute(query_all)
                admissions = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading admissions: {parse_db_error(e)}", "danger")

    return render_template('admission/list.html', admissions=admissions, filter_status=filter_status)

@admission_bp.route('/admit', methods=['GET', 'POST'])
def admit_patient():
    prefill_patient_id = request.args.get('patient_id', '')

    if request.method == 'POST':
        try:
            patient_id = int(request.form.get('patient_id'))
            room_no = int(request.form.get('room_no'))
            reason = request.form.get('reason', '').strip()

            with get_db() as conn:
                with conn.cursor() as cur:
                    # Stored Procedure call: sp_admit_patient
                    # parameters: p_patient_id, p_room_no, p_reason, p_admission_id (OUT NUMBER)
                    out_adm_id = cur.var(oracledb.NUMBER)
                    cur.callproc('sp_admit_patient', [patient_id, room_no, reason, out_adm_id])
                    new_id = int(out_adm_id.getvalue())
                conn.commit()
                flash(f"Patient successfully admitted under Admission #{new_id}! Room {room_no} marked Occupied.", "success")
                return redirect(url_for('admission.list_admissions'))
        except Exception as e:
            flash(f"Admission failed: {parse_db_error(e)}", "danger")

    patients = []
    rooms = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT patient_id, name, city FROM patient ORDER BY name")
                patients = rows_to_dicts(cur)
                # Available rooms
                cur.execute("SELECT room_no, room_type, charge_per_day, status FROM room ORDER BY status, room_no")
                rooms = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading admit options: {parse_db_error(e)}", "danger")

    return render_template(
        'admission/admit.html',
        patients=patients,
        rooms=rooms,
        prefill_patient_id=prefill_patient_id
    )

@admission_bp.route('/<int:admission_id>/discharge', methods=['GET', 'POST'])
def discharge_patient(admission_id):
    if request.method == 'POST':
        try:
            appt_id_str = request.form.get('appointment_id', '').strip()
            payment_mode = request.form.get('payment_mode', '').strip() or None
            appt_id = int(appt_id_str) if appt_id_str else None

            with get_db() as conn:
                with conn.cursor() as cur:
                    # Stored Procedure call: sp_discharge_and_bill
                    # parameters: p_admission_id, p_appointment_id, p_payment_mode, p_bill_id (OUT NUMBER)
                    out_bill_id = cur.var(oracledb.NUMBER)
                    cur.callproc('sp_discharge_and_bill', [
                        admission_id,
                        appt_id,
                        payment_mode,
                        out_bill_id
                    ])
                    new_bill_id = int(out_bill_id.getvalue())
                conn.commit()
                flash(f"Patient discharged! Room freed to Available. Generated Bill #{new_bill_id} ({'Paid' if payment_mode else 'Pending'}).", "success")
                return redirect(url_for('admission.list_bills'))
        except Exception as e:
            flash(f"Discharge and billing failed: {parse_db_error(e)}", "danger")

    admission = None
    patient_appointments = []
    calculated_room_charge = 0
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT a.admission_id, a.admit_date, a.reason, a.patient_id, a.room_no,
                           p.name AS patient_name, r.room_type, r.charge_per_day, s.stay_days
                    FROM admission a
                    JOIN patient p ON p.patient_id = a.patient_id
                    JOIN room r ON r.room_no = a.room_no
                    JOIN v_admission_stay s ON s.admission_id = a.admission_id
                    WHERE a.admission_id = :id AND a.discharge_date IS NULL
                """, {'id': admission_id})
                rows = rows_to_dicts(cur)
                if not rows:
                    flash(f"Active admission #{admission_id} not found.", "warning")
                    return redirect(url_for('admission.list_admissions'))
                admission = rows[0]

                # Call fn_calc_room_charge
                cur.execute("SELECT fn_calc_room_charge(:id) FROM dual", {'id': admission_id})
                calculated_room_charge = cur.fetchone()[0]

                # Find relevant appointments for this patient
                cur.execute("""
                    SELECT a.appointment_id, a.appt_date, a.appt_time, d.name AS doctor_name, d.consultation_fee,
                           fn_medicine_charge(a.appointment_id) AS medicine_charge
                    FROM appointment a
                    JOIN doctor d ON d.doctor_id = a.doctor_id
                    WHERE a.patient_id = :pid
                    ORDER BY a.appt_date DESC
                """, {'pid': admission['patient_id']})
                patient_appointments = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error fetching discharge details: {parse_db_error(e)}", "danger")
        return redirect(url_for('admission.list_admissions'))

    return render_template(
        'admission/discharge.html',
        admission=admission,
        patient_appointments=patient_appointments,
        calculated_room_charge=calculated_room_charge
    )

@admission_bp.route('/bills')
def list_bills():
    status_filter = request.args.get('status', '').strip()
    mode_filter = request.args.get('mode', '').strip()

    query = """
        SELECT b.bill_id, b.bill_date, b.patient_id, p.name AS patient_name,
               b.consultation_charge, b.medicine_charge, b.room_charge,
               b.total_amount, b.payment_mode, b.payment_status
        FROM   v_bill_total b
               JOIN patient p ON p.patient_id = b.patient_id
        WHERE  1=1
    """
    params = {}
    if status_filter:
        query += " AND b.payment_status = :status"
        params['status'] = status_filter
    if mode_filter:
        query += " AND b.payment_mode = :mode"
        params['mode'] = mode_filter

    query += " ORDER BY b.bill_id DESC"

    bills = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                bills = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error fetching bills: {parse_db_error(e)}", "danger")

    return render_template('admission/bills.html', bills=bills, status_filter=status_filter, mode_filter=mode_filter)

@admission_bp.route('/bills/<int:bill_id>/pay', methods=['POST'])
def pay_bill(bill_id):
    payment_mode = request.form.get('payment_mode', '').strip()
    if not payment_mode:
        flash("Please select a payment mode (Cash, Card, UPI, Insurance) to mark as Paid.", "warning")
        return redirect(url_for('admission.list_bills'))

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Trigger trg_bill_payment_check requires payment_mode when status is 'Paid'
                cur.execute("""
                    UPDATE bill
                    SET payment_status = 'Paid',
                        payment_mode = :mode
                    WHERE bill_id = :id AND payment_status = 'Pending'
                """, {'mode': payment_mode, 'id': bill_id})
            conn.commit()
            flash(f"Bill #{bill_id} marked as Paid via {payment_mode}.", "success")
    except Exception as e:
        flash(f"Payment update failed: {parse_db_error(e)}", "danger")

    return redirect(url_for('admission.list_bills'))

@admission_bp.route('/analytics')
def analytics():
    icu_patients = []
    above_avg_bills = []
    revenue_by_mode = []
    bills_by_status = []
    top_billed_patients = []

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Q16: Patients ever admitted to ICU (Nested IN subquery)
                cur.execute("""
                    SELECT patient_id, name AS patient_name, blood_group, medical_history
                    FROM   patient
                    WHERE  patient_id IN (SELECT a.patient_id
                                          FROM   admission a
                                                 JOIN room r ON r.room_no = a.room_no
                                          WHERE  r.room_type = 'ICU')
                """)
                icu_patients = rows_to_dicts(cur)

                # Q18: Bills above average bill amount (Nested subquery on view)
                cur.execute("""
                    SELECT b.bill_id, p.name AS patient_name, b.total_amount, b.payment_status
                    FROM   v_bill_total b
                           JOIN patient p ON p.patient_id = b.patient_id
                    WHERE  b.total_amount > (SELECT AVG(total_amount) FROM v_bill_total)
                    ORDER  BY b.total_amount DESC
                """)
                above_avg_bills = rows_to_dicts(cur)

                # Q14: Aggregate + NVL: Revenue by payment mode
                cur.execute("""
                    SELECT NVL(payment_mode, 'Not yet paid') AS payment_mode,
                           COUNT(*)                          AS no_of_bills,
                           SUM(total_amount)                 AS total_amount
                    FROM   v_bill_total
                    GROUP  BY NVL(payment_mode, 'Not yet paid')
                    ORDER  BY total_amount DESC
                """)
                revenue_by_mode = rows_to_dicts(cur)

                # Q13: Bills and amount by payment status
                cur.execute("""
                    SELECT payment_status,
                           COUNT(*)          AS no_of_bills,
                           SUM(total_amount) AS total_amount
                    FROM   v_bill_total
                    GROUP  BY payment_status
                """)
                bills_by_status = rows_to_dicts(cur)

                # Q24: Analytic Function: RANK() over total amount billed
                cur.execute("""
                    SELECT *
                    FROM  (SELECT p.name AS patient_name,
                                  SUM(b.total_amount) AS total_billed,
                                  RANK() OVER (ORDER BY SUM(b.total_amount) DESC) AS bill_rank
                           FROM   v_bill_total b
                                  JOIN patient p ON p.patient_id = b.patient_id
                           GROUP  BY p.name)
                    WHERE bill_rank <= 5
                    ORDER BY bill_rank
                """)
                top_billed_patients = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error running billing analytics: {parse_db_error(e)}", "danger")

    return render_template(
        'admission/analytics.html',
        icu_patients=icu_patients,
        above_avg_bills=above_avg_bills,
        revenue_by_mode=revenue_by_mode,
        bills_by_status=bills_by_status,
        top_billed_patients=top_billed_patients
    )

