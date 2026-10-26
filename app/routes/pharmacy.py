from datetime import datetime, date
from flask import Blueprint, render_template, request, redirect, url_for, flash
import oracledb
from app.db import get_db, rows_to_dicts, parse_db_error

pharmacy_bp = Blueprint('pharmacy', __name__)

@pharmacy_bp.route('/')
def list_medicines():
    search = request.args.get('search', '').strip()
    status_filter = request.args.get('status', '').strip()

    # Q22: Date function + CASE for shelf status
    query = """
        SELECT medicine_id, medicine_name, manufacturer, unit_price, stock_qty, expiry_date,
               TRUNC(expiry_date - SYSDATE) AS days_left,
               CASE WHEN expiry_date < SYSDATE               THEN 'EXPIRED'
                    WHEN expiry_date <= ADD_MONTHS(SYSDATE,3) THEN 'EXPIRING SOON'
                    ELSE 'OK'
               END AS shelf_status
        FROM   medicine
        WHERE  1=1
    """
    params = {}
    if search:
        query += " AND (UPPER(medicine_name) LIKE :search OR UPPER(manufacturer) LIKE :search)"
        params['search'] = f"%{search.upper()}%"
    if status_filter:
        if status_filter == 'EXPIRED':
            query += " AND expiry_date < SYSDATE"
        elif status_filter == 'EXPIRING SOON':
            query += " AND expiry_date >= SYSDATE AND expiry_date <= ADD_MONTHS(SYSDATE, 3)"
        elif status_filter == 'LOW STOCK':
            query += " AND stock_qty < 50"

    query += " ORDER BY expiry_date, medicine_name"

    medicines = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                medicines = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error fetching medicines: {parse_db_error(e)}", "danger")

    return render_template('pharmacy/list.html', medicines=medicines, search=search, status_filter=status_filter)

@pharmacy_bp.route('/add', methods=['GET', 'POST'])
def add_medicine():
    if request.method == 'POST':
        try:
            name = request.form.get('medicine_name', '').strip()
            manufacturer = request.form.get('manufacturer', '').strip()
            unit_price = float(request.form.get('unit_price'))
            stock_qty = int(request.form.get('stock_qty'))
            expiry_str = request.form.get('expiry_date')
            expiry_date = datetime.strptime(expiry_str, '%Y-%m-%d').date()

            with get_db() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT seq_medicine.NEXTVAL FROM dual")
                    med_id = cur.fetchone()[0]

                    cur.execute("""
                        INSERT INTO medicine (medicine_id, medicine_name, manufacturer, unit_price, stock_qty, expiry_date)
                        VALUES (:id, :name, :mfg, :price, :stock, :expiry)
                    """, {
                        'id': med_id,
                        'name': name,
                        'mfg': manufacturer,
                        'price': unit_price,
                        'stock': stock_qty,
                        'expiry': expiry_date
                    })
                conn.commit()
                flash(f"Medicine '{name}' added with ID #{med_id}!", "success")
                return redirect(url_for('pharmacy.list_medicines'))
        except Exception as e:
            flash(f"Failed to add medicine: {parse_db_error(e)}", "danger")

    return render_template('pharmacy/add.html', today=date.today().strftime('%Y-%m-%d'))

@pharmacy_bp.route('/prescribe', methods=['GET', 'POST'])
def prescribe():
    if request.method == 'POST':
        try:
            appointment_id = int(request.form.get('appointment_id'))
            medicine_id = int(request.form.get('medicine_id'))
            dosage = request.form.get('dosage', '').strip()
            duration_days = int(request.form.get('duration_days'))
            quantity = int(request.form.get('quantity'))

            with get_db() as conn:
                with conn.cursor() as cur:
                    # Procedure call: sp_prescribe_medicine
                    # Triggers trg_prescribe_update_stock to reduce inventory and check expiry/stock
                    cur.callproc('sp_prescribe_medicine', [
                        appointment_id,
                        medicine_id,
                        dosage,
                        duration_days,
                        quantity
                    ])
                conn.commit()
                flash(f"Prescription recorded! Stock successfully deducted by trigger.", "success")
                return redirect(url_for('pharmacy.list_medicines'))
        except Exception as e:
            flash(f"Prescription rejected: {parse_db_error(e)}", "danger")

    appointments = []
    medicines = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Scheduled or Completed appointments
                cur.execute("""
                    SELECT a.appointment_id, a.appt_date, a.status, p.name AS patient_name, d.name AS doctor_name
                    FROM appointment a
                    JOIN patient p ON p.patient_id = a.patient_id
                    JOIN doctor d ON d.doctor_id = a.doctor_id
                    WHERE a.status <> 'Cancelled'
                    ORDER BY a.appt_date DESC
                """)
                appointments = rows_to_dicts(cur)

                cur.execute("""
                    SELECT medicine_id, medicine_name, stock_qty, unit_price, expiry_date,
                           TRUNC(expiry_date - SYSDATE) AS days_left
                    FROM medicine
                    ORDER BY medicine_name
                """)
                medicines = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading prescription form: {parse_db_error(e)}", "danger")

    return render_template('pharmacy/prescribe.html', appointments=appointments, medicines=medicines)

@pharmacy_bp.route('/revise-fees', methods=['GET', 'POST'])
def revise_fees():
    updated_count = None
    departments = []

    if request.method == 'POST':
        try:
            dept_id = int(request.form.get('dept_id'))
            percent = float(request.form.get('percent'))

            with get_db() as conn:
                with conn.cursor() as cur:
                    # Cursor Procedure call: sp_revise_doctor_fees
                    # parameters: p_dept_id, p_percent, p_updated (OUT NUMBER)
                    out_updated = cur.var(oracledb.NUMBER)
                    cur.callproc('sp_revise_doctor_fees', [dept_id, percent, out_updated])
                    updated_count = int(out_updated.getvalue())
                conn.commit()
                flash(f"Cursor procedure executed: {updated_count} doctor consultation fee(s) revised by {percent}%!", "success")
                return redirect(url_for('pharmacy.revise_fees'))
        except Exception as e:
            flash(f"Fee revision failed: {parse_db_error(e)}", "danger")

    doctor_fees = []
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT dept_id, dept_name, location FROM department ORDER BY dept_name")
                departments = rows_to_dicts(cur)

                cur.execute("""
                    SELECT d.doctor_id, d.name, d.specialization, d.consultation_fee, dep.dept_id, dep.dept_name
                    FROM doctor d
                    JOIN department dep ON dep.dept_id = d.dept_id
                    ORDER BY dep.dept_name, d.name
                """)
                doctor_fees = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error loading departments: {parse_db_error(e)}", "danger")

    return render_template(
        'pharmacy/revise_fees.html',
        departments=departments,
        doctor_fees=doctor_fees,
        updated_count=updated_count
    )

@pharmacy_bp.route('/alerts')
def alerts():
    # Procedure sp_pharmacy_alert_report report + query
    months = int(request.args.get('months', 3))
    min_stock = int(request.args.get('min_stock', 50))

    alerts_list = []
    dbms_output_lines = []

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Query mirroring sp_pharmacy_alert_report
                cur.execute("""
                    SELECT medicine_id, medicine_name, stock_qty, unit_price, expiry_date,
                           TRUNC(expiry_date - SYSDATE) AS days_left,
                           CASE WHEN expiry_date < TRUNC(SYSDATE)                         THEN 'EXPIRED'
                                WHEN expiry_date <= ADD_MONTHS(TRUNC(SYSDATE), :m)        THEN 'EXPIRING SOON'
                                ELSE 'LOW STOCK'
                           END AS alert_type
                    FROM   medicine
                    WHERE  expiry_date <= ADD_MONTHS(TRUNC(SYSDATE), :m)
                    OR     stock_qty   <  :s
                    ORDER  BY expiry_date
                """, {'m': months, 's': min_stock})
                alerts_list = rows_to_dicts(cur)

                # Execute PL/SQL procedure sp_pharmacy_alert_report with DBMS_OUTPUT enabled
                cur.callproc("dbms_output.enable", [50000])
                cur.callproc("sp_pharmacy_alert_report", [months, min_stock])
                
                # Fetch lines from DBMS_OUTPUT
                line_var = cur.var(str)
                status_var = cur.var(int)
                while True:
                    cur.callproc("dbms_output.get_line", [line_var, status_var])
                    if status_var.getvalue() != 0:
                        break
                    val = line_var.getvalue()
                    if val is not None:
                        dbms_output_lines.append(val)
    except Exception as e:
        flash(f"Error loading alerts: {parse_db_error(e)}", "danger")

    return render_template(
        'pharmacy/alerts.html',
        alerts=alerts_list,
        dbms_output_lines=dbms_output_lines,
        months=months,
        min_stock=min_stock
    )

@pharmacy_bp.route('/<int:medicine_id>/delete', methods=['POST'])
def delete_medicine(medicine_id):
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Will raise ORA-02292 child record found if prescribed in PRESCRIBES
                cur.execute("DELETE FROM medicine WHERE medicine_id = :id", {'id': medicine_id})
            conn.commit()
            flash(f"Medicine #{medicine_id} successfully deleted from inventory.", "success")
    except Exception as e:
        flash(f"Cannot delete Medicine #{medicine_id}: {parse_db_error(e)}", "danger")

    return redirect(url_for('pharmacy.list_medicines'))

@pharmacy_bp.route('/analytics')
def analytics():
    most_prescribed = []
    line_costs = []
    appt_totals = []
    dept_stats = []
    high_fee_doctors = []

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Q10: Most prescribed medicines
                cur.execute("""
                    SELECT m.medicine_name,
                           COUNT(*)           AS times_prescribed,
                           SUM(pr.quantity)   AS total_quantity
                    FROM   prescribes pr
                           JOIN medicine m ON m.medicine_id = pr.medicine_id
                    GROUP  BY m.medicine_name
                    ORDER  BY times_prescribed DESC, total_quantity DESC
                """)
                most_prescribed = rows_to_dicts(cur)

                # Q5: 4-table join with line cost arithmetic
                cur.execute("""
                    SELECT pr.appointment_id, p.name AS patient_name, m.medicine_name,
                           pr.dosage, pr.quantity, m.unit_price,
                           pr.quantity * m.unit_price AS line_cost
                    FROM   prescribes pr
                           JOIN medicine    m ON m.medicine_id    = pr.medicine_id
                           JOIN appointment a ON a.appointment_id = pr.appointment_id
                           JOIN patient     p ON p.patient_id     = a.patient_id
                    ORDER  BY pr.appointment_id, m.medicine_name
                """)
                line_costs = rows_to_dicts(cur)

                # Q9: Aggregate medicine total per appointment
                cur.execute("""
                    SELECT pr.appointment_id, p.name AS patient_name,
                           SUM(pr.quantity * m.unit_price) AS medicine_total
                    FROM   prescribes pr
                           JOIN medicine    m ON m.medicine_id    = pr.medicine_id
                           JOIN appointment a ON a.appointment_id = pr.appointment_id
                           JOIN patient     p ON p.patient_id     = a.patient_id
                    GROUP  BY pr.appointment_id, p.name
                    ORDER  BY pr.appointment_id
                """)
                appt_totals = rows_to_dicts(cur)

                # Q8: Department doctor counts and fees
                cur.execute("""
                    SELECT dep.dept_name,
                           COUNT(doc.doctor_id)                        AS doctors,
                           NVL(ROUND(AVG(doc.consultation_fee), 2), 0) AS avg_fee,
                           NVL(MAX(doc.consultation_fee), 0)           AS max_fee
                    FROM   department dep
                           LEFT JOIN doctor doc ON doc.dept_id = dep.dept_id
                    GROUP  BY dep.dept_name
                    ORDER  BY doctors DESC, dep.dept_name
                """)
                dept_stats = rows_to_dicts(cur)

                # Q15: Doctors charging more than the average fee (Scalar subquery)
                cur.execute("""
                    SELECT doctor_id, name AS doctor_name, specialization, consultation_fee
                    FROM   doctor
                    WHERE  consultation_fee > (SELECT AVG(consultation_fee) FROM doctor)
                    ORDER  BY consultation_fee DESC
                """)
                high_fee_doctors = rows_to_dicts(cur)
    except Exception as e:
        flash(f"Error executing pharmacy analytics: {parse_db_error(e)}", "danger")

    return render_template(
        'pharmacy/analytics.html',
        most_prescribed=most_prescribed,
        line_costs=line_costs,
        appt_totals=appt_totals,
        dept_stats=dept_stats,
        high_fee_doctors=high_fee_doctors
    )

