from datetime import datetime, date
from flask import Blueprint, render_template, request, redirect, url_for, flash
import oracledb
from app.db import get_db, rows_to_dicts, parse_db_error

appointment_bp = Blueprint('appointment', __name__)

@appointment_bp.route('/')
def list_appointments():
    doctor_filter = request.args.get('doctor_id', '').strip()
    status_filter = request.args.get('status', '').strip()
    date_filter = request.args.get('date', '').strip()

    # Q3: 3-table join
    query = """
        SELECT a.appointment_id, a.appt_date, a.appt_time, a.status, a.diagnosis,
               p.patient_id, p.name AS patient_name,
               d.doctor_id, d.name AS doctor_name, d.specialization, d.consultation_fee
        FROM   appointment a
               JOIN patient p ON p.patient_id = a.patient_id
               JOIN doctor  d ON d.doctor_id  = a.doctor_id
        WHERE 1=1
    """
    params = {}
    if doctor_filter:
        query += " AND a.doctor_id = :doc_id"
        params['doc_id'] = int(doctor_filter)
    if status_filter:
        query += " AND a.status = :status"
        params['status'] = status_filter
    if date_filter:
        try:
            d_val = datetime.strptime(date_filter, '%Y-%m-%d').date()
            query += " AND a.appt_date = :d_val"
            params['d_val'] = d_val
        except ValueError:
            pass

    query += " ORDER BY a.appt_date DESC, a.appt_time DESC"

    appointments = []
    doctors = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                appointments = rows_to_dicts(cur)

                cur.execute("SELECT doctor_id, name, specialization FROM doctor ORDER BY name")
                doctors = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error fetching appointments: {parse_db_error(e)}", "danger")

    return render_template(
        'appointment/list.html',
        appointments=appointments,
        doctors=doctors,
        doctor_filter=doctor_filter,
        status_filter=status_filter,
        date_filter=date_filter
    )

@appointment_bp.route('/book', methods=['GET', 'POST'])
def book_appointment():
    prefill_patient_id = request.args.get('patient_id', '')

    if request.method == 'POST':
        try:
            patient_id = int(request.form.get('patient_id'))
            doctor_id = int(request.form.get('doctor_id'))
            appt_date_str = request.form.get('appt_date')
            appt_time = request.form.get('appt_time', '').strip()

            appt_date = datetime.strptime(appt_date_str, '%Y-%m-%d').date()

            with get_db() as conn:
                with conn.cursor() as cur:
                    # Stored Procedure call: sp_book_appointment
                    # parameters: p_patient_id, p_doctor_id, p_date, p_time, p_appointment_id (OUT NUMBER)
                    out_appt_id = cur.var(oracledb.NUMBER)
                    cur.callproc('sp_book_appointment', [
                        patient_id,
                        doctor_id,
                        appt_date,
                        appt_time,
                        out_appt_id
                    ])
                    new_id = int(out_appt_id.getvalue())
                conn.commit()
                flash(f"Appointment #{new_id} booked successfully for {appt_date.strftime('%d-%b-%Y')} at {appt_time}!", "success")
                return redirect(url_for('appointment.list_appointments'))
        except Exception as e:
            flash(f"Booking failed: {parse_db_error(e)}", "danger")

    patients = []
    doctors = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT patient_id, name, city FROM patient ORDER BY name")
                patients = rows_to_dicts(cur)
                cur.execute("""
                    SELECT d.doctor_id, d.name, d.specialization, d.consultation_fee, dep.dept_name
                    FROM doctor d
                    JOIN department dep ON dep.dept_id = d.dept_id
                    ORDER BY d.name
                """)
                doctors = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading booking form options: {parse_db_error(e)}", "danger")

    return render_template(
        'appointment/book.html',
        patients=patients,
        doctors=doctors,
        prefill_patient_id=prefill_patient_id,
        today=date.today().strftime('%Y-%m-%d')
    )

@appointment_bp.route('/<int:appointment_id>/cancel', methods=['POST'])
def cancel_appointment(appointment_id):
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Stored Procedure call: sp_cancel_appointment
                cur.callproc('sp_cancel_appointment', [appointment_id])
            conn.commit()
            flash(f"Appointment #{appointment_id} has been cancelled.", "success")
    except Exception as e:
        flash(f"Could not cancel appointment: {parse_db_error(e)}", "danger")

    return redirect(url_for('appointment.list_appointments'))

@appointment_bp.route('/<int:appointment_id>/delete', methods=['POST'])
def delete_appointment(appointment_id):
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Check status first
                cur.execute("SELECT status FROM appointment WHERE appointment_id = :id", {'id': appointment_id})
                row = cur.fetchone()
                if not row:
                    flash(f"Appointment #{appointment_id} not found.", "warning")
                    return redirect(url_for('appointment.list_appointments'))

                if row[0] != 'Cancelled':
                    flash("Only Cancelled appointments can be deleted from the system.", "warning")
                    return redirect(url_for('appointment.list_appointments'))

                cur.execute("DELETE FROM appointment WHERE appointment_id = :id AND status = 'Cancelled'", {'id': appointment_id})
            conn.commit()
            flash(f"Cancelled Appointment #{appointment_id} permanently removed.", "success")
    except Exception as e:
        flash(f"Cannot delete appointment: {parse_db_error(e)}", "danger")

    return redirect(url_for('appointment.list_appointments'))

@appointment_bp.route('/analytics')
def analytics():
    busy_doctors = []
    idle_doctors = []
    monthly_trends = []
    doctor_strings = []

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Q7: Doctors with 2+ appointments (HAVING)
                cur.execute("""
                    SELECT d.doctor_id, d.name AS doctor_name, d.specialization,
                           COUNT(*) AS total_appointments
                    FROM   appointment a
                           JOIN doctor d ON d.doctor_id = a.doctor_id
                    GROUP  BY d.doctor_id, d.name, d.specialization
                    HAVING COUNT(*) >= 2
                    ORDER  BY total_appointments DESC, d.name
                """)
                busy_doctors = rows_to_dicts(cur)

                # Q17: Doctors with NO appointments (NOT EXISTS)
                cur.execute("""
                    SELECT d.doctor_id, d.name AS doctor_name, d.specialization, dep.dept_name
                    FROM   doctor d
                           JOIN department dep ON dep.dept_id = d.dept_id
                    WHERE  NOT EXISTS (SELECT 1
                                       FROM   appointment a
                                       WHERE  a.doctor_id = d.doctor_id)
                """)
                idle_doctors = rows_to_dicts(cur)

                # Q23: TO_CHAR + GROUP BY: Appointments per month
                cur.execute("""
                    SELECT TO_CHAR(appt_date, 'YYYY-MM')                          AS appt_month,
                           COUNT(*)                                               AS total,
                           SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END)  AS completed,
                           SUM(CASE WHEN status = 'Scheduled' THEN 1 ELSE 0 END)  AS scheduled,
                           SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END)  AS cancelled
                    FROM   appointment
                    GROUP  BY TO_CHAR(appt_date, 'YYYY-MM')
                    ORDER  BY appt_month DESC
                """)
                monthly_trends = rows_to_dicts(cur)

                # Q21: SQL string functions on Doctor table
                cur.execute("""
                    SELECT UPPER(name)                              AS doctor_name,
                           LENGTH(name)                             AS name_length,
                           SUBSTR(email, 1, INSTR(email, '@') - 1)  AS username,
                           SUBSTR(email, INSTR(email, '@') + 1)     AS domain,
                           'XXXXXX' || SUBSTR(phone, -4)            AS masked_phone
                    FROM   doctor
                    ORDER  BY name
                """)
                doctor_strings = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading appointment analytics: {parse_db_error(e)}", "danger")

    return render_template(
        'appointment/analytics.html',
        busy_doctors=busy_doctors,
        idle_doctors=idle_doctors,
        monthly_trends=monthly_trends,
        doctor_strings=doctor_strings
    )

