from flask import Blueprint, render_template, flash
from app.db import get_db, rows_to_dicts, parse_db_error

dashboard_bp = Blueprint('dashboard', __name__)

@dashboard_bp.route('/')
def index():
    stats = {
        'patients': 0,
        'active_admissions': 0,
        'pending_bills': 0,
        'pending_amount': 0,
        'available_rooms': 0,
        'doctors': 0
    }
    room_summary = []
    dept_summary = []
    recent_appts = []

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Total patients
                cur.execute("SELECT COUNT(*) FROM patient")
                stats['patients'] = cur.fetchone()[0]

                # Active admissions
                cur.execute("SELECT COUNT(*) FROM admission WHERE discharge_date IS NULL")
                stats['active_admissions'] = cur.fetchone()[0]

                # Pending bills & amount
                cur.execute("SELECT COUNT(*), NVL(SUM(total_amount), 0) FROM v_bill_total WHERE payment_status = 'Pending'")
                p_row = cur.fetchone()
                stats['pending_bills'] = p_row[0]
                stats['pending_amount'] = p_row[1]

                # Available rooms
                cur.execute("SELECT COUNT(*) FROM room WHERE status = 'Available'")
                stats['available_rooms'] = cur.fetchone()[0]

                # Total doctors
                cur.execute("SELECT COUNT(*) FROM doctor")
                stats['doctors'] = cur.fetchone()[0]

                # Q12: Room summary with CASE
                cur.execute("""
                    SELECT room_type,
                           MIN(charge_per_day) AS daily_charge,
                           COUNT(*) AS total_rooms,
                           SUM(CASE WHEN status = 'Available'   THEN 1 ELSE 0 END) AS available,
                           SUM(CASE WHEN status = 'Occupied'    THEN 1 ELSE 0 END) AS occupied,
                           SUM(CASE WHEN status = 'Maintenance' THEN 1 ELSE 0 END) AS maintenance
                    FROM   room
                    GROUP  BY room_type
                    ORDER  BY daily_charge
                """)
                room_summary = rows_to_dicts(cur)

                # Q8: Dept summary with outer join + AVG/MAX
                cur.execute("""
                    SELECT dep.dept_name, dep.location,
                           COUNT(doc.doctor_id)                        AS doctors,
                           NVL(ROUND(AVG(doc.consultation_fee), 2), 0) AS avg_fee,
                           NVL(MAX(doc.consultation_fee), 0)           AS max_fee
                    FROM   department dep
                           LEFT JOIN doctor doc ON doc.dept_id = dep.dept_id
                    GROUP  BY dep.dept_name, dep.location
                    ORDER  BY doctors DESC, dep.dept_name
                """)
                dept_summary = rows_to_dicts(cur)

                # Recent appointments (Q3 limited)
                cur.execute("""
                    SELECT a.appointment_id, a.appt_date, a.appt_time,
                           p.name AS patient_name, d.name AS doctor_name, a.status
                    FROM   appointment a
                           JOIN patient p ON p.patient_id = a.patient_id
                           JOIN doctor  d ON d.doctor_id  = a.doctor_id
                    ORDER  BY a.appt_date DESC, a.appt_time DESC
                    FETCH FIRST 5 ROWS ONLY
                """)
                recent_appts = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading dashboard data: {parse_db_error(e)}", "danger")

    return render_template(
        'index.html',
        stats=stats,
        room_summary=room_summary,
        dept_summary=dept_summary,
        recent_appts=recent_appts
    )

