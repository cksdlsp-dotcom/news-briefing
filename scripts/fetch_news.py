#!/usr/bin/env python3
import hashlib, html, json, os, re, ssl, urllib.parse, urllib.request
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
import xml.etree.ElementTree as ET

KST = timezone(timedelta(hours=9))
TODAY = datetime.now(KST).date().isoformat()
NEWS_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'news.json')

QUERIES = [
    '건축 건설 설계 감리 BIM 스마트건설',
    '부동산 도시개발 재개발 재건축 건축',
    '건축법 국토교통부 건설 정책 제도',
    '청주 충북 건설 부동산 개발 도시계획',
    'AI 건축 건설 설계 자동화 생성형AI',
    'AI 문서 자동화 OCR 공공 행정',
    '건설 적산 견적 원가 자재 노임',
    '입찰 설계용역 감리용역 건축사 CM',
    '철강 건설자재 구조 건축 KS',
    'QGIS 공간정보 지적 GIS 도시계획',
]

PROJECTS = {
    '수주대박': ['입찰','공고','수주','용역','설계용역','감리용역','건설사업관리','CM','발주','조달'],
    '사전검토': ['건축법','도시계획','용도지역','토지','지구단위','개발행위','인허가','규제','부동산','재개발','재건축','도시개발'],
    '문서분류': ['문서','OCR','분류','검색','RAG','데이터베이스','아카이브','전자문서'],
    '감리자동화': ['감리','현장','품질','안전','검측','건설사업관리','CM','시공','스마트건설'],
    '내역·적산': ['적산','견적','원가','노임','자재','물량','공사비','단가','철강','레미콘','시멘트'],
    'BIM': ['BIM','Revit','레빗','IFC','openBIM','디지털트윈','스마트건설'],
    'AI활용': ['AI','인공지능','생성형','자동화','AX','에이전트','LLM','OCR','로봇','드론'],
    '지역·부동산': ['청주','충북','충청','부동산','아파트','토지','도시개발','산업단지','공항','교통'],
    'QGIS자동화': ['QGIS','GIS','공간정보','지적','지도','공간데이터','국토정보'],
}
CORE = set(sum(PROJECTS.values(), [])) | {'건축','건설','설계','건축사','국토부','국토교통부'}
EXCLUDE = ['야구','축구','농구','배구','연예','아이돌','드라마','영화','가수','살인','성폭행','도박','선거유세']

UA = 'Mozilla/5.0 (compatible; ArchitectureBriefing/1.0; +https://cksdlsp-dotcom.github.io/news-briefing/)'
CTX = ssl.create_default_context()

def clean_text(s):
    s = html.unescape(re.sub(r'<[^>]+>', ' ', s or ''))
    return re.sub(r'\s+', ' ', s).strip()

def norm_title(s):
    s = re.sub(r'\[[^\]]+\]|\([^\)]*\)', ' ', s.lower())
    return re.sub(r'[^0-9a-z가-힣]+', '', s)

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ko-KR,ko;q=0.9'})
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
        return r.read()

def resolve_url(url):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=12, context=CTX) as r:
            final = r.geturl()
            if 'news.google.com' not in urllib.parse.urlparse(final).netloc:
                return final
    except Exception:
        pass
    return url

def pub_date(text):
    try:
        return parsedate_to_datetime(text).astimezone(KST).date().isoformat()
    except Exception:
        return TODAY

def score_and_projects(title, desc):
    text = f'{title} {desc}'
    if any(x in text for x in EXCLUDE):
        return 0, []
    projects = []
    score = 0
    for p, keys in PROJECTS.items():
        hits = sum(1 for k in keys if k.lower() in text.lower())
        if hits:
            projects.append(p)
            score += min(hits, 3) * 2
    score += sum(1 for k in CORE if k.lower() in text.lower())
    if not any(k in text for k in ['건축','건설','설계','감리','BIM','부동산','도시','토지','청주','충북','AI','인공지능','적산','입찰','공사','자재','QGIS','공간정보']):
        score = 0
    return score, projects[:4]

def short_mark(title, desc):
    d = clean_text(desc)
    d = re.sub(r'\s*-\s*[^-]{2,30}$', '', d)
    if d and d != title:
        return (d[:118] + '…') if len(d) > 120 else d
    return title[:100]

def load_old():
    try:
        with open(NEWS_FILE, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {'updated_at':'','articles':[]}

def main():
    old = load_old()
    articles = old.get('articles', [])
    seen_url = {a.get('url') for a in articles}
    seen_title = {norm_title(a.get('title','')) for a in articles}
    fresh = []
    for q in QUERIES:
        rss = 'https://news.google.com/rss/search?' + urllib.parse.urlencode({
            'q': q + ' when:3d', 'hl':'ko','gl':'KR','ceid':'KR:ko'
        })
        try:
            root = ET.fromstring(fetch(rss))
        except Exception as e:
            print('RSS fail', q, e)
            continue
        for item in root.findall('.//item')[:35]:
            title = clean_text(item.findtext('title'))
            link = clean_text(item.findtext('link'))
            desc = clean_text(item.findtext('description'))
            source_el = item.find('source')
            source = clean_text(source_el.text if source_el is not None else '') or '공개뉴스'
            published = pub_date(item.findtext('pubDate') or '')
            score, projects = score_and_projects(title, desc)
            if score < 4 or not projects:
                continue
            nt = norm_title(title)
            if not nt or nt in seen_title:
                continue
            direct = resolve_url(link)
            if direct in seen_url:
                continue
            aid = 'auto-' + hashlib.sha1((nt + direct).encode()).hexdigest()[:12]
            fresh.append({
                'id': aid, 'briefing_date': TODAY, 'published_date': published,
                'title': title, 'url': direct, 'source': source,
                'projects': projects, 'mark': short_mark(title, desc), 'score': score,
                'via_google_news': 'news.google.com' in urllib.parse.urlparse(direct).netloc,
            })
            seen_title.add(nt); seen_url.add(direct)
    fresh.sort(key=lambda a:(a['score'], a['published_date']), reverse=True)
    # 한 매체 쏠림 방지: 매체당 하루 최대 6개, 전체 최대 45개
    counts = {}
    selected = []
    for a in fresh:
        if counts.get(a['source'],0) >= 6: continue
        selected.append(a); counts[a['source']] = counts.get(a['source'],0)+1
        if len(selected) >= 45: break
    articles.extend(selected)
    cutoff = (datetime.now(KST).date() - timedelta(days=90)).isoformat()
    articles = [a for a in articles if a.get('briefing_date', TODAY) >= cutoff]
    articles.sort(key=lambda a:(a.get('briefing_date',''), a.get('score',0), a.get('published_date','')), reverse=True)
    out = {'updated_at': datetime.now(KST).isoformat(timespec='seconds'), 'articles': articles}
    with open(NEWS_FILE,'w',encoding='utf-8') as f:
        json.dump(out,f,ensure_ascii=False,indent=2)
    print(f'added={len(selected)} total={len(articles)}')

if __name__ == '__main__': main()
