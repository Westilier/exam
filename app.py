import os
from flask import Flask, jsonify
import psycopg2

app = Flask(__name__)

def check_db():
    conn = psycopg2.connect(
        host=os.environ.get("DB_HOST"),
        port=6432,
        database=os.environ.get("DB_NAME"),
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD"),
        sslmode="require",
        target_session_attrs="read-write"
    )
    q = conn.cursor()
    q.execute('SELECT version()')
    q.close()

@app.route("/")
def hello():
    try:
        check_db()
        return "Гаврилов Владислав Владимирович, Шоколадная крошка"
    except:
        return "Приложение работает, но нет связи с БД"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
