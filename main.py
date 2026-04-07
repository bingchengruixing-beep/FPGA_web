import asyncio
import threading
import serial
import serial.tools.list_ports
import numpy as np
import json
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import time
app = FastAPI(title="Logic Analyzer Backend")

# 允许跨域请求（前端独立运行必备）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 全局状态字典
state = {
    "ser": None,
    "running": False,
    "thread": None,
    "loop": None,
    "clients": set()
}


class ControlParams(BaseModel):
    cmd: int
    div: int
    mode: int
    p1: int
    p2: int

# ================= 底层硬件读取线程 =================
def serial_reader_task():
    buffer = bytearray()
    ser = state["ser"]

    while state["running"] and ser and ser.is_open:
        try:
            if ser.in_waiting:
                buffer.extend(ser.read(ser.in_waiting))

                while len(buffer) >= 2051:
                    if buffer[0] == 0x5A and buffer[1] == 0xA5:
                        frame = buffer[2:2050]
                        checksum = buffer[2050]

                        if sum(frame) & 0xFF == checksum:
                            # NumPy 极速解包
                            raw_array = np.frombuffer(frame, dtype=np.uint8)
                            bits_matrix = np.unpackbits(raw_array.reshape(-1, 1), axis=1)[:, ::-1].T

                            # 转换为标准的 Python 嵌套列表以供 JSON 序列化
                            data_list = bits_matrix.tolist()

                            # 安全地跨线程投递到 FastAPI 的异步广播函数
                            if state["loop"] and state["clients"]:
                                asyncio.run_coroutine_threadsafe(
                                    broadcast_waveform(data_list),
                                    state["loop"]
                                )
                        # 推进缓冲池
                        buffer = buffer[2051:]
                    else:
                        buffer.pop(0)
        except Exception as e:
            print(f"串口读取致命错误: {e}")
            state["running"] = False
            break


async def broadcast_waveform(data_matrix):
    message = json.dumps({"type": "waveform", "data": data_matrix})
    dead_clients = set()
    for client in state["clients"]:
        try:
            await client.send_text(message)
        except:
            dead_clients.add(client)
    # 清理断开的连接
    for client in dead_clients:
        state["clients"].discard(client)


# ================= FastAPI 路由端点 =================
@app.on_event("startup")
async def startup_event():
    # 获取主线程的异步事件循环
    state["loop"] = asyncio.get_running_loop()


@app.get("/api/ports")
def get_ports():
    ports = [p.device for p in serial.tools.list_ports.comports()]
    return {"status": "success", "data": ports}


@app.post("/api/connect")
def connect_hardware(port: str, baudrate: int = 115200):
    if state["running"]:
        return {"status": "error", "msg": "系统已在运行中，请先断开。"}
    try:
        state["ser"] = serial.Serial(port, baudrate, timeout=0.1)
        state["running"] = True
        state["thread"] = threading.Thread(target=serial_reader_task, daemon=True)
        state["thread"].start()
        return {"status": "success", "msg": f"成功挂载硬件: {port} @ {baudrate}bps"}
    except Exception as e:
        return {"status": "error", "msg": str(e)}


@app.post("/api/disconnect")
def disconnect_hardware():
    state["running"] = False
    if state["ser"]:
        state["ser"].close()
        state["ser"] = None
    return {"status": "success", "msg": "硬件连接已安全切断"}


@app.post("/api/control")
def send_control_frame(params: ControlParams):
    ser = state["ser"]
    if not ser or not ser.is_open:
        return {"status": "error", "msg": "硬件未连接"}

    try:
        # 强制将所有传入的参数约束在 8 位无符号整数范围内 (0-255)
        cmd_byte = params.cmd & 0xFF
        div_byte = params.div & 0xFF
        mode_byte = params.mode & 0xFF
        p1_byte = params.p1 & 0xFF
        p2_byte = params.p2 & 0xFF

        # 按照 FPGA 协议组装前 7 字节
        frame = bytearray([0xAA, 0x55, cmd_byte, div_byte, mode_byte, p1_byte, p2_byte])

        # 计算第 8 字节的校验和并追加
        checksum = sum(frame) & 0xFF
        frame.append(checksum)

        # 执行物理下发
        ser.write(frame)

        # 在后端终端打印出生成的 Hex 流，用于自证与排错
        hex_str = ' '.join([f"{b:02X}" for b in frame])
        print(f"[{time.strftime('%H:%M:%S')}] 向上位机下发控制指令: {hex_str}")

        return {"status": "success", "msg": f"指令已发送: {hex_str}"}

    except Exception as e:
        return {"status": "error", "msg": f"指令组装或发送引发异常: {str(e)}"}

@app.websocket("/ws/data")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    state["clients"].add(websocket)
    try:
        while True:
            # 维持连接心跳
            await websocket.receive_text()
    except WebSocketDisconnect:
        state["clients"].discard(websocket)


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)