from fastapi import FastAPI
 
from app.routers import checkin_ws,story
 
app = FastAPI(title="Aegis Backend")

app.include_router(checkin_ws.router)
app.include_router(story.router) 
 
@app.get("/health")
def health():
    return {"status": "ok"}
 