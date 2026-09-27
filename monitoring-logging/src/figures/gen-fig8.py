#!/usr/bin/env python3
"""ch03-fig8-alert-timeline.svg 생성. 시각은 course M21 21.4 실측 관찰 로그."""
X0, PX = 170, 112          # 22:00:00 위치, 1분당 px
def X(hms):
    h, m, s = map(int, hms.split(":")); return X0 + ((m + s / 60) * PX)
SANS = "font-family:Pretendard,'Apple SD Gothic Neo',sans-serif"
MONO = "font-family:'SFMono-Regular',Consolas,monospace"
out = []
def rect(a, b, y, h, fill, stroke):
    out.append(f'<rect x="{X(a):.0f}" y="{y}" width="{X(b)-X(a):.0f}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="2" rx="4"/>')
def text(x, y, s, size=24, color="#24292A", w=400, anchor="start", mono=False):
    out.append(f'<text x="{x:.0f}" y="{y}" font-size="{size}" font-weight="{w}" text-anchor="{anchor}" style="{MONO if mono else SANS};fill:{color}">{s}</text>')
def vline(t, y1, y2, color, dash=True):
    d = ' stroke-dasharray="8 6"' if dash else ""
    out.append(f'<line x1="{X(t):.0f}" y1="{y1}" x2="{X(t):.0f}" y2="{y2}" stroke="{color}" stroke-width="2"{d}/>')
def bracket(a, b, y, label, sub, color):
    xa, xb = X(a), X(b)
    out.append(f'<path d="M{xa:.0f} {y-12} L{xa:.0f} {y} L{xb:.0f} {y} L{xb:.0f} {y-12}" stroke="{color}" stroke-width="2.5" fill="none"/>')
    text((xa + xb) / 2, y + 34, label, 25, color, 700, "middle")
    text((xa + xb) / 2, y + 66, sub, 21, "#5A6867", 400, "middle")

# time axis
out.append(f'<line x1="{X0}" y1="120" x2="{X("22:12:00"):.0f}" y2="120" stroke="#A7B5AC" stroke-width="2"/>')
for m in range(0, 13, 2):
    t = f"22:{m:02d}:00"
    out.append(f'<line x1="{X(t):.0f}" y1="112" x2="{X(t):.0f}" y2="128" stroke="#A7B5AC" stroke-width="2"/>')
    text(X(t), 100, t[:5], 21, "#6F7C79", 400, "middle", True)

# load band
text(30, 186, "부하", 26, "#24292A", 700)
rect("22:00:20", "22:05:59", 158, 44, "#E7F0FF", "#1D5FBF")
text(X("22:00:20") + 14, 188, "에러 · 지연 주입 (k6)", 21, "#1D5FBF", 700)

# lanes
lanes = [("에러율 ②", 250, "22:03:18", "for: 2m"), ("지연 ③", 340, "22:04:18", "for: 3m")]
for name, y, fire, _ in lanes:
    text(30, y + 32, name, 25, "#24292A", 700)
    rect("22:01:00", fire, y, 50, "#FFF1DE", "#B5761F")
    rect(fire, "22:11:04", y, 50, "#FCE4E6", "#C2414A")
    text(X("22:01:00") + 12, y + 33, "pending", 20, "#8A5813", 700, "start", True)
    text(X(fire) + 12, y + 33, "firing", 20, "#C2414A", 700, "start", True)

# key moments
for t, c in [("22:00:20", "#1D5FBF"), ("22:05:59", "#1D5FBF"), ("22:11:04", "#0F766E")]:
    vline(t, 140, 420, c)
text(X("22:05:59"), 450, "부하 종료 22:05:59", 21, "#1D5FBF", 700, "middle")
text(X("22:11:04"), 450, "inactive 22:11:04", 21, "#0F766E", 700, "middle")

# brackets
bracket("22:00:20", "22:01:00", 530, "40초", "평가 주기(30초) + rate 계산", "#1D5FBF")
bracket("22:01:00", "22:03:18", 640, "2분 18초", "② 규칙의 for: 2m", "#B5761F")
bracket("22:01:00", "22:04:18", 750, "3분 18초", "③ 규칙의 for: 3m", "#B5761F")
bracket("22:05:59", "22:11:04", 640, "5분 5초", "rate(…[5m]) 의 창 길이", "#C2414A")

text(1570, 870, "시각은 실측 관찰 로그(20초 간격 조회)", 20, "#6F7C79", 400, "end")

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" role="img" aria-labelledby="t8 d8">
  <title id="t8">알림 상태 전이 타임라인</title>
  <desc id="d8">부하를 건 뒤 40초 만에 pending, 에러율 알림은 for 2분을 채워 firing, 지연 알림은 for 3분을 채워 firing. 부하를 끝낸 뒤에도 rate 5분 창 때문에 5분 5초 동안 firing이 유지됐다.</desc>
  <rect width="1600" height="900" fill="#FFFFFF"/>
  {"".join(out)}
</svg>
'''
open(__file__.replace("gen-fig8.py", "ch03-fig8-alert-timeline.svg"), "w").write(svg)
