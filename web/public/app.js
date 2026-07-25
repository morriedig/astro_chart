(function () {
  "use strict";

  var SVG_NS = "http://www.w3.org/2000/svg";

  /* ---------- 多語系（UI 靜態字串） ---------- */

  var I18N = {
    "zh-TW": {
      docTitle: "AstroChart 星盤",
      brandSub: "星盤",
      navDocs: "API 文件",
      footerTag: "純 Ruby 星曆計算",
      langAria: "語言",
      tabsAria: "功能切換",
      legendAria: "相位顏色圖例",
      wheelAria: "星盤圖：上升點置於左方，黃道經度逆時針遞增",
      tabNatal: "本命盤", tabSyn: "合盤", tabTrans: "行運",
      tabProg: "推運", tabSolar: "太陽回歸", tabComp: "組合盤",
      birthDate: "出生日期", birthTime: "出生時間",
      citySearch: "城市搜尋",
      cityPh: "輸入城市（中文或英文）自動帶入座標",
      lat: "緯度", lng: "經度", tz: "時區",
      tzCustom: "自訂時區（IANA 名稱，留空則用上方選項）",
      tzPh: "例如 Asia/Taipei",
      tzIana: "時區（IANA 名稱）",
      tzUseBirth: "（使用出生地時區）",
      houseSystem: "宮位制",
      hsPlacidusOpt: "普拉西德制（Placidus）",
      hsWholeOpt: "整宮制（Whole Sign）",
      orbDefault: "容許度上限（度，留空則用預設容許度）",
      orb3: "容許度上限（度，留空則用預設 3）",
      orb1: "容許度上限（度，留空則用預設 1）",
      btnNatal: "繪製星盤", btnSyn: "計算合盤", btnTrans: "計算行運",
      btnProg: "計算推運", btnSolar: "計算太陽回歸", btnComp: "計算組合盤",
      btnShare: "分享", btnPng: "下載圖片",
      partyA: "甲方 A", partyB: "乙方 B",
      natalData: "本命資料", transitMoment: "行運時刻", srSettings: "回歸設定",
      hintTransNow: "留空以「現在」時刻計算；填寫則日期與時間須同時填。",
      srYear: "回歸年份",
      hintSrLoc: "回歸地點（選填，留空則用出生地）：",
      progTarget: "推運目標日期",
      dateLabel: "日期", timeLabel: "時間",
      secPlanets: "行星位置", secHouses: "宮位", secPatterns: "相位圖形",
      secStats: "元素與三方統計", secAspects: "相位",
      secSynAspects: "跨盤相位",
      secAInB: "A 的行星在 B 的宮位", secBInA: "B 的行星在 A 的宮位",
      secTransPlanets: "行運行星位置", secTransAspects: "行運相位（對本命）",
      secProgPlanets: "推運行星位置", secProgAspects: "推運相位（對本命）",
      secCompPlanets: "組合盤行星（中點）", secCompAspects: "組合盤相位",
      thPlanet: "行星", thZodiac: "星座", thDegree: "度數", thHouse: "宮位",
      thAspect: "相位", thOrb: "容許度", thCusp: "宮首度數",
      thNatalHouse: "落入本命宮位",
      thTransPlanet: "行運行星", thNatalPlanet: "本命行星", thProgPlanet: "推運行星",
      thAPlanet: "A 行星", thBPlanet: "B 行星",
      thInBHouse: "落入 B 的宮位", thInAHouse: "落入 A 的宮位",
      emptyData: "沒有資料",
      emptyAspects: "此盤未偵測到相位",
      emptySyn: "沒有符合條件的跨盤相位",
      emptyTrans: "此容許度內沒有行運相位",
      emptyProg: "此容許度內沒有推運相位",
      emptyComp: "組合盤沒有偵測到相位",
      emptyPatterns: "此盤未偵測到大三角、T三角或大十字圖形",
      emptyStats: "沒有統計資料",
      errServer: "伺服器回應異常（HTTP {s}）",
      errDate: "請選擇出生日期",
      errTime: "請選擇出生時間",
      errLatLng: "請輸入有效的緯度與經度數值",
      errOrb: "容許度上限須為非負數字",
      errTransAt: "行運時刻需同時填寫日期與時間，或兩者皆留空以使用現在時刻",
      errTarget: "請選擇推運目標日期",
      errYear: "請輸入回歸年份",
      errSrLoc: "回歸地點的緯度與經度需同時填寫有效數值，或兩者皆留空",
      errUnknown: "發生未知錯誤，請稍後再試",
      loading: "推算中⋯",
      copied: "已複製連結",
      copyPrompt: "複製此分享連結：",
      ascendant: "上升點",
      hsPlacidus: "普拉西德制", hsWhole: "整宮制",
      houseNth: "第 {n} 宮",
      retro: "逆行",
      transitTimeLabel: "行運時刻：",
      localTime: "（當地時間 {t}）",
      progMeta: "二次推運（一日一年）　·　經過年數：{y} 年",
      srTimeLabel: "回歸時刻：",
      srLocLabel: "地點",
      statElements: "元素", statModalities: "三方",
      patElement: "元素：", patCrossElement: "跨元素", patApex: "端點：",
      listSep: "、", dotSep: "　·　"
    },
    en: {
      docTitle: "AstroChart",
      brandSub: "Astrology",
      navDocs: "API Docs",
      footerTag: "Pure-Ruby ephemeris",
      langAria: "Language",
      tabsAria: "Chart type",
      legendAria: "Aspect color legend",
      wheelAria: "Chart wheel: Ascendant on the left, longitudes increase counterclockwise",
      tabNatal: "Natal", tabSyn: "Synastry", tabTrans: "Transits",
      tabProg: "Progressions", tabSolar: "Solar Return", tabComp: "Composite",
      birthDate: "Birth date", birthTime: "Birth time",
      citySearch: "City search",
      cityPh: "Type a city to auto-fill coordinates",
      lat: "Latitude", lng: "Longitude", tz: "Time zone",
      tzCustom: "Custom time zone (IANA name, overrides the above)",
      tzPh: "e.g. Asia/Taipei",
      tzIana: "Time zone (IANA name)",
      tzUseBirth: "(use birthplace time zone)",
      houseSystem: "House system",
      hsPlacidusOpt: "Placidus",
      hsWholeOpt: "Whole Sign",
      orbDefault: "Max orb (degrees, blank = per-aspect defaults)",
      orb3: "Max orb (degrees, blank = 3)",
      orb1: "Max orb (degrees, blank = 1)",
      btnNatal: "Draw Chart", btnSyn: "Calculate Synastry", btnTrans: "Calculate Transits",
      btnProg: "Calculate Progressions", btnSolar: "Calculate Solar Return", btnComp: "Calculate Composite",
      btnShare: "Share", btnPng: "Download PNG",
      partyA: "Person A", partyB: "Person B",
      natalData: "Natal Data", transitMoment: "Transit Moment", srSettings: "Return Settings",
      hintTransNow: "Leave blank to use the current moment; otherwise fill in both date and time.",
      srYear: "Return year",
      hintSrLoc: "Return location (optional, defaults to birthplace):",
      progTarget: "Target date",
      dateLabel: "Date", timeLabel: "Time",
      secPlanets: "Planets", secHouses: "Houses", secPatterns: "Aspect Patterns",
      secStats: "Elements & Modalities", secAspects: "Aspects",
      secSynAspects: "Cross-Chart Aspects",
      secAInB: "A's Planets in B's Houses", secBInA: "B's Planets in A's Houses",
      secTransPlanets: "Transiting Planets", secTransAspects: "Transit Aspects (to Natal)",
      secProgPlanets: "Progressed Planets", secProgAspects: "Progressed Aspects (to Natal)",
      secCompPlanets: "Composite Planets (Midpoints)", secCompAspects: "Composite Aspects",
      thPlanet: "Planet", thZodiac: "Sign", thDegree: "Degree", thHouse: "House",
      thAspect: "Aspect", thOrb: "Orb", thCusp: "Cusp",
      thNatalHouse: "Natal house",
      thTransPlanet: "Transiting", thNatalPlanet: "Natal planet", thProgPlanet: "Progressed",
      thAPlanet: "Planet A", thBPlanet: "Planet B",
      thInBHouse: "House of B", thInAHouse: "House of A",
      emptyData: "No data",
      emptyAspects: "No aspects detected in this chart",
      emptySyn: "No cross-chart aspects match",
      emptyTrans: "No transit aspects within this orb",
      emptyProg: "No progressed aspects within this orb",
      emptyComp: "No aspects detected in the composite",
      emptyPatterns: "No Grand Trine, T-Square, or Grand Cross detected",
      emptyStats: "No statistics available",
      errServer: "Unexpected server response (HTTP {s})",
      errDate: "Please pick a birth date",
      errTime: "Please pick a birth time",
      errLatLng: "Please enter valid latitude and longitude values",
      errOrb: "Max orb must be a non-negative number",
      errTransAt: "Fill in both transit date and time, or leave both blank to use the current moment",
      errTarget: "Please pick a target date",
      errYear: "Please enter the return year",
      errSrLoc: "Return-location latitude and longitude must both be valid, or both left blank",
      errUnknown: "Something went wrong. Please try again later",
      loading: "Calculating…",
      copied: "Link copied",
      copyPrompt: "Copy this share link:",
      ascendant: "Ascendant",
      hsPlacidus: "Placidus", hsWhole: "Whole Sign",
      houseNth: "House {n}",
      retro: "Retrograde",
      transitTimeLabel: "Transit time: ",
      localTime: " (local {t})",
      progMeta: "Secondary progressions (day-for-a-year) · Years elapsed: {y}",
      srTimeLabel: "Return time: ",
      srLocLabel: "Location",
      statElements: "Elements", statModalities: "Modalities",
      patElement: "Element: ", patCrossElement: "Mixed elements", patApex: "Apex: ",
      listSep: ", ", dotSep: " · "
    },
    ja: {
      docTitle: "AstroChart ホロスコープ",
      brandSub: "ホロスコープ",
      navDocs: "APIドキュメント",
      footerTag: "純Ruby天文暦計算",
      langAria: "言語",
      tabsAria: "機能切替",
      legendAria: "アスペクトの色凡例",
      wheelAria: "ホロスコープ図：アセンダントを左に配置、黄経は反時計回り",
      tabNatal: "ネイタル", tabSyn: "シナストリー", tabTrans: "トランジット",
      tabProg: "プログレス", tabSolar: "ソーラーリターン", tabComp: "コンポジット",
      birthDate: "生年月日", birthTime: "出生時刻",
      citySearch: "都市検索",
      cityPh: "都市名を入力すると座標が自動入力されます",
      lat: "緯度", lng: "経度", tz: "タイムゾーン",
      tzCustom: "カスタムタイムゾーン（IANA名、空欄なら上を使用）",
      tzPh: "例：Asia/Taipei",
      tzIana: "タイムゾーン（IANA名）",
      tzUseBirth: "（出生地のタイムゾーンを使用）",
      houseSystem: "ハウスシステム",
      hsPlacidusOpt: "プラシーダス",
      hsWholeOpt: "ホールサイン",
      orbDefault: "オーブ上限（度、空欄なら既定値）",
      orb3: "オーブ上限（度、空欄なら既定3）",
      orb1: "オーブ上限（度、空欄なら既定1）",
      btnNatal: "ホロスコープ作成", btnSyn: "シナストリー計算", btnTrans: "トランジット計算",
      btnProg: "プログレス計算", btnSolar: "ソーラーリターン計算", btnComp: "コンポジット計算",
      btnShare: "共有", btnPng: "画像を保存",
      partyA: "Aさん", partyB: "Bさん",
      natalData: "出生データ", transitMoment: "トランジット日時", srSettings: "リターン設定",
      hintTransNow: "空欄なら現在時刻で計算します。指定する場合は日付と時刻を両方入力してください。",
      srYear: "リターン年",
      hintSrLoc: "リターン地点（任意、空欄なら出生地）：",
      progTarget: "対象日",
      dateLabel: "日付", timeLabel: "時刻",
      secPlanets: "天体の位置", secHouses: "ハウス", secPatterns: "アスペクトパターン",
      secStats: "エレメントとクオリティ", secAspects: "アスペクト",
      secSynAspects: "相互アスペクト",
      secAInB: "Aの天体 × Bのハウス", secBInA: "Bの天体 × Aのハウス",
      secTransPlanets: "トランジット天体", secTransAspects: "トランジットアスペクト（対ネイタル）",
      secProgPlanets: "進行天体", secProgAspects: "進行アスペクト（対ネイタル）",
      secCompPlanets: "コンポジット天体（中間点）", secCompAspects: "コンポジットアスペクト",
      thPlanet: "天体", thZodiac: "星座", thDegree: "度数", thHouse: "ハウス",
      thAspect: "アスペクト", thOrb: "オーブ", thCusp: "カスプ度数",
      thNatalHouse: "出生ハウス",
      thTransPlanet: "トランジット天体", thNatalPlanet: "出生天体", thProgPlanet: "進行天体",
      thAPlanet: "Aの天体", thBPlanet: "Bの天体",
      thInBHouse: "Bのハウス", thInAHouse: "Aのハウス",
      emptyData: "データがありません",
      emptyAspects: "アスペクトは検出されませんでした",
      emptySyn: "条件に合う相互アスペクトはありません",
      emptyTrans: "このオーブ内にトランジットアスペクトはありません",
      emptyProg: "このオーブ内に進行アスペクトはありません",
      emptyComp: "コンポジットにアスペクトはありません",
      emptyPatterns: "グランドトライン・Tスクエア・グランドクロスは検出されませんでした",
      emptyStats: "統計データがありません",
      errServer: "サーバーエラー（HTTP {s}）",
      errDate: "生年月日を選択してください",
      errTime: "出生時刻を選択してください",
      errLatLng: "有効な緯度・経度を入力してください",
      errOrb: "オーブ上限は0以上の数値で入力してください",
      errTransAt: "トランジット日時は日付と時刻を両方入力するか、両方空欄にしてください",
      errTarget: "対象日を選択してください",
      errYear: "リターン年を入力してください",
      errSrLoc: "リターン地点の緯度・経度は両方入力するか、両方空欄にしてください",
      errUnknown: "エラーが発生しました。しばらくしてからもう一度お試しください",
      loading: "計算中⋯",
      copied: "リンクをコピーしました",
      copyPrompt: "この共有リンクをコピー：",
      ascendant: "アセンダント",
      hsPlacidus: "プラシーダス", hsWhole: "ホールサイン",
      houseNth: "第{n}ハウス",
      retro: "逆行",
      transitTimeLabel: "トランジット日時：",
      localTime: "（現地時間 {t}）",
      progMeta: "二次進行（1日1年）　·　経過年数：{y}年",
      srTimeLabel: "リターン日時：",
      srLocLabel: "地点",
      statElements: "エレメント", statModalities: "クオリティ",
      patElement: "エレメント：", patCrossElement: "エレメント混合", patApex: "頂点：",
      listSep: "、", dotSep: "　·　"
    },
    ko: {
      docTitle: "AstroChart 호로스코프",
      brandSub: "호로스코프",
      navDocs: "API 문서",
      footerTag: "순수 Ruby 천체력 계산",
      langAria: "언어",
      tabsAria: "기능 전환",
      legendAria: "어스펙트 색상 범례",
      wheelAria: "호로스코프 차트: 어센던트가 왼쪽, 황경은 반시계 방향으로 증가",
      tabNatal: "네이탈", tabSyn: "시너스트리", tabTrans: "트랜짓",
      tabProg: "프로그레션", tabSolar: "솔라 리턴", tabComp: "컴포지트",
      birthDate: "생년월일", birthTime: "출생 시간",
      citySearch: "도시 검색",
      cityPh: "도시 이름을 입력하면 좌표가 자동 입력됩니다",
      lat: "위도", lng: "경도", tz: "시간대",
      tzCustom: "사용자 지정 시간대 (IANA 이름, 비우면 위 선택 사용)",
      tzPh: "예: Asia/Taipei",
      tzIana: "시간대 (IANA 이름)",
      tzUseBirth: "(출생지 시간대 사용)",
      houseSystem: "하우스 시스템",
      hsPlacidusOpt: "플라시두스",
      hsWholeOpt: "홀 사인",
      orbDefault: "최대 오브 (도, 비우면 기본값 사용)",
      orb3: "최대 오브 (도, 비우면 기본 3)",
      orb1: "최대 오브 (도, 비우면 기본 1)",
      btnNatal: "차트 그리기", btnSyn: "시너스트리 계산", btnTrans: "트랜짓 계산",
      btnProg: "프로그레션 계산", btnSolar: "솔라 리턴 계산", btnComp: "컴포지트 계산",
      btnShare: "공유", btnPng: "이미지 저장",
      partyA: "사람 A", partyB: "사람 B",
      natalData: "출생 정보", transitMoment: "트랜짓 시각", srSettings: "리턴 설정",
      hintTransNow: "비워 두면 현재 시각으로 계산합니다. 입력할 경우 날짜와 시간을 모두 입력하세요.",
      srYear: "리턴 연도",
      hintSrLoc: "리턴 장소 (선택, 비우면 출생지 사용):",
      progTarget: "대상 날짜",
      dateLabel: "날짜", timeLabel: "시간",
      secPlanets: "행성 위치", secHouses: "하우스", secPatterns: "어스펙트 패턴",
      secStats: "원소·특질 통계", secAspects: "어스펙트",
      secSynAspects: "상호 어스펙트",
      secAInB: "A의 행성 × B의 하우스", secBInA: "B의 행성 × A의 하우스",
      secTransPlanets: "트랜짓 행성", secTransAspects: "트랜짓 어스펙트 (네이탈 대비)",
      secProgPlanets: "프로그레스 행성", secProgAspects: "프로그레스 어스펙트 (네이탈 대비)",
      secCompPlanets: "컴포지트 행성 (중간점)", secCompAspects: "컴포지트 어스펙트",
      thPlanet: "행성", thZodiac: "별자리", thDegree: "도수", thHouse: "하우스",
      thAspect: "어스펙트", thOrb: "오브", thCusp: "커스프 도수",
      thNatalHouse: "네이탈 하우스",
      thTransPlanet: "트랜짓 행성", thNatalPlanet: "네이탈 행성", thProgPlanet: "프로그레스 행성",
      thAPlanet: "A 행성", thBPlanet: "B 행성",
      thInBHouse: "B의 하우스", thInAHouse: "A의 하우스",
      emptyData: "데이터가 없습니다",
      emptyAspects: "이 차트에서 어스펙트가 발견되지 않았습니다",
      emptySyn: "조건에 맞는 상호 어스펙트가 없습니다",
      emptyTrans: "이 오브 내 트랜짓 어스펙트가 없습니다",
      emptyProg: "이 오브 내 프로그레스 어스펙트가 없습니다",
      emptyComp: "컴포지트에서 어스펙트가 발견되지 않았습니다",
      emptyPatterns: "그랜드 트라인·T스퀘어·그랜드 크로스가 발견되지 않았습니다",
      emptyStats: "통계 데이터가 없습니다",
      errServer: "서버 오류 (HTTP {s})",
      errDate: "생년월일을 선택하세요",
      errTime: "출생 시간을 선택하세요",
      errLatLng: "유효한 위도와 경도를 입력하세요",
      errOrb: "최대 오브는 0 이상의 숫자여야 합니다",
      errTransAt: "트랜짓 시각은 날짜와 시간을 모두 입력하거나 모두 비워 두세요",
      errTarget: "대상 날짜를 선택하세요",
      errYear: "리턴 연도를 입력하세요",
      errSrLoc: "리턴 장소의 위도와 경도는 모두 입력하거나 모두 비워 두세요",
      errUnknown: "알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도하세요",
      loading: "계산 중⋯",
      copied: "링크 복사됨",
      copyPrompt: "이 공유 링크를 복사하세요:",
      ascendant: "어센던트",
      hsPlacidus: "플라시두스", hsWhole: "홀 사인",
      houseNth: "{n}하우스",
      retro: "역행",
      transitTimeLabel: "트랜짓 시각: ",
      localTime: " (현지 시간 {t})",
      progMeta: "세컨더리 프로그레션 (1일=1년) · 경과 연수: {y}년",
      srTimeLabel: "리턴 시각: ",
      srLocLabel: "위치",
      statElements: "원소", statModalities: "특질",
      patElement: "원소: ", patCrossElement: "혼합 원소", patApex: "정점: ",
      listSep: ", ", dotSep: " · "
    }
  };

  var HTML_LANG = { "zh-TW": "zh-Hant", en: "en", ja: "ja", ko: "ko" };
  var LANG = "zh-TW";

  function t(key) {
    var dict = I18N[LANG] || I18N["zh-TW"];
    if (dict[key] !== undefined) return dict[key];
    if (I18N["zh-TW"][key] !== undefined) return I18N["zh-TW"][key];
    return key;
  }

  function tf(key, subs) {
    var s = t(key);
    Object.keys(subs).forEach(function (k) {
      s = s.replace("{" + k + "}", String(subs[k]));
    });
    return s;
  }

  /* ---------- API 詞彙表（四語）——所有需要比對 API 回傳值的地方
     一律透過下列反查表，任何語言的回應都能對回符號／顏色／索引。 ---------- */

  // 14 個天體／點位；wheel: 前 12 個畫在輪盤上（福點、莉莉絲與定位星僅列表格）。
  var PLANET_TABLE = [
    { glyph: "☉", wheel: true,  names: { "zh-TW": "太陽",   en: "Sun",        ja: "太陽",       ko: "태양" } },
    { glyph: "☽", wheel: true,  names: { "zh-TW": "月亮",   en: "Moon",       ja: "月",         ko: "달" } },
    { glyph: "☿", wheel: true,  names: { "zh-TW": "水星",   en: "Mercury",    ja: "水星",       ko: "수성" } },
    { glyph: "♀", wheel: true,  names: { "zh-TW": "金星",   en: "Venus",      ja: "金星",       ko: "금성" } },
    { glyph: "♂", wheel: true,  names: { "zh-TW": "火星",   en: "Mars",       ja: "火星",       ko: "화성" } },
    { glyph: "♃", wheel: true,  names: { "zh-TW": "木星",   en: "Jupiter",    ja: "木星",       ko: "목성" } },
    { glyph: "♄", wheel: true,  names: { "zh-TW": "土星",   en: "Saturn",     ja: "土星",       ko: "토성" } },
    { glyph: "♅", wheel: true,  names: { "zh-TW": "天王星", en: "Uranus",     ja: "天王星",     ko: "천왕성" } },
    { glyph: "♆", wheel: true,  names: { "zh-TW": "海王星", en: "Neptune",    ja: "海王星",     ko: "해왕성" } },
    { glyph: "♇", wheel: true,  names: { "zh-TW": "冥王星", en: "Pluto",      ja: "冥王星",     ko: "명왕성" } },
    { glyph: "☊", wheel: true,  names: { "zh-TW": "北交點", en: "North Node", ja: "ドラゴンヘッド", ko: "북교점" } },
    { glyph: "☋", wheel: true,  names: { "zh-TW": "南交點", en: "South Node", ja: "ドラゴンテイル", ko: "남교점" } },
    { glyph: "⊗", wheel: false, names: { "zh-TW": "福點",   en: "Part of Fortune", ja: "パート・オブ・フォーチュン", ko: "포르투나" } },
    { glyph: "⚸", wheel: false, names: { "zh-TW": "莉莉絲", en: "Lilith",     ja: "リリス",     ko: "릴리트" } }
  ];

  var PLANET_GLYPHS = {};  // 任一語言的行星名 → 符號
  var WHEEL_BODIES = {};   // 任一語言的行星名 → 是否畫上輪盤
  PLANET_TABLE.forEach(function (entry) {
    Object.keys(entry.names).forEach(function (lang) {
      var name = entry.names[lang];
      PLANET_GLYPHS[name] = entry.glyph;
      if (entry.wheel) WHEEL_BODIES[name] = true;
    });
  });

  var ZODIAC_GLYPHS = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"];
  var ZODIAC_NAMES = {
    "zh-TW": ["牡羊座", "金牛座", "雙子座", "巨蟹座", "獅子座", "處女座",
              "天秤座", "天蠍座", "射手座", "摩羯座", "水瓶座", "雙魚座"],
    en: ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
         "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"],
    ja: ["牡羊座", "牡牛座", "双子座", "蟹座", "獅子座", "乙女座",
         "天秤座", "蠍座", "射手座", "山羊座", "水瓶座", "魚座"],
    ko: ["양자리", "황소자리", "쌍둥이자리", "게자리", "사자자리", "처녀자리",
         "천칭자리", "전갈자리", "궁수자리", "염소자리", "물병자리", "물고기자리"]
  };
  var SIGN_INDEX = {}; // 任一語言的星座名 → 0–11
  Object.keys(ZODIAC_NAMES).forEach(function (lang) {
    ZODIAC_NAMES[lang].forEach(function (name, i) { SIGN_INDEX[name] = i; });
  });

  var ASPECT_TABLE = [
    { color: "#d3b877", names: { "zh-TW": "合相",   en: "Conjunction", ja: "コンジャンクション", ko: "컨정션" } },
    { color: "#5cb39e", names: { "zh-TW": "六分相", en: "Sextile",     ja: "セクスタイル",       ko: "섹스타일" } },
    { color: "#d9893c", names: { "zh-TW": "四分相", en: "Square",      ja: "スクエア",           ko: "스퀘어" } },
    { color: "#6b93d6", names: { "zh-TW": "三分相", en: "Trine",       ja: "トライン",           ko: "트라인" } },
    { color: "#c9574f", names: { "zh-TW": "對分相", en: "Opposition",  ja: "オポジション",       ko: "어포지션" } }
  ];
  var ASPECT_COLORS = {}; // 任一語言的相位名 → 顏色
  ASPECT_TABLE.forEach(function (entry) {
    Object.keys(entry.names).forEach(function (lang) {
      ASPECT_COLORS[entry.names[lang]] = entry.color;
    });
  });

  var ELEMENT_TABLE = [
    { color: "#c9574f", names: { "zh-TW": "火", en: "Fire",  ja: "火", ko: "불" } },
    { color: "#d3b877", names: { "zh-TW": "土", en: "Earth", ja: "地", ko: "흙" } },
    { color: "#6b93d6", names: { "zh-TW": "風", en: "Air",   ja: "風", ko: "공기" } },
    { color: "#5cb39e", names: { "zh-TW": "水", en: "Water", ja: "水", ko: "물" } }
  ];
  var MODALITY_TABLE = [
    { color: "#d3b877", names: { "zh-TW": "基本", en: "Cardinal", ja: "活動", ko: "활동궁" } },
    { color: "#d9893c", names: { "zh-TW": "固定", en: "Fixed",    ja: "不動", ko: "고정궁" } },
    { color: "#8d93ad", names: { "zh-TW": "變動", en: "Mutable",  ja: "柔軟", ko: "변통궁" } }
  ];

  // 輪盤配色以「屬性」寫入 SVG（而非 CSS class），使 SVG 可獨立序列化為 PNG。
  var W = {
    disc: "#0d1124",
    gold: "#d3b877",
    goldSoft: "#a8925a",
    line: "#242b49",
    muted: "#8d93ad",
    ink: "#e9e4d5",
    cusp: "#39406a",
    font: "'Noto Sans TC', 'PingFang TC', 'Microsoft JhengHei', sans-serif"
  };

  function $(id) { return document.getElementById(id); }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }

  function svgEl(tag, attrs) {
    var node = document.createElementNS(SVG_NS, tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) { node.setAttribute(k, String(attrs[k])); });
    }
    return node;
  }

  function fmtDeg(value) {
    var deg = Math.floor(value);
    var min = Math.round((value - deg) * 60);
    if (min === 60) { deg += 1; min = 0; }
    return deg + "°" + (min < 10 ? "0" + min : String(min)) + "′";
  }

  function houseLabel(n) { return tf("houseNth", { n: n }); }

  function buildTable(container, headers, rows, emptyText) {
    container.textContent = "";
    if (!rows.length) {
      container.appendChild(el("p", "empty", emptyText || t("emptyData")));
      return;
    }
    var table = el("table");
    var thead = el("thead");
    var headRow = el("tr");
    headers.forEach(function (h) { headRow.appendChild(el("th", null, h)); });
    thead.appendChild(headRow);
    table.appendChild(thead);
    var tbody = el("tbody");
    rows.forEach(function (cells) {
      var tr = el("tr");
      cells.forEach(function (cell) {
        var td = el("td");
        if (cell && cell.nodeType === 1) {
          td.appendChild(cell);
        } else {
          td.textContent = cell;
        }
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    container.appendChild(table);
  }

  function postJSON(url, payload) {
    payload.lang = LANG; // 所有 API 呼叫都帶目前語言，回應詞彙隨之翻譯
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    }).then(function (res) {
      return res.json().catch(function () { return null; }).then(function (data) {
        if (!res.ok) {
          var message = data && data.error && data.error.message
            ? data.error.message
            : tf("errServer", { s: res.status });
          throw new Error(message);
        }
        return data;
      });
    });
  }

  function personPayload(prefix) {
    var date = $(prefix + "-date").value;
    var time = $(prefix + "-time").value;
    var lat = parseFloat($(prefix + "-lat").value);
    var lng = parseFloat($(prefix + "-lng").value);
    if (!date) throw new Error(t("errDate"));
    if (!time) throw new Error(t("errTime"));
    if (!isFinite(lat) || !isFinite(lng)) throw new Error(t("errLatLng"));
    return {
      birth_date: date,
      birth_time: time,
      latitude: lat,
      longitude: lng,
      timezone: $(prefix + "-tz").value
    };
  }

  function optionalOrb(id) {
    var raw = $(id).value.trim();
    if (raw === "") return null;
    var v = parseFloat(raw);
    if (!isFinite(v) || v < 0) throw new Error(t("errOrb"));
    return v;
  }

  /* ---------- 星盤輪 ---------- */

  function houseTotalDegree(house) {
    // 宮首 degree 已是 0–360 的黃道絕對經度；僅在（假設性的）宮內度數輸入時
    // 才需要加上星座位移。星座名以四語反查表對回索引。
    if (house.degree >= 30) return house.degree;
    var signIndex = SIGN_INDEX[house.zodiac];
    return (signIndex === undefined ? 0 : signIndex) * 30 + house.degree;
  }

  function displayLongitudes(lons) {
    var MIN_SEP = 4.6;
    var items = lons.map(function (lon, i) {
      var norm = ((lon % 360) + 360) % 360;
      return { i: i, lon: norm, disp: norm };
    });
    items.sort(function (a, b) { return a.lon - b.lon; });
    for (var k = 1; k < items.length; k++) {
      if (items[k].disp - items[k - 1].disp < MIN_SEP) {
        items[k].disp = items[k - 1].disp + MIN_SEP;
      }
    }
    if (items.length > 1) {
      var wrapGap = items[0].disp + 360 - items[items.length - 1].disp;
      if (wrapGap < MIN_SEP) {
        items[items.length - 1].disp = items[0].disp + 360 - MIN_SEP;
      }
    }
    var out = [];
    items.forEach(function (it) { out[it.i] = it.disp; });
    return out;
  }

  function collectAspects(planets) {
    var seen = {};
    var out = [];
    planets.forEach(function (p) {
      (p.aspects || []).forEach(function (a) {
        var pair = [p.planet, a.planet].slice().sort();
        var key = pair[0] + "|" + pair[1] + "|" + a.aspect_type;
        if (seen[key]) return;
        seen[key] = true;
        out.push({ a: p.planet, b: a.planet, type: a.aspect_type, orb: a.orb });
      });
    });
    return out;
  }

  function wheelBodies(planets) {
    return planets.filter(function (p) {
      return Object.prototype.hasOwnProperty.call(WHEEL_BODIES, p.planet);
    });
  }

  function buildWheel(chart) {
    var C = 300;
    var R_OUT = 286;    // 黃道帶外圈
    var R_ZOD = 244;    // 黃道帶內圈
    var R_SIGN = 265;   // 星座符號
    var R_INNER = 176;  // 宮位號碼圈外緣
    var R_HUB = 148;    // 相位線區
    var R_PLANET = 208; // 行星符號
    var R_RETRO = 190;  // 逆行小標
    var R_TICK = 236;   // 行星刻度

    var asc = chart.ascendant.total_degree;

    function pt(lon, r) {
      var a = (180 - (lon - asc)) * Math.PI / 180;
      return [C + r * Math.cos(a), C + r * Math.sin(a)];
    }
    function line(lonA, rA, lonB, rB, stroke, width, opacity) {
      var p1 = pt(lonA, rA);
      var p2 = pt(lonB, rB);
      var attrs = {
        x1: p1[0], y1: p1[1], x2: p2[0], y2: p2[1],
        stroke: stroke, "stroke-width": width
      };
      if (opacity !== undefined) attrs.opacity = opacity;
      return svgEl("line", attrs);
    }
    function glyph(lon, r, text, fill, size) {
      var p = pt(lon, r);
      var node = svgEl("text", {
        x: p[0], y: p[1],
        fill: fill,
        "text-anchor": "middle",
        "dominant-baseline": "central",
        "font-size": size,
        "font-family": W.font
      });
      node.textContent = text;
      return node;
    }

    var svg = svgEl("svg", {
      xmlns: SVG_NS,
      viewBox: "0 0 600 600",
      "class": "wheel",
      role: "img",
      "aria-label": t("wheelAria")
    });

    // 底盤與同心圓
    svg.appendChild(svgEl("circle", { cx: C, cy: C, r: R_OUT, fill: W.disc }));
    svg.appendChild(svgEl("circle", { cx: C, cy: C, r: R_OUT, fill: "none", stroke: W.gold, "stroke-width": 2.5 }));
    svg.appendChild(svgEl("circle", { cx: C, cy: C, r: R_ZOD, fill: "none", stroke: W.goldSoft, "stroke-width": 1 }));
    svg.appendChild(svgEl("circle", { cx: C, cy: C, r: R_INNER, fill: "none", stroke: W.line, "stroke-width": 1 }));
    svg.appendChild(svgEl("circle", { cx: C, cy: C, r: R_HUB, fill: "none", stroke: W.line, "stroke-width": 1 }));

    // 黃道十二宮：界線與符號
    var i;
    for (i = 0; i < 12; i++) {
      svg.appendChild(line(i * 30, R_ZOD, i * 30, R_OUT, W.goldSoft, 1, 0.55));
      // U+FE0E 強制文字呈現，避免瀏覽器改用彩色 emoji 字型而蓋掉金色填色
      svg.appendChild(glyph(i * 30 + 15, R_SIGN, ZODIAC_GLYPHS[i] + "\uFE0E", W.gold, 21));
    }

    // 宮首線與宮位號碼
    var houses = chart.houses.slice().sort(function (a, b) {
      return a.house_number - b.house_number;
    });
    var cusps = houses.map(houseTotalDegree);
    for (i = 0; i < cusps.length; i++) {
      var major = [1, 4, 7, 10].indexOf(houses[i].house_number) >= 0;
      svg.appendChild(line(cusps[i], R_HUB, cusps[i], major ? R_OUT : R_ZOD,
        major ? W.goldSoft : W.cusp, major ? 1.6 : 1));
      var next = cusps[(i + 1) % cusps.length];
      var span = ((next - cusps[i]) % 360 + 360) % 360;
      if (span === 0) span = 30;
      svg.appendChild(glyph(cusps[i] + span / 2, (R_INNER + R_HUB) / 2,
        String(houses[i].house_number), W.muted, 12));
    }

    // 行星（僅 12 個實體天體／交點）
    var planets = wheelBodies(chart.planets);
    var lonByName = {};
    planets.forEach(function (p) { lonByName[p.planet] = p.total_degree; });

    // 相位線（畫在行星符號之下）
    collectAspects(planets).forEach(function (a) {
      if (!(a.a in lonByName) || !(a.b in lonByName)) return;
      svg.appendChild(line(lonByName[a.a], R_HUB, lonByName[a.b], R_HUB,
        ASPECT_COLORS[a.type] || W.muted, 1.3, 0.85));
    });

    var disp = displayLongitudes(planets.map(function (p) { return p.total_degree; }));
    planets.forEach(function (p, idx) {
      svg.appendChild(line(p.total_degree, R_TICK, p.total_degree, R_ZOD, W.gold, 1.5));
      svg.appendChild(line(p.total_degree, R_TICK, disp[idx], R_PLANET + 16, W.cusp, 0.75));
      svg.appendChild(glyph(disp[idx], R_PLANET, PLANET_GLYPHS[p.planet] + "\uFE0E", W.ink, 20));
      if (p.retrograde) {
        svg.appendChild(glyph(disp[idx], R_RETRO, "℞", W.goldSoft, 10));
      }
    });

    return svg;
  }

  /* ---------- PNG 下載 ---------- */

  function downloadWheelPNG(wrapId) {
    var wrap = $(wrapId);
    var svg = wrap ? wrap.querySelector("svg") : null;
    if (!svg) return;
    var clone = svg.cloneNode(true);
    clone.setAttribute("xmlns", SVG_NS);
    clone.setAttribute("width", "1200");
    clone.setAttribute("height", "1200");
    var xml = new XMLSerializer().serializeToString(clone);
    var img = new Image();
    img.onload = function () {
      var canvas = document.createElement("canvas");
      canvas.width = 1200;
      canvas.height = 1200;
      var ctx = canvas.getContext("2d");
      ctx.fillStyle = "#0a0d19";
      ctx.fillRect(0, 0, 1200, 1200);
      ctx.drawImage(img, 0, 0, 1200, 1200);
      canvas.toBlob(function (blob) {
        if (!blob) return;
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "astro-chart.png";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function () { URL.revokeObjectURL(a.href); }, 2000);
      }, "image/png");
    };
    img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(xml);
  }

  /* ---------- 結果渲染 ---------- */

  function buildLegend(container) {
    container.textContent = "";
    ASPECT_TABLE.forEach(function (entry) {
      var item = el("span", "legend-item");
      var swatch = el("span", "legend-swatch");
      swatch.style.backgroundColor = entry.color;
      item.appendChild(swatch);
      item.appendChild(el("span", null, entry.names[LANG] || entry.names["zh-TW"]));
      container.appendChild(item);
    });
  }

  function planetNameCell(p) {
    var wrap = el("span", "planet-name");
    wrap.appendChild(el("span", null, p.planet));
    if (p.retrograde) {
      var badge = el("span", "retro-badge", "℞");
      badge.setAttribute("title", t("retro"));
      wrap.appendChild(badge);
    }
    return wrap;
  }

  function planetTableRows(planets) {
    return planets.map(function (p) {
      return [
        planetNameCell(p),
        p.zodiac,
        fmtDeg(p.degree),
        p.house !== undefined && p.house !== null ? houseLabel(p.house) : "—"
      ];
    });
  }

  function renderChartInto(ids, chart) {
    var wheelWrap = $(ids.wheel);
    wheelWrap.textContent = "";
    wheelWrap.appendChild(buildWheel(chart));

    var ascText = t("ascendant") + " " + chart.ascendant.zodiac + " " + fmtDeg(chart.ascendant.degree);
    if (chart.house_system) {
      ascText += t("dotSep") + (chart.house_system === "W" ? t("hsWhole") : t("hsPlacidus"));
    }
    $(ids.asc).textContent = ascText;
    buildLegend($(ids.legend));

    buildTable($(ids.planets), [t("thPlanet"), t("thZodiac"), t("thDegree"), t("thHouse")],
      planetTableRows(chart.planets));

    buildTable($(ids.houses), [t("thHouse"), t("thZodiac"), t("thCusp")],
      chart.houses.map(function (h) {
        return [houseLabel(h.house_number), h.zodiac, fmtDeg(houseTotalDegree(h) % 30)];
      }));

    // 僅取十二個實體行星／交點：三個定位星的相位是其守護星相位的重新標名複本，
    // 納入會造成同一相位重複列出（與輪盤的過濾邏輯一致）。
    buildTable($(ids.aspects), [t("thPlanet"), t("thAspect"), t("thPlanet"), t("thOrb")],
      collectAspects(wheelBodies(chart.planets)).map(function (a) {
        return [a.a, a.type, a.b, a.orb.toFixed(2) + "°"];
      }), t("emptyAspects"));
  }

  function renderPatterns(container, patterns) {
    container.textContent = "";
    if (!patterns || !patterns.length) {
      container.appendChild(el("p", "empty", t("emptyPatterns")));
      return;
    }
    patterns.forEach(function (pat) {
      var card = el("div", "pattern-card");
      card.appendChild(el("div", "pattern-name", pat.pattern_type));
      card.appendChild(el("div", "pattern-planets", (pat.planets || []).join(t("listSep"))));
      // 以結構判斷圖形種類（不比對翻譯後的 pattern_type 字串）：
      // 大三角帶 element 欄位；T三角帶 apex。
      if (pat.apex) {
        card.appendChild(el("div", "pattern-extra", t("patApex") + pat.apex));
      } else if ("element" in pat) {
        card.appendChild(el("div", "pattern-extra",
          pat.element ? t("patElement") + pat.element : t("patCrossElement")));
      }
      container.appendChild(card);
    });
  }

  function lookupCount(counts, entry) {
    var langs = Object.keys(entry.names);
    for (var i = 0; i < langs.length; i++) {
      var name = entry.names[langs[i]];
      if (counts[name] !== undefined) return counts[name];
    }
    return null;
  }

  function statGroup(titleKey, counts, table, total) {
    var group = el("div", "stat-group");
    group.appendChild(el("h3", null, t(titleKey)));
    counts = counts || {};
    var known = table.some(function (entry) { return lookupCount(counts, entry) !== null; });
    var rows;
    if (known || !Object.keys(counts).length) {
      rows = table.map(function (entry) {
        var n = lookupCount(counts, entry);
        return {
          label: entry.names[LANG] || entry.names["zh-TW"],
          n: n === null ? 0 : n,
          color: entry.color
        };
      });
    } else {
      // 後端詞彙與內建表不一致時的保底：直接以回應的鍵順序呈現
      rows = Object.keys(counts).map(function (name, i) {
        return { label: name, n: counts[name], color: table[i % table.length].color };
      });
    }
    rows.forEach(function (r) {
      var row = el("div", "stat-row");
      row.appendChild(el("span", "stat-label", r.label));
      var track = el("div", "stat-track");
      var fill = el("div", "stat-fill");
      fill.style.width = (total > 0 ? (r.n / total) * 100 : 0) + "%";
      fill.style.backgroundColor = r.color;
      track.appendChild(fill);
      row.appendChild(track);
      row.appendChild(el("span", "stat-count", String(r.n)));
      group.appendChild(row);
    });
    return group;
  }

  function renderStats(container, stats) {
    container.textContent = "";
    if (!stats) {
      container.appendChild(el("p", "empty", t("emptyStats")));
      return;
    }
    container.appendChild(statGroup("statElements", stats.elements, ELEMENT_TABLE, 10));
    container.appendChild(statGroup("statModalities", stats.modalities, MODALITY_TABLE, 10));
  }

  function renderNatal(data) {
    var chart = data.chart;
    renderChartInto({
      wheel: "natal-wheel", asc: "natal-asc", legend: "natal-legend",
      planets: "natal-planets", houses: "natal-houses", aspects: "natal-aspects"
    }, chart);
    renderPatterns($("natal-patterns"), chart.patterns);
    renderStats($("natal-stats"), chart.element_stats);
  }

  function overlayRows(map) {
    return Object.keys(map).map(function (name) {
      return [name, houseLabel(map[name])];
    });
  }

  function renderSynastry(data) {
    var syn = data.synastry;
    buildTable($("syn-aspects"), [t("thAPlanet"), t("thAspect"), t("thBPlanet"), t("thOrb")],
      syn.aspects.map(function (a) {
        return [a.a_planet, a.aspect_type, a.b_planet, a.orb.toFixed(2) + "°"];
      }), t("emptySyn"));
    buildTable($("syn-a-in-b"), [t("thAPlanet"), t("thInBHouse")],
      overlayRows(syn.a_planets_in_b_houses));
    buildTable($("syn-b-in-a"), [t("thBPlanet"), t("thInAHouse")],
      overlayRows(syn.b_planets_in_a_houses));
  }

  function fmtMoment(iso) {
    if (!iso) return "";
    var d = new Date(iso);
    var text = iso.replace("T", " ").replace("Z", " UTC");
    if (!isNaN(d.getTime())) {
      text += tf("localTime", { t: d.toLocaleString() });
    }
    return text;
  }

  function movingPlanetRows(planets) {
    return (planets || []).map(function (p) {
      return [
        p.planet,
        p.zodiac,
        fmtDeg(p.degree),
        p.natal_house !== undefined && p.natal_house !== null
          ? houseLabel(p.natal_house) : "—"
      ];
    });
  }

  function renderTransits(data) {
    $("trans-time").textContent = t("transitTimeLabel") + fmtMoment(data.transit_time_utc);
    buildTable($("trans-planets"), [t("thTransPlanet"), t("thZodiac"), t("thDegree"), t("thNatalHouse")],
      movingPlanetRows(data.planets));
    buildTable($("trans-aspects"), [t("thTransPlanet"), t("thAspect"), t("thNatalPlanet"), t("thOrb")],
      (data.aspects || []).map(function (a) {
        return [a.transit_planet, a.aspect_type, a.natal_planet, a.orb.toFixed(2) + "°"];
      }), t("emptyTrans"));
  }

  function renderProgressions(data) {
    var prog = data.progression;
    $("prog-meta").textContent = tf("progMeta", { y: prog.years_elapsed });
    buildTable($("prog-planets"), [t("thProgPlanet"), t("thZodiac"), t("thDegree"), t("thNatalHouse")],
      movingPlanetRows(prog.planets));
    buildTable($("prog-aspects"), [t("thProgPlanet"), t("thAspect"), t("thNatalPlanet"), t("thOrb")],
      (prog.aspects_to_natal || []).map(function (a) {
        return [a.progressed_planet, a.aspect_type, a.natal_planet, a.orb.toFixed(2) + "°"];
      }), t("emptyProg"));
  }

  function renderSolar(data) {
    var sr = data.solar_return;
    var loc = sr.location || {};
    var meta = t("srTimeLabel") + fmtMoment(sr.return_time_utc);
    if (loc.latitude !== undefined && loc.longitude !== undefined) {
      meta += t("dotSep") + t("srLocLabel") + " " + loc.latitude + ", " + loc.longitude;
    }
    $("solar-time").textContent = meta;
    renderChartInto({
      wheel: "solar-wheel", asc: "solar-asc", legend: "solar-legend",
      planets: "solar-planets", houses: "solar-houses", aspects: "solar-aspects"
    }, sr.chart);
  }

  function renderComposite(data) {
    var comp = data.composite;
    buildTable($("comp-planets"), [t("thPlanet"), t("thZodiac"), t("thDegree")],
      (comp.planets || []).map(function (p) {
        return [p.planet, p.zodiac, fmtDeg(p.degree)];
      }));
    buildTable($("comp-aspects"), [t("thPlanet"), t("thAspect"), t("thPlanet"), t("thOrb")],
      (comp.aspects || []).map(function (a) {
        return [a.planet_a, a.aspect_type, a.planet_b, a.orb.toFixed(2) + "°"];
      }), t("emptyComp"));
  }

  /* ---------- 城市搜尋 ---------- */

  function initCitySearch(prefix) {
    var input = $(prefix + "-city");
    var drop = $(prefix + "-city-drop");
    if (!input || !drop) return;

    var items = [];
    var active = -1;
    var timer = null;
    var seq = 0;

    function close() {
      drop.hidden = true;
      drop.textContent = "";
      items = [];
      active = -1;
      input.setAttribute("aria-expanded", "false");
    }

    function select(city) {
      var latEl = $(prefix + "-lat");
      var lngEl = $(prefix + "-lng");
      if (latEl) latEl.value = city.latitude;
      if (lngEl) lngEl.value = city.longitude;
      // Every IANA zone is now an <option>, so just set the select directly.
      var sel = $(prefix + "-tz");
      if (sel && city.timezone) sel.value = city.timezone;
      input.value = city.name;
      close();
    }

    function highlight(idx) {
      active = idx;
      items.forEach(function (it, i) {
        it.li.classList.toggle("active", i === active);
      });
    }

    function render(cities) {
      close();
      if (!cities.length) return;
      cities.forEach(function (city, i) {
        var li = el("li", null);
        li.setAttribute("role", "option");
        li.appendChild(el("span", null, city.name));
        li.appendChild(el("span", "city-meta",
          (city.country || "") + " · " + (city.timezone || "")));
        li.addEventListener("mousedown", function (ev) {
          ev.preventDefault(); // 保持 input 焦點，避免 blur 先關閉選單
          select(city);
        });
        li.addEventListener("mousemove", function () { highlight(i); });
        drop.appendChild(li);
        items.push({ li: li, city: city });
      });
      drop.hidden = false;
      input.setAttribute("aria-expanded", "true");
    }

    function search(q) {
      var mySeq = ++seq;
      fetch("/api/v1/cities?q=" + encodeURIComponent(q) + "&lang=" + encodeURIComponent(LANG))
        .then(function (res) { return res.ok ? res.json() : null; })
        .then(function (data) {
          if (mySeq !== seq) return; // 過期回應
          render((data && data.data) || []);
        })
        .catch(function () { /* 搜尋失敗時安靜略過 */ });
    }

    input.addEventListener("input", function () {
      if (timer) clearTimeout(timer);
      var q = input.value.trim();
      if (!q) { seq++; close(); return; }
      timer = setTimeout(function () { search(q); }, 250);
    });

    input.addEventListener("keydown", function (ev) {
      if (drop.hidden || !items.length) return;
      if (ev.key === "ArrowDown") {
        ev.preventDefault();
        highlight((active + 1) % items.length);
      } else if (ev.key === "ArrowUp") {
        ev.preventDefault();
        highlight((active - 1 + items.length) % items.length);
      } else if (ev.key === "Enter") {
        if (active >= 0) {
          ev.preventDefault();
          select(items[active].city);
        }
      } else if (ev.key === "Escape") {
        close();
      }
    });

    input.addEventListener("blur", function () {
      // 取消尚未觸發的搜尋與作廢進行中的回應，避免選單在失焦後重新打開
      // （屆時沒有任何點擊能再關閉它）。
      if (timer) clearTimeout(timer);
      timer = null;
      seq++;
      setTimeout(close, 150);
    });
  }

  /* ---------- 語言切換 ---------- */

  function applyI18n() {
    var nodes = document.querySelectorAll("[data-i18n]");
    var i, node;
    for (i = 0; i < nodes.length; i++) {
      node = nodes[i];
      // disabled 的按鈕正處於暫態（推算中／已複製），由各自流程以 t() 復原
      if (node.disabled) continue;
      node.textContent = t(node.getAttribute("data-i18n"));
    }
    nodes = document.querySelectorAll("[data-i18n-placeholder]");
    for (i = 0; i < nodes.length; i++) {
      node = nodes[i];
      node.setAttribute("placeholder", t(node.getAttribute("data-i18n-placeholder")));
    }
    nodes = document.querySelectorAll("[data-i18n-aria]");
    for (i = 0; i < nodes.length; i++) {
      node = nodes[i];
      node.setAttribute("aria-label", t(node.getAttribute("data-i18n-aria")));
    }
    document.title = t("docTitle");
  }

  function setLang(code) {
    if (!I18N[code]) return;
    LANG = code;
    try { localStorage.setItem("astro_lang", code); } catch (e) { /* 私密模式等 */ }
    document.documentElement.setAttribute("lang", HTML_LANG[code]);
    applyI18n();
    var btns = document.querySelectorAll(".lang-btn");
    for (var i = 0; i < btns.length; i++) {
      var active = btns[i].getAttribute("data-lang") === code;
      btns[i].classList.toggle("active", active);
      btns[i].setAttribute("aria-pressed", active ? "true" : "false");
    }
  }

  function initLangSwitch() {
    var btns = document.querySelectorAll(".lang-btn");
    for (var i = 0; i < btns.length; i++) {
      (function (btn) {
        btn.addEventListener("click", function () {
          setLang(btn.getAttribute("data-lang"));
        });
      })(btns[i]);
    }
  }

  function storedLang() {
    try {
      var v = localStorage.getItem("astro_lang");
      if (v && I18N[v]) return v;
    } catch (e) { /* ignore */ }
    return null;
  }

  /* ---------- 分享連結 ---------- */

  function personShareMap(prefix, pfx) {
    return [
      [pfx + "bd", prefix + "-date"],
      [pfx + "bt", prefix + "-time"],
      [pfx + "lat", prefix + "-lat"],
      [pfx + "lng", prefix + "-lng"],
      [pfx + "tz", prefix + "-tz"]
    ];
  }

  var SHARE_MAPS = {
    natal: personShareMap("natal", "").concat([["hs", "natal-hs"]]),
    syn: personShareMap("a", "a").concat(personShareMap("b", "b"), [["orb", "syn-orb"]]),
    trans: personShareMap("tr", "").concat([
      ["ad", "tr-at-date"], ["at", "tr-at-time"],
      ["az", "tr-at-tz"],
      ["orb", "trans-orb"]
    ]),
    prog: personShareMap("pg", "").concat([["td", "pg-target"], ["orb", "pg-orb"]]),
    solar: personShareMap("sr", "").concat([
      ["yr", "sr-year"], ["slat", "srloc-lat"],
      ["slng", "srloc-lng"], ["stz", "srloc-tz"]
    ]),
    comp: personShareMap("ca", "a").concat(personShareMap("cb", "b"))
  };

  var FORMS = {
    natal: "natal-form", syn: "syn-form", trans: "trans-form",
    prog: "prog-form", solar: "solar-form", comp: "comp-form"
  };

  function buildShareURL(tabKey) {
    var params = new URLSearchParams();
    params.set("tab", tabKey);
    params.set("lang", LANG);
    SHARE_MAPS[tabKey].forEach(function (m) {
      var node = $(m[1]);
      // 空值也要寫入：欄位被清空（例如合盤容許度留空＝用預設容許度）時，
      // 收到連結的人才會還原成一樣的空值，而不是跳回 HTML 預設值。
      if (node) params.set(m[0], node.value);
    });
    return location.origin + location.pathname + "?" + params.toString();
  }

  function bindShare(buttonId, tabKey) {
    var btn = $(buttonId);
    if (!btn) return;
    btn.addEventListener("click", function () {
      var url = buildShareURL(tabKey);
      try { history.replaceState(null, "", url); } catch (e) { /* file:// 等情境 */ }
      var done = function () {
        btn.textContent = t("copied");
        btn.disabled = true;
        setTimeout(function () {
          btn.textContent = t(btn.getAttribute("data-i18n"));
          btn.disabled = false;
        }, 1600);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(url).then(done, function () {
          window.prompt(t("copyPrompt"), url);
        });
      } else {
        window.prompt(t("copyPrompt"), url);
      }
    });
  }

  function restoreFromURL() {
    var params = new URLSearchParams(location.search);
    var lang = params.get("lang");
    if (lang && I18N[lang]) setLang(lang); // 連結中的語言優先於 localStorage
    var tab = params.get("tab");
    if (!tab || !SHARE_MAPS[tab]) return;
    SHARE_MAPS[tab].forEach(function (m) {
      var v = params.get(m[0]);
      if (v === null) return;
      var node = $(m[1]);
      if (node) node.value = v;
    });
    activateTab(tab);
    var form = $(FORMS[tab]);
    if (!form) return;
    if (form.requestSubmit) {
      form.requestSubmit();
    } else {
      form.dispatchEvent(new Event("submit", { cancelable: true }));
    }
  }

  /* ---------- 表單與分頁 ---------- */

  function bindForm(opts) {
    $(opts.form).addEventListener("submit", function (ev) {
      ev.preventDefault();
      var btn = $(opts.button);
      var errBox = $(opts.error);
      var result = $(opts.result);
      errBox.hidden = true;

      var payload;
      try {
        payload = opts.payload();
      } catch (e) {
        result.hidden = true;
        errBox.textContent = e.message;
        errBox.hidden = false;
        return;
      }

      btn.disabled = true;
      btn.textContent = t("loading");

      postJSON(opts.url, payload)
        .then(function (data) {
          opts.render(data.data);
          result.hidden = false;
        })
        .catch(function (e) {
          result.hidden = true;
          errBox.textContent = e && e.message ? e.message : t("errUnknown");
          errBox.hidden = false;
        })
        .then(function () {
          btn.disabled = false;
          btn.textContent = t(btn.getAttribute("data-i18n"));
        });
    });
  }

  var TABS = [
    { key: "natal", btn: "tab-natal", panel: "panel-natal" },
    { key: "syn", btn: "tab-syn", panel: "panel-syn" },
    { key: "trans", btn: "tab-trans", panel: "panel-trans" },
    { key: "prog", btn: "tab-prog", panel: "panel-prog" },
    { key: "solar", btn: "tab-solar", panel: "panel-solar" },
    { key: "comp", btn: "tab-comp", panel: "panel-comp" }
  ];

  function activateTab(key) {
    TABS.forEach(function (t) {
      var active = t.key === key;
      var btn = $(t.btn);
      var panel = $(t.panel);
      btn.classList.toggle("active", active);
      btn.setAttribute("aria-selected", active ? "true" : "false");
      panel.hidden = !active;
    });
  }

  function initTabs() {
    TABS.forEach(function (t) {
      $(t.btn).addEventListener("click", function () { activateTab(t.key); });
    });
  }

  /* ---------- 各分頁 payload ---------- */

  function natalPayload() {
    var p = personPayload("natal");
    p.house_system = $("natal-hs").value;
    return p;
  }

  function synPayload() {
    var orb = optionalOrb("syn-orb");
    return { a: personPayload("a"), b: personPayload("b"), orb_limit: orb };
  }

  function transPayload() {
    var payload = { natal: personPayload("tr") };
    var d = $("tr-at-date").value;
    var t2 = $("tr-at-time").value;
    if (d || t2) {
      if (!d || !t2) {
        throw new Error(t("errTransAt"));
      }
      payload.at = { date: d, time: t2, timezone: $("tr-at-tz").value };
    }
    var orb = optionalOrb("trans-orb");
    if (orb !== null) payload.orb_limit = orb;
    return payload;
  }

  function progPayload() {
    var target = $("pg-target").value;
    if (!target) throw new Error(t("errTarget"));
    var payload = { natal: personPayload("pg"), target_date: target };
    var orb = optionalOrb("pg-orb");
    if (orb !== null) payload.orb_limit = orb;
    return payload;
  }

  function solarPayload() {
    var yr = parseInt($("sr-year").value, 10);
    if (!isFinite(yr)) throw new Error(t("errYear"));
    var payload = { natal: personPayload("sr"), year: yr };
    var latRaw = $("srloc-lat").value.trim();
    var lngRaw = $("srloc-lng").value.trim();
    if (latRaw !== "" || lngRaw !== "") {
      var lat = parseFloat(latRaw);
      var lng = parseFloat(lngRaw);
      if (!isFinite(lat) || !isFinite(lng)) {
        throw new Error(t("errSrLoc"));
      }
      payload.latitude = lat;
      payload.longitude = lng;
    }
    var tz = $("srloc-tz").value;
    if (tz !== "") payload.timezone = tz;
    return payload;
  }

  function compPayload() {
    return { a: personPayload("ca"), b: personPayload("cb") };
  }

  /* ---------- 初始化 ---------- */

  initTabs();
  initLangSwitch();
  setLang(storedLang() || "zh-TW");

  bindForm({
    form: "natal-form", button: "natal-submit", error: "natal-error",
    result: "natal-result", url: "/api/v1/charts",
    payload: natalPayload, render: renderNatal
  });

  bindForm({
    form: "syn-form", button: "syn-submit", error: "syn-error",
    result: "syn-result", url: "/api/v1/synastry",
    payload: synPayload, render: renderSynastry
  });

  bindForm({
    form: "trans-form", button: "trans-submit", error: "trans-error",
    result: "trans-result", url: "/api/v1/transits",
    payload: transPayload, render: renderTransits
  });

  bindForm({
    form: "prog-form", button: "prog-submit", error: "prog-error",
    result: "prog-result", url: "/api/v1/progressions",
    payload: progPayload, render: renderProgressions
  });

  bindForm({
    form: "solar-form", button: "solar-submit", error: "solar-error",
    result: "solar-result", url: "/api/v1/solar-return",
    payload: solarPayload, render: renderSolar
  });

  bindForm({
    form: "comp-form", button: "comp-submit", error: "comp-error",
    result: "comp-result", url: "/api/v1/composite",
    payload: compPayload, render: renderComposite
  });

  ["natal", "a", "b", "tr", "pg", "sr", "srloc", "ca", "cb"].forEach(initCitySearch);

  bindShare("natal-share", "natal");
  bindShare("syn-share", "syn");
  bindShare("trans-share", "trans");
  bindShare("prog-share", "prog");
  bindShare("solar-share", "solar");
  bindShare("comp-share", "comp");

  var natalPng = $("natal-png");
  if (natalPng) {
    natalPng.addEventListener("click", function () { downloadWheelPNG("natal-wheel"); });
  }
  var solarPng = $("solar-png");
  if (solarPng) {
    solarPng.addEventListener("click", function () { downloadWheelPNG("solar-wheel"); });
  }

  restoreFromURL();
})();
