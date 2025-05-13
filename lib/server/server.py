import os
import time
import json
import sqlite3
import hashlib
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from ultralytics import YOLO

app = Flask(__name__)
CORS(app)

# --- path setup ---
BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
DB_PATH     = os.path.join(BASE_DIR, 'users.db')
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, '..', '..'))
REPORTS_DIR = os.path.join(PROJECT_ROOT, 'reports')
IMAGES_DIR  = os.path.join(PROJECT_ROOT, 'images')

os.makedirs(IMAGES_DIR, exist_ok=True)

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()

    # create users & reports as before…
    conn.execute("""
      CREATE TABLE IF NOT EXISTS users (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT    NOT NULL,
        surname   TEXT    NOT NULL,
        age       INTEGER,
        city      TEXT,
        phone     TEXT    UNIQUE,
        email     TEXT    UNIQUE,
        password  TEXT    NOT NULL
      )
    """)
    conn.execute("""
      CREATE TABLE IF NOT EXISTS reports (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        issues      TEXT    NOT NULL,
        details     TEXT,
        location    TEXT,
        image_path  TEXT,
        status      TEXT    DEFAULT 'Pending',
        likes       INTEGER DEFAULT 0, 
        created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    """)

    # new: a table to track which user liked which report, exactly once
    conn.execute("""
      CREATE TABLE IF NOT EXISTS report_likes (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id  INTEGER NOT NULL,
        user_id    INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(report_id, user_id),
        FOREIGN KEY(report_id) REFERENCES reports(id),
        FOREIGN KEY(user_id)   REFERENCES users(id)
      )
    """)

    conn.commit()
    conn.close()

# load your YOLO model once
model = YOLO(os.path.join(BASE_DIR, "best.pt"))
init_db()

@app.route('/like_report', methods=['POST'])
def like_report_global():
    data = request.json or {}
    rid = data.get('report_id')
    if not rid:
        return jsonify(error="report_id required"), 400

    conn = get_db_connection()
    conn.execute('UPDATE reports SET likes = likes + 1 WHERE id = ?', (rid,))
    conn.commit()
    # return new count:
    new_count = conn.execute('SELECT likes FROM reports WHERE id = ?', (rid,)).fetchone()['likes']
    conn.close()
    return jsonify(report_id=rid, likes=new_count), 200

# — serve images from disk —
@app.route('/images/<path:filename>')
def serve_image(filename):
    return send_from_directory(IMAGES_DIR, filename)


# — register / login (unchanged) —
@app.route('/register', methods=['POST'])
def register():
    data = request.json or {}
    required = ['name','surname','age','city','phone','email','password']
    if not all(k in data for k in required):
        return jsonify(error="Missing registration fields"), 400

    try:
        conn = get_db_connection()
        conn.execute('''
          INSERT INTO users (name,surname,age,city,phone,email,password)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
          data['name'], data['surname'], data['age'], data['city'],
          data['phone'], data['email'],
          hashlib.sha256(data['password'].encode()).hexdigest()
        ))
        conn.commit()
        conn.close()
        return jsonify(message="User created"), 201
    except sqlite3.IntegrityError:
        return jsonify(error="Phone or Email already registered"), 409

@app.route('/login', methods=['POST'])
def login():
    # Try JSON first, fall back to form data
    if request.is_json:
        data = request.get_json()
    else:
        data = request.form.to_dict()

    # Now data will have your fields whether you sent JSON or form‐urlencoded
    if not (('email' in data or 'phone' in data) and 'password' in data):
        return jsonify(error="Missing login fields"), 400

    conn = get_db_connection()
    if 'email' in data:
        user = conn.execute(
            'SELECT * FROM users WHERE email=?', (data['email'],)
        ).fetchone()
    else:
        user = conn.execute(
            'SELECT * FROM users WHERE phone=?', (data['phone'],)
        ).fetchone()
    conn.close()

    if user and user['password'] == hashlib.sha256(
         data['password'].encode()
    ).hexdigest():
        return jsonify(message="Login successful", user=dict(user)), 200
    else:
        return jsonify(error="Invalid credentials"), 401



# — object detection (unchanged) —
@app.route('/analyze', methods=['POST'])
def analyze():
    if 'image' not in request.files:
        return jsonify(error="No image"), 400

    f = request.files['image']
    tmp = os.path.join(BASE_DIR, 'temp.jpg')
    f.save(tmp)

    results = model.predict(tmp)
    names   = model.names

    boxes = []
    labels = []
    for b in results[0].boxes:
        cls = int(b.cls[0])
        x1,y1,x2,y2 = map(int, b.xyxy[0])
        boxes.append(dict(label=names[cls], x1=x1,y1=y1,x2=x2,y2=y2))
        labels.append(names[cls])

    os.remove(tmp)

    if labels:
        return jsonify(
          detected_issue=', '.join(labels),
          suggestion='Detected: ' + ', '.join(labels),
          boxes=boxes
        )
    else:
        return jsonify(
          detected_issue='Nothing',
          suggestion='No issues found',
          boxes=[]
        )


# — report submission with image —
@app.route('/submit_report', methods=['POST'])
def submit_report():
    # you must send a multipart/form-data with:
    #   image      file
    #   user_id    text
    #   issues     JSON-encoded string of list
    #   details    text
    #   location   text

    if 'image' not in request.files:
        return jsonify(error="Image missing"), 400
    image    = request.files['image']
    user_id  = request.form.get('user_id')
    issues   = request.form.get('issues')
    details  = request.form.get('details')
    location = request.form.get('location')

    if not (user_id and issues and details is not None and location is not None):
        return jsonify(error="Missing form fields"), 400

    ts = int(time.time())
    ext = os.path.splitext(image.filename)[1] or '.jpg'
    fname = f"report_{ts}{ext}"
    image.save(os.path.join(IMAGES_DIR, fname))

    img_url = "/images/" + fname


    conn = get_db_connection()
    conn.execute('''
      INSERT INTO reports (user_id, issues, details, location, image_path)
      VALUES (?, ?, ?, ?, ?)
    ''', (
      int(user_id),
      issues,
      details,
      location,
      img_url
    ))
    conn.commit()
    conn.close()

    # optional JSON backup
    backup = dict(
      user_id   = user_id,
      issues    = json.loads(issues),
      details   = details,
      location  = location,
      image_path= img_url
    )
    with open(os.path.join(REPORTS_DIR, f"report_{ts}.json"), 'w') as bf:
        json.dump(backup, bf)

    return jsonify(message="Report saved", image_path=img_url), 201


@app.route('/reports/<int:report_id>/like', methods=['POST'])
def like_report(report_id):
    # Try JSON first, otherwise fall back to form data or query string
    data = request.get_json(silent=True) or request.form.to_dict() or {}
    user_id = data.get('user_id') or request.args.get('user_id')
    if not user_id:
        return jsonify(error="user_id required"), 400

    conn = get_db_connection()
    try:
        conn.execute(
          "INSERT INTO report_likes (report_id, user_id) VALUES (?, ?)",
          (report_id, int(user_id))
        )
    except sqlite3.IntegrityError:
        # Already liked
        cur = conn.execute(
          "SELECT likes FROM reports WHERE id = ?", (report_id,)
        ).fetchone()
        conn.close()
        return jsonify(id=report_id, likes=cur['likes']), 200

    conn.execute("UPDATE reports SET likes = likes + 1 WHERE id = ?", (report_id,))
    conn.commit()
    new_likes = conn.execute(
      "SELECT likes FROM reports WHERE id = ?", (report_id,)
    ).fetchone()['likes']
    conn.close()
    return jsonify(id=report_id, likes=new_likes), 201


@app.route('/reports/<int:report_id>/status', methods=['PUT'])
def update_report_status(report_id):
    data = request.get_json(silent=True) or {}
    new_status = data.get('status')
    if new_status not in ('pending', 'solving', 'done'):
        return jsonify(error='Invalid status'), 400

    conn = get_db_connection()
    conn.execute(
      'UPDATE reports SET status = ? WHERE id = ?',
      (new_status, report_id)
    )
    conn.commit()
    conn.close()
    return jsonify(success=True), 200

# — list all reports —
@app.route('/reports', methods=['GET'])
def list_reports():
    conn = get_db_connection()
    rows = conn.execute('''
       SELECT
         r.id, r.user_id, u.name, u.surname,
         r.issues, r.details, r.location, r.image_path,
         r.status, r.likes, r.created_at
      FROM reports r
       JOIN users u ON u.id = r.user_id
       ORDER BY r.created_at DESC
    ''').fetchall()
    conn.close()

    out = []
    for r in rows:
        out.append(dict(
           id         = r['id'],
           user_id    = r['user_id'],
           user_name  = f"{r['name']} {r['surname']}",
           issues     = json.loads(r['issues']),
           details    = r['details'],
           location   = r['location'],
           image_path = r['image_path'],
           status     = r['status'],
           likes      = r['likes'],
           created_at = r['created_at'],
        ))
    return jsonify(out), 200


# — your “my reports” endpoint —
@app.route('/my_reports', methods=['GET'])
def my_reports():
    uid = request.args.get('user_id')
    if not uid:
        return jsonify(error="user_id required"), 400

    conn = get_db_connection()
    rows = conn.execute('''
      SELECT
        id, issues, details, location, image_path,
        status, likes, created_at
      FROM reports
      WHERE user_id = ?
      ORDER BY created_at DESC
    ''', (uid,)).fetchall()
    conn.close()

    out = []
    for r in rows:
        out.append(dict(
          id         = r['id'],
          issues     = json.loads(r['issues']),
          details    = r['details'],
          location   = r['location'],
          image_path = r['image_path'],
          status     = r['status'],
          likes      = r['likes'],
          created_at = r['created_at'],
        ))
    return jsonify(out), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
