#!/usr/bin/env python3
"""실습 가이드 빌드.   python3 src/build_lab.py

src/lab-guide.src.html 의 FILE 자리표시자(경로는 이 폴더 루트 기준)를 파일 내용(HTML 이스케이프)으로
바꾸고, 목차와 스타일·스크립트를 붙여 ../lab-guide.html 을 만든다.
"""
import html
import re
from pathlib import Path

SRC = Path(__file__).parent
ROOT = SRC.parent
OUT = ROOT / "lab-guide.html"

body = (SRC / "lab-guide.src.html").read_text(encoding="utf-8")


def embed(m):
    rel = m.group(1)
    text = (ROOT / rel).read_text(encoding="utf-8")
    return (f'<p class="src"><a href="{rel}" target="_blank" rel="noopener">{rel}</a></p>'
            f'<pre class="file-body">{html.escape(text)}</pre>')


body = re.sub(r"\{\{FILE:([^}]+)\}\}", embed, body)

# 목차
toc = []
for sec in re.finditer(r'<section id="(p\d+)">\s*<h2><span class="no">(\d+)</span>(.*?)</h2>(.*?)</section>', body, re.S):
    sid, no, title, inner = sec.groups()
    subs = re.findall(r'<div class="step" id="([^"]+)">\s*<h3>(.*?)</h3>', inner, re.S)
    items = "".join(
        f'<li><a href="#{i}">{re.sub(r"<[^>]+>", "", re.sub(r'<span class="badge[^"]*">.*?</span>', "", t)).strip()}</a></li>' for i, t in subs)
    toc.append(f'<li><a href="#{sid}"><b>{no}</b> {title}</a><ul>{items}</ul></li>')

caps = len(re.findall(r'data-k="', body))

page = f"""<!doctype html>
<html lang="ko"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>모니터링과 로깅 · 실습 가이드</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css">
<style>
:root{{--bg:#FAFAF7;--panel:#FFFFFF;--ink:#24292A;--muted:#5A6867;--line:#D8DDD6;--teal:#0F766E;--teal-deep:#0B5A54;--teal-bg:#E0EFEB;--yellow:#8A5813;--yellow-bg:#FFF1DE;--red:#C2414A;--mono:'SFMono-Regular',Consolas,'Liberation Mono',monospace;--sans:Pretendard,'Apple SD Gothic Neo','Noto Sans KR',system-ui,sans-serif}}
*{{box-sizing:border-box}}
html{{font-size:16px}}
body{{margin:0;background:var(--bg);color:var(--ink);font-family:var(--sans);line-height:1.7}}
.layout{{display:grid;grid-template-columns:300px minmax(0,1fr);max-width:1400px;margin:0 auto}}
nav{{position:sticky;top:0;height:100vh;overflow:auto;padding:28px 20px;border-right:1px solid var(--line);font-size:.86rem}}
nav h1{{font-size:1.05rem;margin:0 0 6px}}
nav .progress{{font:600 .8rem var(--mono);color:var(--teal);margin-bottom:16px}}
nav ul{{list-style:none;margin:0;padding:0}}
nav li{{margin:6px 0}}
nav li ul{{margin:4px 0 10px 14px}}
nav li ul li{{margin:2px 0}}
nav a{{color:var(--ink);text-decoration:none}}
nav a:hover{{color:var(--teal)}}
main{{padding:36px 48px 120px;min-width:0}}
header.top{{margin-bottom:32px}}
header.top h1{{font-size:2rem;margin:0 0 8px;letter-spacing:-.02em}}
header.top p{{color:var(--muted);margin:0}}
section{{margin-top:56px}}
h2{{font-size:1.5rem;margin:0 0 12px;padding-bottom:8px;border-bottom:1px solid var(--line)}}
h2 .no{{font:700 .9rem var(--mono);color:var(--teal);margin-right:10px}}
h3{{font-size:1.1rem;margin:0 0 8px}}
.lead{{color:var(--muted)}}
.step{{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:20px 24px;margin:18px 0}}
.purpose{{margin:6px 0 10px}}
.expect{{margin:10px 0;padding-left:12px;border-left:3px solid var(--teal)}}
.warn{{margin:10px 0;color:var(--yellow)}}
.note{{margin:10px 0;color:var(--muted)}}
.badge{{display:inline-block;font:600 .72rem var(--mono);padding:2px 7px;border-radius:4px;background:var(--teal-bg);color:var(--teal-deep);vertical-align:middle;margin-left:4px}}
.badge.cap{{background:#E7F0FF;color:#1D5FBF}}
.badge.warn{{background:var(--yellow-bg);color:var(--yellow)}}
pre{{font:13.5px/1.55 var(--mono);background:#F4F7F5;border:1px solid var(--line);border-radius:6px;padding:12px 14px;overflow-x:auto;margin:8px 0;white-space:pre}}
pre.cmd{{position:relative;background:#F4F7F5;padding-right:64px}}
pre.out{{background:#FFFFFF;color:var(--muted);border-style:dashed}}
pre.out::before{{content:"실행 결과";display:block;font:600 .7rem var(--sans);color:var(--muted);margin-bottom:4px}}
button.copy{{position:absolute;top:8px;right:8px;font:600 .72rem var(--sans);border:1px solid var(--line);background:#fff;border-radius:4px;padding:3px 8px;cursor:pointer;color:var(--muted)}}
button.copy:hover{{color:var(--teal);border-color:var(--teal)}}
code{{font-family:var(--mono);font-size:.88em;background:var(--teal-bg);color:var(--teal-deep);padding:1px 5px;border-radius:3px}}
pre code{{background:none;padding:0;color:inherit}}
label.cap{{display:block;margin:8px 0;padding:8px 12px;border:1px solid #B8D3F5;border-radius:6px;background:#F5F9FF;cursor:pointer}}
label.cap input{{margin-right:6px;transform:scale(1.15)}}
label.cap.done{{opacity:.55}}
details.file{{margin:10px 0}}
details.file summary{{cursor:pointer;font-weight:600;color:var(--teal-deep)}}
p.src{{margin:6px 0 0;font:.8rem var(--mono)}}
p.src a{{color:#1D5FBF}}
pre.file-body{{max-height:480px;overflow:auto;font-size:12.5px}}
table.t{{border-collapse:collapse;width:100%;margin:10px 0;font-size:.92rem}}
table.t th,table.t td{{border:1px solid var(--line);padding:6px 10px;text-align:left;vertical-align:top}}
table.t th{{background:var(--teal-bg);color:var(--teal-deep)}}
table.opt td:first-child{{font-family:var(--mono);font-size:.85rem;white-space:nowrap}}
.verdict{{margin:10px 0;padding:8px 12px;background:#F2F8F6;border-radius:6px}}
.verdict::before{{content:"판정 ";font-weight:700;color:var(--teal-deep)}}
.why{{margin:6px 0 10px;color:var(--ink)}}
@media (max-width:900px){{.layout{{grid-template-columns:1fr}} nav{{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line)}} main{{padding:24px 16px 80px}}}}
</style>
</head>
<body>
<div class="layout">
<nav>
  <h1>실습 가이드</h1>
  <div class="progress">캡처 <span id="capDone">0</span> / {caps}</div>
  <ul>{"".join(toc)}</ul>
</nav>
<main>
<header class="top">
  <h1>모니터링과 로깅 · 실습 가이드</h1>
  <p>발표 슬라이드(<a href="slides.html">slides.html</a>)의 내용을 빈 kind 클러스터에서 처음부터 따라 한다. 명령은 모두 이 폴더 루트에서 실행한다.</p>
</header>
{body}
</main>
</div>
<script>
document.querySelectorAll('pre.cmd').forEach(p => {{
  const b = document.createElement('button'); b.className = 'copy'; b.textContent = '복사';
  b.addEventListener('click', () => {{
    const t = p.innerText.replace(/\\n?복사$/, '').replace(/^복사\\n?/, '');
    navigator.clipboard.writeText(p.dataset.raw || t).then(() => {{ b.textContent = '복사됨'; setTimeout(() => b.textContent = '복사', 1200); }});
  }});
  p.dataset.raw = p.innerText; p.appendChild(b);
}});
const KEY = 'ch03-lab-caps';
let saved = {{}};
try {{ saved = JSON.parse(localStorage.getItem(KEY) || '{{}}'); }} catch (e) {{ saved = {{}}; }}
function count() {{ document.getElementById('capDone').textContent = document.querySelectorAll('label.cap input:checked').length; }}
document.querySelectorAll('label.cap input').forEach(i => {{
  if (saved[i.dataset.k]) {{ i.checked = true; i.parentElement.classList.add('done'); }}
  i.addEventListener('change', () => {{
    saved[i.dataset.k] = i.checked; i.parentElement.classList.toggle('done', i.checked);
    try {{ localStorage.setItem(KEY, JSON.stringify(saved)); }} catch (e) {{}}
    count();
  }});
}});
count();
</script>
</body></html>
"""
OUT.write_text(page, encoding="utf-8")
print(f"{OUT.name}: steps={len(re.findall(r'class=\"step\"', body))} captures={caps}")
