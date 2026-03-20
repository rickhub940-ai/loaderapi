from flask import Flask, request
import secrets

app = Flask(__name__)

# 🔐 สร้าง token ตอนรัน (เปลี่ยนทุกครั้ง)
TOKEN = secrets.token_hex(16)
print("YOUR TOKEN:", TOKEN)

# =========================
# 🌐 หน้าเว็บ
# =========================
@app.route("/")
def home():
    key = request.args.get("key")

    if key != TOKEN:
        return """
        <html>
        <body style="background:black;color:white;text-align:center;padding-top:100px;">
            <h1>Access Denied</h1>
        </body>
        </html>
        """

    return """
    <html>
    <head>
        <title>009 Loader</title>
    </head>
    <body style="background:#0f172a;color:white;text-align:center;padding-top:100px;">
        <h1>ดูหาพ่อมึงหรอ 😂</h1>
        <p>สร้างโดย 009.exe</p>
    </body>
    </html>
    """

# =========================
# 📜 script endpoint
# =========================
latest_script = 'print("HELLO WORLD")'

@app.route("/script")
def script():
    key = request.args.get("key")

    if key != TOKEN:
        return "print('No Access')"

    return latest_script


# =========================
# 🚀 run server
# =========================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
