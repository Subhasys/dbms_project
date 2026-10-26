import os
from app import create_app

app = create_app()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    print(f"Hospital Management System running at http://localhost:{port}")
    app.run(host='0.0.0.0', port=port, debug=True)

