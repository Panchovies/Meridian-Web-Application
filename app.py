from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health')
def health():
    date = datetime.now(timezone.utc).isoformat()
    return jsonify({
        "status": "ok", 
        "timestamp": date,
        "message": "Service is healthy and running."
    }), 200

if __name__ == '__main__':
    app.run(debug=True)