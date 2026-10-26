import os
import re
from contextlib import contextmanager
import oracledb
from dotenv import load_dotenv

# Ensure secrets.env is loaded from project root
env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'secrets.env')
if os.path.exists(env_path):
    load_dotenv(env_path)
else:
    load_dotenv()

_pool = None

def get_pool():
    global _pool
    if _pool is None:
        user = os.getenv('DB_USER', 'SYSTEM')
        password = os.getenv('DB_PASSWORD')
        dsn = os.getenv('DB_DSN', 'localhost:1521/xe')
        _pool = oracledb.create_pool(
            user=user,
            password=password,
            dsn=dsn,
            min=1,
            max=5,
            increment=1
        )
    return _pool

@contextmanager
def get_db():
    conn = get_pool().acquire()
    try:
        yield conn
    finally:
        conn.close()

def parse_db_error(e: Exception) -> str:
    """Format Oracle error into a clean, human-readable message."""
    msg = str(e)
    # Check if there is an ORA-20xxx or standard ORA error
    match = re.search(r'ORA-(\d+):\s*([^\n\r]+)', msg)
    if match:
        err_code, err_text = match.group(1), match.group(2)
        # Check for ORA-00001 unique constraint
        if err_code == '00001':
            return "Duplicate entry detected: a record with these unique details already exists."
        elif err_code == '02292':
            return "Cannot delete or alter this record because related records depend on it."
        elif err_code == '02291':
            return "Referenced record does not exist."
        return err_text
    return msg

def rows_to_dicts(cursor):
    """Convert cursor results to a list of dicts with lowercase keys."""
    columns = [col[0].lower() for col in cursor.description] if cursor.description else []
    return [dict(zip(columns, row)) for row in cursor.fetchall()]

