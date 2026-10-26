import os
from flask import Flask

def create_app():
    app = Flask(__name__)
    app.secret_key = os.getenv('SECRET_KEY', 'hospital-hms-secret-key-2026')

    from app.routes.dashboard import dashboard_bp
    from app.routes.patient import patient_bp
    from app.routes.appointment import appointment_bp
    from app.routes.admission import admission_bp
    from app.routes.pharmacy import pharmacy_bp

    app.register_blueprint(dashboard_bp)
    app.register_blueprint(patient_bp, url_prefix='/patients')
    app.register_blueprint(appointment_bp, url_prefix='/appointments')
    app.register_blueprint(admission_bp, url_prefix='/admissions')
    app.register_blueprint(pharmacy_bp, url_prefix='/pharmacy')

    return app

