import os
import sys

# Add current dir to python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app

app = create_app()
app.testing = True

routes_to_test = [
    ('/', 'Dashboard'),
    ('/patients/', 'Patient List'),
    ('/patients/add', 'Patient Add Form'),
    ('/patients/analytics', 'Patient Analytics'),
    ('/appointments/', 'Appointment List'),
    ('/appointments/book', 'Appointment Book Form'),
    ('/appointments/analytics', 'Appointment Analytics'),
    ('/admissions/', 'Admissions List'),
    ('/admissions/admit', 'Admit Form'),
    ('/admissions/bills', 'Bills List'),
    ('/admissions/analytics', 'Billing Analytics'),
    ('/pharmacy/', 'Pharmacy List'),
    ('/pharmacy/add', 'Medicine Add Form'),
    ('/pharmacy/prescribe', 'Prescribe Form'),
    ('/pharmacy/revise-fees', 'Revise Fees Form'),
    ('/pharmacy/alerts', 'Stock Alerts & DBMS_OUTPUT'),
    ('/pharmacy/analytics', 'Pharmacy Analytics'),
]

with app.test_client() as client:
    failed = False
    for route, name in routes_to_test:
        resp = client.get(route)
        if resp.status_code == 200:
            print(f"[PASS] {name} ({route}) - 200 OK")
        else:
            print(f"[FAIL] {name} ({route}) - Status {resp.status_code}")
            failed = True

    if failed:
        sys.exit(1)
    print("\nAll routes passed verification successfully!")

