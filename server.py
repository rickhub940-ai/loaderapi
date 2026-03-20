from flask import Flask, request
import base64

app = Flask(__name__)

latest_script = 'print("ยังไม่มีสคริปต์")'

def obfuscate(code):
    encoded = base64.b64encode(code.encode()).decode()
    return f'''
local b="{encoded}"
local d=game:GetService("HttpService"):Base64Decode(b)
loadstring(d)()
'''

@app.route("/script")
def get_script():
    return latest_script

@app.route("/update", methods=["POST"])
def update():
    global latest_script

    if request.headers.get("x-key") != "mysecret":
        return "Forbidden", 403

    code = request.json.get("code")
    if not code:
        return "No code"

    latest_script = obfuscate(code)
    return "Updated!"

app.run(host="0.0.0.0", port=3000)
