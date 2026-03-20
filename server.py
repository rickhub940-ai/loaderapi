from flask import Flask, request, redirect

app = Flask(__name__)

latest_script = 'print("HELLO")'

# 🔐 คีย์ที่อนุญาต
valid_keys = ["009", "vip123", "test"]

# 🌐 หน้าเว็บ
@app.route("/")
def home():
    return """
    <html>
    <body style="background:black;color:white;text-align:center;padding-top:120px;font-family:Arial;">
        <h1>ดูหาพ่อมึงหรอ 😂</h1>
        <p>สร้างโดย 009.exe</p>
    </body>
    </html>
    """

# 📜 script loader
@app.route("/script")
def script():
    key = request.args.get("key")
    ua = request.headers.get("User-Agent", "")

    # ❌ ไม่มี key → เด้ง
    if not key:
        return redirect("/", 302)

    # ❌ key ไม่ถูก → เด้ง
    if key not in valid_keys:
        return redirect("/", 302)

    # ❌ เปิดใน browser → เด้ง
    if "Mozilla" in ua:
        return redirect("/", 302)

    # ✅ ผ่านหมด → ส่งสคริปต์
    return latest_script


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)
