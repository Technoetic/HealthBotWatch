"""FastAPI 라우터 — stateless, HealthBot iOS 전용"""
import json
import logging

from fastapi import Request, HTTPException
from pydantic import BaseModel
from telegram import Bot
from typing import Optional

import time
import store
from config import TELEGRAM_TOKEN, ALERT_COOLDOWN_MINUTES
from utils import now_kst
from health.analyzer import analyze_health
from health.alerts import detect_alerts, is_crisis
from app.routers.websocket import emit_pipeline_event, manager as ws_manager

logger = logging.getLogger(__name__)


class HealthData(BaseModel):
    token: str
    timestamp: Optional[str] = None
    # 나머지 필드는 동적으로 처리


def register_routes(app):

    @app.get("/")
    async def root():
        return {"status": "ok", "service": "health-care-bot"}

    @app.get("/health-check")
    async def health_check():
        return {"status": "ok", "timestamp": now_kst().isoformat()}

    @app.get("/pending")
    async def check_pending(token: str = ""):
        """iPhone 앱이 폴링: 대기 중인 요청 확인"""
        chat_id = store.registered_users.get(token)
        if not chat_id:
            return {"pending": False, "query": None}
        # 쿼리 요청이 있으면 쿼리 반환
        if chat_id in store.pending_queries:
            q = store.pending_queries[chat_id]
            return {"pending": True, "query": q}
        # 일반 전송 요청
        if chat_id in store.pending_requests:
            return {"pending": True, "query": None}
        return {"pending": False, "query": None}

    @app.post("/pending")
    async def set_pending(token: str = ""):
        chat_id = store.registered_users.get(token)
        if not chat_id:
            raise HTTPException(status_code=401, detail="Invalid token")
        store.pending_requests.add(chat_id)
        return {"status": "ok", "message": "Pending request set"}

    @app.post("/api/now")
    async def trigger_now(token: str = ""):
        """외부에서 /now 트리거 — Telethon으로 사용자처럼 /now 입력"""
        chat_id = store.registered_users.get(token)
        if not chat_id:
            raise HTTPException(status_code=401, detail="Invalid token")
        store.pending_requests.add(chat_id)

        # Telethon 사용자 클라이언트로 봇에게 /now 전송 (사용자가 직접 친 것처럼)
        import main as _main
        if _main._telethon_client and _main._telethon_client.is_connected():
            try:
                from config import BOT_USERNAME
                await _main._telethon_client.send_message(BOT_USERNAME, "/now")
                return {"status": "ok", "method": "telethon"}
            except Exception as e:
                logger.warning(f"Telethon send failed: {e}")

        # Telethon 실패 시 봇으로 직접 메시지
        bot = Bot(token=TELEGRAM_TOKEN)
        await bot.send_message(chat_id=chat_id, text="📱 HealthKit에서 건강 데이터를 요청합니다. 잠시 후 도착합니다...")
        return {"status": "ok", "method": "bot"}

    @app.post("/api/send")
    async def send_message_as_user(request: Request):
        """GUI에서 입력한 메시지를 Telethon으로 봇에게 전송 (사용자처럼)"""
        try:
            body = await request.json()
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid JSON")
        message = body.get("message", "").strip()
        if not message:
            raise HTTPException(status_code=400, detail="Empty message")

        import main as _main
        if _main._telethon_client and _main._telethon_client.is_connected():
            try:
                from config import BOT_USERNAME
                await _main._telethon_client.send_message(BOT_USERNAME, message)
                return {"status": "ok", "method": "telethon"}
            except Exception as e:
                logger.warning(f"Telethon send failed: {e}")
                raise HTTPException(status_code=500, detail=str(e))

        raise HTTPException(status_code=503, detail="Telethon client not connected")

    @app.get("/api/last-record")
    async def get_last_record(token: str = ""):
        """마지막 수신 건강 데이터 조회"""
        chat_id = store.registered_users.get(token)
        if not chat_id:
            return {"error": "Invalid token"}
        return store.last_record.get(chat_id, {})

    @app.post("/health")
    async def receive_health_data(request: Request):
        """iPhone에서 건강 데이터 수신 → AI 분석 → 텔레그램 전송"""
        try:
            body = await request.json()
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid JSON")

        token = body.get("token", "")
        chat_id = store.registered_users.get(token)
        if not chat_id:
            raise HTTPException(status_code=401, detail="Invalid token")

        record = {k: v for k, v in body.items() if k != "token" and v is not None}
        if len(record) <= 1:
            return {"status": "ok", "message": "No health data provided"}

        store.pending_requests.discard(chat_id)
        store.last_record[chat_id] = record
        logger.info(f"Health data received for {chat_id}: {list(record.keys())}")
        ts = now_kst().isoformat()

        # LongRun 앱에 워치 데이터 포워딩
        try:
            import httpx
            user_email = None
            for t, cid in store.registered_users.items():
                if cid == chat_id:
                    # 토큰에서 이메일 추출 불가 → DB에서 조회 필요
                    # 간단히: store에 email 매핑이 있으면 사용
                    user_email = store.user_emails.get(chat_id)
                    break
            if user_email:
                forward_data = {**record, "email": user_email}
                async with httpx.AsyncClient() as client:
                    await client.post(
                        "https://ravishing-grace-production.up.railway.app/api/watch-data",
                        json=forward_data, timeout=5
                    )
                logger.info(f"Forwarded to LongRun: {user_email}")
        except Exception as e:
            logger.warning(f"LongRun forward failed: {e}")

        # WebSocket에 실시간 건강 데이터 브로드캐스트
        await ws_manager.broadcast({"event": "health_data", "record": record})
        t0 = time.time()

        # Stage 1: data_receive
        await emit_pipeline_event("pipeline_stage", "processing", "data_receive", 0, ts)
        await emit_pipeline_event("pipeline_stage", "done", "data_receive", int((time.time()-t0)*1000), ts)

        # Stage 2: token_auth
        t1 = time.time()
        await emit_pipeline_event("pipeline_stage", "processing", "token_auth", 0, ts)
        await emit_pipeline_event("pipeline_stage", "done", "token_auth", int((time.time()-t1)*1000), ts)

        if chat_id in store.paused_users:
            return {"status": "ok", "message": "Data received (paused)"}

        # 질문 대기 중이면 자동 리포트 억제 (handlers.py에서 LLM 답변을 별도 생성)
        if chat_id in store.suppress_auto_report:
            logger.info(f"Auto-report suppressed for {chat_id} (question pending)")
            return {"status": "ok", "message": "Data received (auto-report suppressed)"}

        bot = Bot(token=TELEGRAM_TOKEN)

        # Stage 3: data_parse
        t2 = time.time()
        await emit_pipeline_event("pipeline_stage", "processing", "data_parse", 0, ts)
        await emit_pipeline_event("pipeline_stage", "done", "data_parse", int((time.time()-t2)*1000), ts)

        # Stage 4: crisis_detect
        t3 = time.time()
        await emit_pipeline_event("pipeline_stage", "processing", "crisis_detect", 0, ts)
        crisis = is_crisis(record)
        await emit_pipeline_event("pipeline_stage", "done", "crisis_detect", int((time.time()-t3)*1000), ts)

        if crisis:
            await bot.send_message(
                chat_id=chat_id,
                text="🆘 생체 신호에서 급격한 이상이 감지되었습니다.\n\n긴급 연락: 119 (구급) / 112 (경찰)"
            )
            return {"status": "ok", "message": "Crisis alert sent"}

        # Stage 5: throttle_check
        t4 = time.time()
        await emit_pipeline_event("pipeline_stage", "processing", "throttle_check", 0, ts)
        alerts = detect_alerts(record, chat_id)
        if alerts:
            last_alert = store.alert_cooldown.get(chat_id)
            now = now_kst()
            if last_alert is None or (now - last_alert).total_seconds() >= ALERT_COOLDOWN_MINUTES * 60:
                await bot.send_message(chat_id=chat_id, text="🚨 건강 이상 감지\n\n" + "\n".join(alerts))
                store.alert_cooldown[chat_id] = now
        await emit_pipeline_event("pipeline_stage", "done", "throttle_check", int((time.time()-t4)*1000), ts)

        # Stage 6: prompt_build
        t5 = time.time()
        await emit_pipeline_event("pipeline_stage", "processing", "prompt_build", 0, ts)
        await emit_pipeline_event("pipeline_stage", "done", "prompt_build", int((time.time()-t5)*1000), ts)

        # Stage 7: llm_call
        t6 = time.time()
        await emit_pipeline_event("pipeline_stage", "processing", "llm_call", 0, ts)
        try:
            care_msg = await analyze_health(record, [])
            await emit_pipeline_event("pipeline_stage", "done", "llm_call", int((time.time()-t6)*1000), ts)

            # Stage 8: markdown_strip
            t7 = time.time()
            await emit_pipeline_event("pipeline_stage", "processing", "markdown_strip", 0, ts)
            await emit_pipeline_event("pipeline_stage", "done", "markdown_strip", int((time.time()-t7)*1000), ts)

            # Stage 9: telegram_send
            t8 = time.time()
            await emit_pipeline_event("pipeline_stage", "processing", "telegram_send", 0, ts)
            # HTML 출처 포맷
            from health.papers import search_papers as _search, format_paper_citation as _fmt
            papers = _search("건강 데이터 분석", record)
            html_msg = care_msg.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            html_msg = f"⌚ <b>건강 케어 리포트</b>\n\n{html_msg}"
            if papers:
                html_msg += "\n\n———————————\n<b>📚 출처</b>\n"
                for i, p in enumerate(papers, 1):
                    html_msg += f"{i}. <i>{_fmt(p)}</i>\n"
            try:
                await bot.send_message(chat_id=chat_id, text=html_msg, parse_mode="HTML")
            except Exception:
                await bot.send_message(chat_id=chat_id, text=f"⌚ 건강 케어 리포트\n\n{care_msg}")
            await emit_pipeline_event("pipeline_stage", "done", "telegram_send", int((time.time()-t8)*1000), ts)
            await ws_manager.broadcast({"event": "llm_reply", "reply": care_msg})
        except Exception as e:
            logger.error(f"AI analysis failed: {e}")
            await emit_pipeline_event("pipeline_stage", "error", "llm_call", int((time.time()-t6)*1000), ts)

        # 완료
        await emit_pipeline_event("pipeline_complete", "done", "all", int((time.time()-t0)*1000), ts)
        return {"status": "ok", "message": "Data received and processed"}

    @app.post("/health/watch")
    async def receive_watch_data(request: Request):
        """워치에서 직접 전송 → /health로 포워딩"""
        return await receive_health_data(request)

    @app.post("/health/query-response")
    async def receive_query_response(request: Request):
        """iPhone이 쿼리 결과를 전송 → AI 분석 → 텔레그램 응답"""
        try:
            body = await request.json()
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid JSON")

        token = body.get("token", "")
        chat_id = store.registered_users.get(token)
        if not chat_id:
            raise HTTPException(status_code=401, detail="Invalid token")

        query_info = store.pending_queries.pop(chat_id, {})
        original_query = query_info.get("query", "건강 데이터 조회")
        records = body.get("records", [])

        logger.info(f"Query response for {chat_id}: query='{original_query}', records={len(records)}")

        if not records:
            bot = Bot(token=TELEGRAM_TOKEN)
            await bot.send_message(chat_id=chat_id, text="📭 요청한 기간에 건강 데이터가 없습니다.")
            return {"status": "ok"}

        # AI 분석 with 원래 질문 컨텍스트
        from config import ai, MODEL

        data_text = json.dumps(records, ensure_ascii=False, indent=2)
        if len(data_text) > 3000:
            data_text = data_text[:3000] + "\n...(truncated)"

        try:
            response = ai.chat.completions.create(
                model=MODEL,
                messages=[{
                    "role": "user",
                    "content": (
                        f"사용자 질문: {original_query}\n\n"
                        f"HealthKit 데이터 ({len(records)}개 레코드):\n{data_text}\n\n"
                        "위 데이터를 바탕으로 사용자 질문에 답하세요. "
                        "3~5문장, 이모지 포함, 마크다운 금지. "
                        "수치를 구체적으로 언급하고 트렌드가 있으면 알려주세요."
                    )
                }],
                max_tokens=300,
                temperature=0.3
            )
            answer = response.choices[0].message.content
        except Exception as e:
            logger.error(f"AI query analysis failed: {e}")
            answer = f"데이터 {len(records)}건 수신. AI 분석 중 오류 발생."

        bot = Bot(token=TELEGRAM_TOKEN)
        await bot.send_message(chat_id=chat_id, text=f"📊 조회 결과\n\n{answer}")
        return {"status": "ok"}
