#!/usr/bin/env python3
"""ch03-fig4-mean-vs-tail.svg 생성. 네 수치는 course M20 20.6 실측, 막대는 개략."""
import math
x0, sc, base = 150, 315, 690            # 0.1ms 위치, 로그 1자리당 px, 기준선
X = lambda s: x0 + (math.log10(s) + 4) * sc
SANS = "font-family:Pretendard,'Apple SD Gothic Neo',sans-serif"
MONO = "font-family:'SFMono-Regular',Consolas,monospace"
bins = [(0.00025, 40), (0.0004, 210), (0.00063, 430), (0.001, 250), (0.0016, 90),
        (0.0025, 30), (0.004, 12), (0.6, 34), (0.76, 66)]

def bar(c, h):
    slow = c > 0.1
    w = 30 if slow else 46
    return (f'<rect x="{X(c)-w/2:.0f}" y="{base-h}" width="{w}" height="{h}" '
            f'fill="{"#FCE4E6" if slow else "#DDF3EC"}" stroke="{"#C2414A" if slow else "#0F766E"}" stroke-width="2"/>')

def mark(v, label, val, y, color, anchor="start", dx=14, dash=False):
    x = X(v)
    d = ' stroke-dasharray="10 7"' if dash else ""
    return (f'<line x1="{x:.0f}" y1="{base}" x2="{x:.0f}" y2="{y-8}" stroke="{color}" stroke-width="3"{d}/>'
            f'<text x="{x+dx:.0f}" y="{y+26}" font-size="34" font-weight="700" text-anchor="{anchor}" style="{SANS};fill:{color}">{label}</text>'
            f'<text x="{x+dx:.0f}" y="{y+64}" font-size="28" text-anchor="{anchor}" style="{MONO};fill:{color}">{val}</text>')

ticks = "".join(
    f'<line x1="{X(v):.0f}" y1="{base}" x2="{X(v):.0f}" y2="{base+14}" stroke="#5A6867" stroke-width="2"/>'
    f'<text x="{X(v):.0f}" y="{base+48}" font-size="26" text-anchor="middle" style="{MONO};fill:#5A6867">{l}</text>'
    for v, l in [(0.0001, "0.1ms"), (0.001, "1ms"), (0.01, "10ms"), (0.1, "100ms"), (1, "1s")])
marks = (mark(0.00059, "P50", "0.59ms", 150, "#0B5A54")
         + mark(0.045, "평균", "45ms", 300, "#B5761F", dash=True)
         + mark(0.725, "P95", "725ms", 150, "#C2414A", "end", -14)
         + mark(0.79, "P99", "790ms", 250, "#C2414A"))

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" role="img" aria-labelledby="t4 d4">
  <title id="t4">평균 45ms를 겪은 요청은 없다</title>
  <desc id="d4">order-api 응답 시간 분포. 대부분의 요청은 1밀리초 안팎에 끝나고 일부가 800밀리초 근처에 몰린다. 평균 45밀리초는 두 무리 사이 빈 곳에 떨어진다. P50 0.59ms, P95 725ms, P99 790ms는 실측값이다.</desc>
  <rect width="1600" height="900" fill="#FFFFFF"/>
  <text x="40" y="60" font-size="34" font-weight="700" style="{SANS};fill:#24292A">order-api 응답 시간 분포</text>
  <text x="40" y="102" font-size="24" style="{SANS};fill:#5A6867">가로축 로그 눈금 · 세로축 요청 수(개략)</text>
  {"".join(bar(c, h) for c, h in bins)}
  <line x1="120" y1="{base}" x2="1560" y2="{base}" stroke="#5A6867" stroke-width="2.5"/>
  {ticks}
  {marks}
  <text x="{X(0.00063):.0f}" y="{base+104}" font-size="28" font-weight="700" text-anchor="middle" style="{SANS};fill:#0B5A54">정상 요청 대부분</text>
  <text x="{X(0.045):.0f}" y="{base+104}" font-size="28" font-weight="700" text-anchor="middle" style="{SANS};fill:#B5761F">이 근처 요청은 거의 없다</text>
  <text x="{X(0.7):.0f}" y="{base+104}" font-size="28" font-weight="700" text-anchor="middle" style="{SANS};fill:#C2414A">느린 요청 무리</text>
  <text x="40" y="{base+168}" font-size="22" style="{SANS};fill:#6F7C79">막대 모양은 개략도, 네 수치는 실측값. k6 부하 중 /api/chaos/slow 요청이 초당 2건 섞여 있었다</text>
</svg>
'''
open(__file__.replace("gen-fig4.py", "ch03-fig4-mean-vs-tail.svg"), "w").write(svg)
