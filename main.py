import discord
from discord.ext import commands
import requests
import os
import threading
import time
import random
import string
from flask import Flask, request
from pymongo import MongoClient

# --- [1] ตั้งค่าระบบ และ Database ---
# ดึงค่า MONGO_URL ที่คุณเพิ่งได้มา (ใส่ใน Environment ของ Render)
MONGO_URL = os.getenv("mongodb+srv://rickhub_db:bKZ8gMHBNScgPjNa@cluster0.pqbqua6.mongodb.net/?appName=Cluster0") 
client = MongoClient(MONGO_URL)
db = client["009_Network"]
keys_col = db["keys"]       
users_col = db["users"]     
config_col = db["config"]   

MY_ID = 1426272052117241913          # !!! เปลี่ยนเป็น ID ไอดีหลักของคุณ !!!
OBF_BOT_ID = 1373818951049678928
RESET_COOLDOWN = 4 * 3600   # 4 ชั่วโมง

# --- [2] Web API (Flask) ---
app = Flask(__name__)

@app.route('/loader')
def loader_system():
    user_key = request.args.get('key')
    user_hwid = request.args.get('hwid')
    ua = request.headers.get('User-Agent', '').lower()
    
    # ป้องกันคนส่องผ่าน Browser
    if any(x in ua for x in ['mozilla', 'chrome', 'safari', 'firefox', 'edge']):
        return """
        <body style="background:#000;color:red;text-align:center;font-family:monospace;padding-top:20%;">
            <h1>เข้ามาดูหาพ่อมึงหรอ</h1>
            <p>Protected by 009.exe Security</p>
        </body>
        """, 403

    if not user_key or not user_hwid:
        return "print('❌ 009.exe: Missing Key/HWID')"

    key_data = keys_col.find_one({"key": user_key})
    if not key_data:
        return "print('❌ 009.exe: Invalid Key')"

    if time.time() > key_data["expire"]:
        return "print('❌ 009.exe: Key Expired')"

    # ระบบ Lock HWID
    if key_data["hwid"] is None:
        keys_col.update_one({"key": user_key}, {"$set": {"hwid": user_hwid}})
    elif key_data["hwid"] != user_hwid:
        return "print('❌ 009.exe: HWID Mismatch! Locked to another device.')"

    script = config_col.find_one({"id": "main_script"})
    return script["content"] if script else "print('-- No Script Found in Database')"

def run_web():
    port = int(os.environ.get("PORT", 10000))
    app.run(host='0.0.0.0', port=port)

# --- [3] Selfbot (User Token) ---
bot = commands.Bot(command_prefix=".", self_bot=True)

@bot.event
async def on_ready():
    print(f"009.exe System Online: {bot.user}")

@bot.event
async def on_message(message):
    # 1. ส่งไฟล์ .txt/.lua ไป OBF
    if message.author.id == MY_ID and isinstance(message.channel, discord.DMChannel):
        if message.attachments:
            for file in message.attachments:
                if file.filename.endswith(('.lua', '.txt')):
                    await file.save(file.filename)
                    obf_bot = await bot.fetch_user(OBF_BOT_ID)
                    await obf_bot.send(content=".obf", file=discord.File(file.filename))
                    os.remove(file.filename)
                    await message.channel.send(f"⏳ **009.exe:** ส่ง `{file.filename}` ไป OBF แล้ว...")

    # 2. รับไฟล์จาก OBF กลับมาอัปเดตเว็บ
    if message.author.id == OBF_BOT_ID and isinstance(message.channel, discord.DMChannel):
        if message.attachments:
            content = requests.get(message.attachments[0].url).text
            config_col.update_one({"id": "main_script"}, {"$set": {"content": content}}, upsert=True)
            main_user = await bot.fetch_user(MY_ID)
            await main_user.send("✅ **009.exe:** สคริปต์ Obfuscate และออนไลน์เรียบร้อย!")

    await bot.process_commands(message)

# --- [4] คำสั่งบอท (Gen, Redeem, GetScript, Reset) ---

@bot.command()
async def gen(ctx):
    if ctx.author.id != MY_ID: return
    new_key = "009-" + ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))
    expire = time.time() + (24 * 3600)
    keys_col.insert_one({"key": new_key, "expire": expire, "hwid": None, "owner_id": None})
    await ctx.send(f"🔑 **Generated Key:** `{new_key}`")

@bot.command()
async def redeem(ctx, key: str):
    k_data = keys_col.find_one({"key": key})
    if k_data and k_data["owner_id"] is None:
        keys_col.update_one({"key": key}, {"$set": {"owner_id": ctx.author.id}})
        await ctx.send(f"✅ **Redeem Success!** ขอบคุณที่ใช้บริการ 009.exe")
    else:
        await ctx.send("❌ คีย์ไม่ถูกต้อง หรือถูกใช้งานไปแล้ว")

@bot.command()
async def getscript(ctx):
    k_data = keys_col.find_one({"owner_id": ctx.author.id})
    if k_data:
        api_url = f"https://{request.host}/loader"
        loader = f'_G.key = "{k_data["key"]}"\nloadstring(game:HttpGet("{api_url}?key={k_data["key"]}&hwid="..game:GetService("RbxAnalyticsService"):GetClientId()))()'
        await ctx.send(f"📜 **Your Loader:**\n```lua\n{loader}\n```")
    else:
        await ctx.send("❌ คุณยังไม่ได้ Redeem คีย์!")

@bot.command()
async def reset(ctx):
    user_data = users_col.find_one({"discord_id": ctx.author.id})
    last_reset = user_data["last_reset"] if user_data else 0
    if time.time() - last_reset < RESET_COOLDOWN:
        remain = int((RESET_COOLDOWN - (time.time() - last_reset)) / 60)
        await ctx.send(f"⏳ **Cooldown:** โปรดรออีก {remain} นาที")
    else:
        keys_col.update_one({"owner_id": ctx.author.id}, {"$set": {"hwid": None}})
        users_col.update_one({"discord_id": ctx.author.id}, {"$set": {"last_reset": time.time()}}, upsert=True)
        await ctx.send("✅ **HWID Reset!** เปลี่ยนเครื่องรันได้แล้ว")

if __name__ == "__main__":
    threading.Thread(target=run_web).start()
    bot.run(os.getenv("MTQ3ODA1ODY4ODQ3NTI5OTk3MQ.GAuOrR.DBcA3FxGs93kzlcMbUO4hLFW0e06t4hdzT7fkg"))
