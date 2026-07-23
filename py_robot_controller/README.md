# Python Robot Controller

`robot_controller` を Pygame へ移植した実装です。超音波測距を使う占有グリッド、キーボード操縦、Arduino との UDP 通信を備えています。シミュレーション機能は含みません。Python 3.14 でも起動できるよう、互換 API の `pygame-ce` を利用します（コード上の import は `pygame` のままです）。

## 起動

```powershell
cd py_robot_controller
python -m pip install -r requirements.txt
python app.py
```

起動時に接続画面が開きます。IP アドレスと UDP ポートを設定して `Enter` を押すと、実機へ接続します。

- 操縦: `W` / `A` / `S` / `D` または矢印キー
- 接続画面: `Esc`
- 接続画面の操作: `Tab`、`Enter`

UDP では、左右モーターの速度を little-endian の 32-bit 整数 2 個として送信し、受信した little-endian IEEE 754 float を距離（m）として扱います。Godot 版と同じ通信形式です。
