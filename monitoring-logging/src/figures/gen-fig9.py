#!/usr/bin/env python3
"""ch03-fig9-stream-labels.svg 생성. 스트림 수 3 → 66은 course M22 실패 ③ 실측."""
SANS = "font-family:Pretendard,'Apple SD Gothic Neo',sans-serif"
MONO = "font-family:'SFMono-Regular',Consolas,monospace"
o = []
def t(x, y, s, size=24, color="#24292A", w=400, anchor="start", mono=False):
    o.append(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{w}" text-anchor="{anchor}" style="{MONO if mono else SANS};fill:{color}">{s}</text>')
def r(x, y, w, h, fill, stroke, sw=2, rx=8, dash=""):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

o.append('<line x1="800" y1="40" x2="800" y2="860" stroke="#D8DDD6" stroke-width="2"/>')

# LEFT
t(40, 70, "라벨은 적게, 값이 자주 바뀌는 것은 본문에", 30, "#0B5A54", 700)
t(40, 112, "라벨: namespace · app · pod", 22, "#5A6867", 400, mono=True)
for i, pod in enumerate(["…-fxs5p", "…-k2m9d", "…-q7wzt"]):
    y = 150 + i * 190
    r(40, y, 720, 170, "#E0EFEB", "#0F766E")
    t(62, y + 36, f'스트림 {i+1}  {{app="journal-api", pod="{pod}"}}', 20, "#0B5A54", 700, mono=True)
    for j, p in enumerate(["/api/entries?req=2", "/api/entries?req=20", "/api/entries?req=32"]):
        r(62, y + 52 + j * 36, 676, 30, "#FFFFFF", "#A7B5AC", 1, 4)
        t(76, y + 73 + j * 36, f'{{"path":"{p}","status":200 …}}', 17, "#5A6867", 400, mono=True)
t(40, 760, "journal-api 스트림 3개", 32, "#0B5A54", 700)
t(40, 800, "path는 본문 안. 질의할 때 | json 으로 꺼낸다", 24, "#5A6867")

# RIGHT
t(840, 70, "path를 라벨로 올리면", 30, "#C2414A", 700)
t(840, 112, "라벨: namespace · app · pod · path · status", 22, "#5A6867", 400, mono=True)
cols, size, gap = 11, 50, 12
for k in range(66):
    cx = 840 + (k % cols) * (size + gap)
    cy = 150 + (k // cols) * (size + gap)
    r(cx, cy, size, size, "#FCE4E6", "#C2414A", 1.5, 4)
t(840, 560, "요청 60건 → 스트림 66개", 32, "#C2414A", 700)
t(840, 600, "라벨 조합 하나 = 스트림 하나", 24, "#5A6867")
t(840, 636, "스트림마다 인덱스 항목과 청크가 따로 생긴다", 24, "#5A6867")
t(840, 700, "실서비스라면 하루 수십만 스트림", 24, "#C2414A", 700)
t(840, 736, "→ Loki 인제스터 메모리 고갈", 24, "#C2414A", 700)

t(1570, 870, "스트림 수는 실측(요청 60건 전송)", 20, "#6F7C79", 400, "end")
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" role="img" aria-labelledby="t9 d9">
  <title id="t9">라벨과 로그 본문</title>
  <desc id="d9">왼쪽: 라벨을 namespace, app, pod로 두고 path를 본문에 두면 journal-api 스트림은 파드 수만큼 3개다. 오른쪽: path를 라벨로 올리면 요청 60건이 스트림 66개를 만든다.</desc>
  <rect width="1600" height="900" fill="#FFFFFF"/>
  {"".join(o)}
</svg>
'''
open(__file__.replace("gen-fig9.py", "ch03-fig9-stream-labels.svg"), "w").write(svg)
