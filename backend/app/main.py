from fastapi import FastAPI
from dotenv import load_dotenv

from app.routers import checkin_ws,story,stats,tts
 
app = FastAPI(title="Aegis Backend")
load_dotenv()
app.include_router(checkin_ws.router)
app.include_router(story.router) 
app.include_router(stats.router)
app.include_router(tts.router)
@app.get("/health")
def health():
    return {"status": "ok"}
 