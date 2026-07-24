module Cities
  # City database for the /api/v1/cities lookup endpoint.
  #
  # Every entry:
  #   "name"      => 中文名稱（主要顯示名）
  #   "alt"       => 英文 / 拼音別名（僅供搜尋比對，不回傳）
  #   "country"   => 國家/地區（中文）
  #   "latitude"  => 緯度
  #   "longitude" => 經度
  #   "timezone"  => IANA 時區識別碼
  #
  # 台灣 22 縣市使用縣市政府所在地座標。
  CITIES = [
    # --- 台灣 22 縣市 ---
    { "name" => "台北市", "alt" => ["Taipei", "taibei"], "country" => "台灣", "latitude" => 25.0330, "longitude" => 121.5654, "timezone" => "Asia/Taipei" },
    { "name" => "新北市", "alt" => ["New Taipei", "Banqiao", "xinbei"], "country" => "台灣", "latitude" => 25.0120, "longitude" => 121.4657, "timezone" => "Asia/Taipei" },
    { "name" => "桃園市", "alt" => ["Taoyuan"], "country" => "台灣", "latitude" => 24.9936, "longitude" => 121.3010, "timezone" => "Asia/Taipei" },
    { "name" => "台中市", "alt" => ["Taichung", "taizhong"], "country" => "台灣", "latitude" => 24.1477, "longitude" => 120.6736, "timezone" => "Asia/Taipei" },
    { "name" => "台南市", "alt" => ["Tainan"], "country" => "台灣", "latitude" => 22.9999, "longitude" => 120.2269, "timezone" => "Asia/Taipei" },
    { "name" => "高雄市", "alt" => ["Kaohsiung", "gaoxiong"], "country" => "台灣", "latitude" => 22.6273, "longitude" => 120.3014, "timezone" => "Asia/Taipei" },
    { "name" => "基隆市", "alt" => ["Keelung", "jilong"], "country" => "台灣", "latitude" => 25.1276, "longitude" => 121.7392, "timezone" => "Asia/Taipei" },
    { "name" => "新竹市", "alt" => ["Hsinchu", "xinzhu"], "country" => "台灣", "latitude" => 24.8138, "longitude" => 120.9675, "timezone" => "Asia/Taipei" },
    { "name" => "嘉義市", "alt" => ["Chiayi", "jiayi"], "country" => "台灣", "latitude" => 23.4801, "longitude" => 120.4491, "timezone" => "Asia/Taipei" },
    { "name" => "新竹縣", "alt" => ["Hsinchu County", "Zhubei"], "country" => "台灣", "latitude" => 24.8387, "longitude" => 121.0177, "timezone" => "Asia/Taipei" },
    { "name" => "苗栗縣", "alt" => ["Miaoli"], "country" => "台灣", "latitude" => 24.5602, "longitude" => 120.8214, "timezone" => "Asia/Taipei" },
    { "name" => "彰化縣", "alt" => ["Changhua", "zhanghua"], "country" => "台灣", "latitude" => 24.0518, "longitude" => 120.5161, "timezone" => "Asia/Taipei" },
    { "name" => "南投縣", "alt" => ["Nantou"], "country" => "台灣", "latitude" => 23.9609, "longitude" => 120.9719, "timezone" => "Asia/Taipei" },
    { "name" => "雲林縣", "alt" => ["Yunlin", "Douliu"], "country" => "台灣", "latitude" => 23.7092, "longitude" => 120.4313, "timezone" => "Asia/Taipei" },
    { "name" => "嘉義縣", "alt" => ["Chiayi County", "Taibao"], "country" => "台灣", "latitude" => 23.4518, "longitude" => 120.2555, "timezone" => "Asia/Taipei" },
    { "name" => "屏東縣", "alt" => ["Pingtung", "pingdong"], "country" => "台灣", "latitude" => 22.5519, "longitude" => 120.5487, "timezone" => "Asia/Taipei" },
    { "name" => "宜蘭縣", "alt" => ["Yilan", "Ilan"], "country" => "台灣", "latitude" => 24.7021, "longitude" => 121.7378, "timezone" => "Asia/Taipei" },
    { "name" => "花蓮縣", "alt" => ["Hualien", "hualian"], "country" => "台灣", "latitude" => 23.9872, "longitude" => 121.6015, "timezone" => "Asia/Taipei" },
    { "name" => "台東縣", "alt" => ["Taitung", "taidong"], "country" => "台灣", "latitude" => 22.7583, "longitude" => 121.1444, "timezone" => "Asia/Taipei" },
    { "name" => "澎湖縣", "alt" => ["Penghu", "Magong"], "country" => "台灣", "latitude" => 23.5711, "longitude" => 119.5793, "timezone" => "Asia/Taipei" },
    { "name" => "金門縣", "alt" => ["Kinmen", "Jincheng", "jinmen"], "country" => "台灣", "latitude" => 24.4321, "longitude" => 118.3171, "timezone" => "Asia/Taipei" },
    { "name" => "連江縣", "alt" => ["Lienchiang", "Matsu", "Nangan", "mazu"], "country" => "台灣", "latitude" => 26.1608, "longitude" => 119.9389, "timezone" => "Asia/Taipei" },

    # --- 亞洲 ---
    { "name" => "東京", "alt" => ["Tokyo"], "country" => "日本", "latitude" => 35.6762, "longitude" => 139.6503, "timezone" => "Asia/Tokyo" },
    { "name" => "大阪", "alt" => ["Osaka"], "country" => "日本", "latitude" => 34.6937, "longitude" => 135.5023, "timezone" => "Asia/Tokyo" },
    { "name" => "京都", "alt" => ["Kyoto"], "country" => "日本", "latitude" => 35.0116, "longitude" => 135.7681, "timezone" => "Asia/Tokyo" },
    { "name" => "札幌", "alt" => ["Sapporo"], "country" => "日本", "latitude" => 43.0618, "longitude" => 141.3545, "timezone" => "Asia/Tokyo" },
    { "name" => "福岡", "alt" => ["Fukuoka"], "country" => "日本", "latitude" => 33.5904, "longitude" => 130.4017, "timezone" => "Asia/Tokyo" },
    { "name" => "名古屋", "alt" => ["Nagoya"], "country" => "日本", "latitude" => 35.1815, "longitude" => 136.9066, "timezone" => "Asia/Tokyo" },
    { "name" => "沖繩", "alt" => ["Okinawa", "Naha"], "country" => "日本", "latitude" => 26.2124, "longitude" => 127.6809, "timezone" => "Asia/Tokyo" },
    { "name" => "首爾", "alt" => ["Seoul"], "country" => "韓國", "latitude" => 37.5665, "longitude" => 126.9780, "timezone" => "Asia/Seoul" },
    { "name" => "釜山", "alt" => ["Busan", "Pusan"], "country" => "韓國", "latitude" => 35.1796, "longitude" => 129.0756, "timezone" => "Asia/Seoul" },
    { "name" => "北京", "alt" => ["Beijing", "Peking"], "country" => "中國", "latitude" => 39.9042, "longitude" => 116.4074, "timezone" => "Asia/Shanghai" },
    { "name" => "上海", "alt" => ["Shanghai"], "country" => "中國", "latitude" => 31.2304, "longitude" => 121.4737, "timezone" => "Asia/Shanghai" },
    { "name" => "廣州", "alt" => ["Guangzhou", "Canton"], "country" => "中國", "latitude" => 23.1291, "longitude" => 113.2644, "timezone" => "Asia/Shanghai" },
    { "name" => "深圳", "alt" => ["Shenzhen"], "country" => "中國", "latitude" => 22.5431, "longitude" => 114.0579, "timezone" => "Asia/Shanghai" },
    { "name" => "成都", "alt" => ["Chengdu"], "country" => "中國", "latitude" => 30.5728, "longitude" => 104.0668, "timezone" => "Asia/Shanghai" },
    { "name" => "重慶", "alt" => ["Chongqing"], "country" => "中國", "latitude" => 29.5630, "longitude" => 106.5516, "timezone" => "Asia/Shanghai" },
    { "name" => "杭州", "alt" => ["Hangzhou"], "country" => "中國", "latitude" => 30.2741, "longitude" => 120.1551, "timezone" => "Asia/Shanghai" },
    { "name" => "西安", "alt" => ["Xi'an", "Xian"], "country" => "中國", "latitude" => 34.3416, "longitude" => 108.9398, "timezone" => "Asia/Shanghai" },
    { "name" => "香港", "alt" => ["Hong Kong", "Hongkong", "xianggang"], "country" => "香港", "latitude" => 22.3193, "longitude" => 114.1694, "timezone" => "Asia/Hong_Kong" },
    { "name" => "澳門", "alt" => ["Macau", "Macao", "aomen"], "country" => "澳門", "latitude" => 22.1987, "longitude" => 113.5439, "timezone" => "Asia/Macau" },
    { "name" => "新加坡", "alt" => ["Singapore"], "country" => "新加坡", "latitude" => 1.3521, "longitude" => 103.8198, "timezone" => "Asia/Singapore" },
    { "name" => "吉隆坡", "alt" => ["Kuala Lumpur"], "country" => "馬來西亞", "latitude" => 3.1390, "longitude" => 101.6869, "timezone" => "Asia/Kuala_Lumpur" },
    { "name" => "曼谷", "alt" => ["Bangkok"], "country" => "泰國", "latitude" => 13.7563, "longitude" => 100.5018, "timezone" => "Asia/Bangkok" },
    { "name" => "河內", "alt" => ["Hanoi"], "country" => "越南", "latitude" => 21.0285, "longitude" => 105.8542, "timezone" => "Asia/Ho_Chi_Minh" },
    { "name" => "胡志明市", "alt" => ["Ho Chi Minh City", "Saigon"], "country" => "越南", "latitude" => 10.8231, "longitude" => 106.6297, "timezone" => "Asia/Ho_Chi_Minh" },
    { "name" => "馬尼拉", "alt" => ["Manila"], "country" => "菲律賓", "latitude" => 14.5995, "longitude" => 120.9842, "timezone" => "Asia/Manila" },
    { "name" => "雅加達", "alt" => ["Jakarta"], "country" => "印尼", "latitude" => -6.2088, "longitude" => 106.8456, "timezone" => "Asia/Jakarta" },
    { "name" => "峇里島", "alt" => ["Bali", "Denpasar"], "country" => "印尼", "latitude" => -8.6705, "longitude" => 115.2126, "timezone" => "Asia/Makassar" },
    { "name" => "金邊", "alt" => ["Phnom Penh"], "country" => "柬埔寨", "latitude" => 11.5564, "longitude" => 104.9282, "timezone" => "Asia/Phnom_Penh" },
    { "name" => "仰光", "alt" => ["Yangon", "Rangoon"], "country" => "緬甸", "latitude" => 16.8409, "longitude" => 96.1735, "timezone" => "Asia/Yangon" },
    { "name" => "新德里", "alt" => ["New Delhi", "Delhi"], "country" => "印度", "latitude" => 28.6139, "longitude" => 77.2090, "timezone" => "Asia/Kolkata" },
    { "name" => "孟買", "alt" => ["Mumbai", "Bombay"], "country" => "印度", "latitude" => 19.0760, "longitude" => 72.8777, "timezone" => "Asia/Kolkata" },
    { "name" => "班加羅爾", "alt" => ["Bangalore", "Bengaluru"], "country" => "印度", "latitude" => 12.9716, "longitude" => 77.5946, "timezone" => "Asia/Kolkata" },
    { "name" => "加爾各答", "alt" => ["Kolkata", "Calcutta"], "country" => "印度", "latitude" => 22.5726, "longitude" => 88.3639, "timezone" => "Asia/Kolkata" },
    { "name" => "喀拉蚩", "alt" => ["Karachi"], "country" => "巴基斯坦", "latitude" => 24.8607, "longitude" => 67.0011, "timezone" => "Asia/Karachi" },
    { "name" => "達卡", "alt" => ["Dhaka"], "country" => "孟加拉", "latitude" => 23.8103, "longitude" => 90.4125, "timezone" => "Asia/Dhaka" },
    { "name" => "可倫坡", "alt" => ["Colombo"], "country" => "斯里蘭卡", "latitude" => 6.9271, "longitude" => 79.8612, "timezone" => "Asia/Colombo" },
    { "name" => "加德滿都", "alt" => ["Kathmandu"], "country" => "尼泊爾", "latitude" => 27.7172, "longitude" => 85.3240, "timezone" => "Asia/Kathmandu" },
    { "name" => "杜拜", "alt" => ["Dubai"], "country" => "阿拉伯聯合大公國", "latitude" => 25.2048, "longitude" => 55.2708, "timezone" => "Asia/Dubai" },
    { "name" => "阿布達比", "alt" => ["Abu Dhabi"], "country" => "阿拉伯聯合大公國", "latitude" => 24.4539, "longitude" => 54.3773, "timezone" => "Asia/Dubai" },
    { "name" => "利雅德", "alt" => ["Riyadh"], "country" => "沙烏地阿拉伯", "latitude" => 24.7136, "longitude" => 46.6753, "timezone" => "Asia/Riyadh" },
    { "name" => "杜哈", "alt" => ["Doha"], "country" => "卡達", "latitude" => 25.2854, "longitude" => 51.5310, "timezone" => "Asia/Qatar" },
    { "name" => "特拉維夫", "alt" => ["Tel Aviv"], "country" => "以色列", "latitude" => 32.0853, "longitude" => 34.7818, "timezone" => "Asia/Jerusalem" },
    { "name" => "耶路撒冷", "alt" => ["Jerusalem"], "country" => "以色列", "latitude" => 31.7683, "longitude" => 35.2137, "timezone" => "Asia/Jerusalem" },
    { "name" => "德黑蘭", "alt" => ["Tehran"], "country" => "伊朗", "latitude" => 35.6892, "longitude" => 51.3890, "timezone" => "Asia/Tehran" },
    { "name" => "巴格達", "alt" => ["Baghdad"], "country" => "伊拉克", "latitude" => 33.3152, "longitude" => 44.3661, "timezone" => "Asia/Baghdad" },
    { "name" => "烏蘭巴托", "alt" => ["Ulaanbaatar", "Ulan Bator"], "country" => "蒙古", "latitude" => 47.8864, "longitude" => 106.9057, "timezone" => "Asia/Ulaanbaatar" },
    { "name" => "阿拉木圖", "alt" => ["Almaty"], "country" => "哈薩克", "latitude" => 43.2220, "longitude" => 76.8512, "timezone" => "Asia/Almaty" },

    # --- 歐洲 ---
    { "name" => "倫敦", "alt" => ["London"], "country" => "英國", "latitude" => 51.5074, "longitude" => -0.1278, "timezone" => "Europe/London" },
    { "name" => "曼徹斯特", "alt" => ["Manchester"], "country" => "英國", "latitude" => 53.4808, "longitude" => -2.2426, "timezone" => "Europe/London" },
    { "name" => "愛丁堡", "alt" => ["Edinburgh"], "country" => "英國", "latitude" => 55.9533, "longitude" => -3.1883, "timezone" => "Europe/London" },
    { "name" => "都柏林", "alt" => ["Dublin"], "country" => "愛爾蘭", "latitude" => 53.3498, "longitude" => -6.2603, "timezone" => "Europe/Dublin" },
    { "name" => "巴黎", "alt" => ["Paris"], "country" => "法國", "latitude" => 48.8566, "longitude" => 2.3522, "timezone" => "Europe/Paris" },
    { "name" => "里昂", "alt" => ["Lyon"], "country" => "法國", "latitude" => 45.7640, "longitude" => 4.8357, "timezone" => "Europe/Paris" },
    { "name" => "柏林", "alt" => ["Berlin"], "country" => "德國", "latitude" => 52.5200, "longitude" => 13.4050, "timezone" => "Europe/Berlin" },
    { "name" => "慕尼黑", "alt" => ["Munich", "Muenchen"], "country" => "德國", "latitude" => 48.1351, "longitude" => 11.5820, "timezone" => "Europe/Berlin" },
    { "name" => "法蘭克福", "alt" => ["Frankfurt"], "country" => "德國", "latitude" => 50.1109, "longitude" => 8.6821, "timezone" => "Europe/Berlin" },
    { "name" => "漢堡", "alt" => ["Hamburg"], "country" => "德國", "latitude" => 53.5511, "longitude" => 9.9937, "timezone" => "Europe/Berlin" },
    { "name" => "阿姆斯特丹", "alt" => ["Amsterdam"], "country" => "荷蘭", "latitude" => 52.3676, "longitude" => 4.9041, "timezone" => "Europe/Amsterdam" },
    { "name" => "布魯塞爾", "alt" => ["Brussels"], "country" => "比利時", "latitude" => 50.8503, "longitude" => 4.3517, "timezone" => "Europe/Brussels" },
    { "name" => "盧森堡", "alt" => ["Luxembourg"], "country" => "盧森堡", "latitude" => 49.6116, "longitude" => 6.1319, "timezone" => "Europe/Luxembourg" },
    { "name" => "蘇黎世", "alt" => ["Zurich", "Zuerich"], "country" => "瑞士", "latitude" => 47.3769, "longitude" => 8.5417, "timezone" => "Europe/Zurich" },
    { "name" => "日內瓦", "alt" => ["Geneva"], "country" => "瑞士", "latitude" => 46.2044, "longitude" => 6.1432, "timezone" => "Europe/Zurich" },
    { "name" => "維也納", "alt" => ["Vienna", "Wien"], "country" => "奧地利", "latitude" => 48.2082, "longitude" => 16.3738, "timezone" => "Europe/Vienna" },
    { "name" => "布拉格", "alt" => ["Prague", "Praha"], "country" => "捷克", "latitude" => 50.0755, "longitude" => 14.4378, "timezone" => "Europe/Prague" },
    { "name" => "華沙", "alt" => ["Warsaw", "Warszawa"], "country" => "波蘭", "latitude" => 52.2297, "longitude" => 21.0122, "timezone" => "Europe/Warsaw" },
    { "name" => "布達佩斯", "alt" => ["Budapest"], "country" => "匈牙利", "latitude" => 47.4979, "longitude" => 19.0402, "timezone" => "Europe/Budapest" },
    { "name" => "羅馬", "alt" => ["Rome", "Roma"], "country" => "義大利", "latitude" => 41.9028, "longitude" => 12.4964, "timezone" => "Europe/Rome" },
    { "name" => "米蘭", "alt" => ["Milan", "Milano"], "country" => "義大利", "latitude" => 45.4642, "longitude" => 9.1900, "timezone" => "Europe/Rome" },
    { "name" => "威尼斯", "alt" => ["Venice", "Venezia"], "country" => "義大利", "latitude" => 45.4408, "longitude" => 12.3155, "timezone" => "Europe/Rome" },
    { "name" => "馬德里", "alt" => ["Madrid"], "country" => "西班牙", "latitude" => 40.4168, "longitude" => -3.7038, "timezone" => "Europe/Madrid" },
    { "name" => "巴塞隆納", "alt" => ["Barcelona"], "country" => "西班牙", "latitude" => 41.3874, "longitude" => 2.1686, "timezone" => "Europe/Madrid" },
    { "name" => "里斯本", "alt" => ["Lisbon", "Lisboa"], "country" => "葡萄牙", "latitude" => 38.7223, "longitude" => -9.1393, "timezone" => "Europe/Lisbon" },
    { "name" => "雅典", "alt" => ["Athens"], "country" => "希臘", "latitude" => 37.9838, "longitude" => 23.7275, "timezone" => "Europe/Athens" },
    { "name" => "伊斯坦堡", "alt" => ["Istanbul"], "country" => "土耳其", "latitude" => 41.0082, "longitude" => 28.9784, "timezone" => "Europe/Istanbul" },
    { "name" => "哥本哈根", "alt" => ["Copenhagen"], "country" => "丹麥", "latitude" => 55.6761, "longitude" => 12.5683, "timezone" => "Europe/Copenhagen" },
    { "name" => "斯德哥爾摩", "alt" => ["Stockholm"], "country" => "瑞典", "latitude" => 59.3293, "longitude" => 18.0686, "timezone" => "Europe/Stockholm" },
    { "name" => "奧斯陸", "alt" => ["Oslo"], "country" => "挪威", "latitude" => 59.9139, "longitude" => 10.7522, "timezone" => "Europe/Oslo" },
    { "name" => "赫爾辛基", "alt" => ["Helsinki"], "country" => "芬蘭", "latitude" => 60.1699, "longitude" => 24.9384, "timezone" => "Europe/Helsinki" },
    { "name" => "雷克雅維克", "alt" => ["Reykjavik"], "country" => "冰島", "latitude" => 64.1466, "longitude" => -21.9426, "timezone" => "Atlantic/Reykjavik" },
    { "name" => "莫斯科", "alt" => ["Moscow", "Moskva"], "country" => "俄羅斯", "latitude" => 55.7558, "longitude" => 37.6173, "timezone" => "Europe/Moscow" },
    { "name" => "聖彼得堡", "alt" => ["Saint Petersburg", "St Petersburg"], "country" => "俄羅斯", "latitude" => 59.9311, "longitude" => 30.3609, "timezone" => "Europe/Moscow" },
    { "name" => "基輔", "alt" => ["Kyiv", "Kiev"], "country" => "烏克蘭", "latitude" => 50.4501, "longitude" => 30.5234, "timezone" => "Europe/Kyiv" },
    { "name" => "布加勒斯特", "alt" => ["Bucharest"], "country" => "羅馬尼亞", "latitude" => 44.4268, "longitude" => 26.1025, "timezone" => "Europe/Bucharest" },

    # --- 北美洲 ---
    { "name" => "紐約", "alt" => ["New York", "NYC"], "country" => "美國", "latitude" => 40.7128, "longitude" => -74.0060, "timezone" => "America/New_York" },
    { "name" => "洛杉磯", "alt" => ["Los Angeles", "LA"], "country" => "美國", "latitude" => 34.0522, "longitude" => -118.2437, "timezone" => "America/Los_Angeles" },
    { "name" => "舊金山", "alt" => ["San Francisco"], "country" => "美國", "latitude" => 37.7749, "longitude" => -122.4194, "timezone" => "America/Los_Angeles" },
    { "name" => "西雅圖", "alt" => ["Seattle"], "country" => "美國", "latitude" => 47.6062, "longitude" => -122.3321, "timezone" => "America/Los_Angeles" },
    { "name" => "芝加哥", "alt" => ["Chicago"], "country" => "美國", "latitude" => 41.8781, "longitude" => -87.6298, "timezone" => "America/Chicago" },
    { "name" => "休士頓", "alt" => ["Houston"], "country" => "美國", "latitude" => 29.7604, "longitude" => -95.3698, "timezone" => "America/Chicago" },
    { "name" => "達拉斯", "alt" => ["Dallas"], "country" => "美國", "latitude" => 32.7767, "longitude" => -96.7970, "timezone" => "America/Chicago" },
    { "name" => "邁阿密", "alt" => ["Miami"], "country" => "美國", "latitude" => 25.7617, "longitude" => -80.1918, "timezone" => "America/New_York" },
    { "name" => "波士頓", "alt" => ["Boston"], "country" => "美國", "latitude" => 42.3601, "longitude" => -71.0589, "timezone" => "America/New_York" },
    { "name" => "華盛頓哥倫比亞特區", "alt" => ["Washington", "Washington DC"], "country" => "美國", "latitude" => 38.9072, "longitude" => -77.0369, "timezone" => "America/New_York" },
    { "name" => "亞特蘭大", "alt" => ["Atlanta"], "country" => "美國", "latitude" => 33.7490, "longitude" => -84.3880, "timezone" => "America/New_York" },
    { "name" => "丹佛", "alt" => ["Denver"], "country" => "美國", "latitude" => 39.7392, "longitude" => -104.9903, "timezone" => "America/Denver" },
    { "name" => "鳳凰城", "alt" => ["Phoenix"], "country" => "美國", "latitude" => 33.4484, "longitude" => -112.0740, "timezone" => "America/Phoenix" },
    { "name" => "拉斯維加斯", "alt" => ["Las Vegas"], "country" => "美國", "latitude" => 36.1699, "longitude" => -115.1398, "timezone" => "America/Los_Angeles" },
    { "name" => "檀香山", "alt" => ["Honolulu"], "country" => "美國", "latitude" => 21.3069, "longitude" => -157.8583, "timezone" => "Pacific/Honolulu" },
    { "name" => "安克拉治", "alt" => ["Anchorage"], "country" => "美國", "latitude" => 61.2181, "longitude" => -149.9003, "timezone" => "America/Anchorage" },
    { "name" => "多倫多", "alt" => ["Toronto"], "country" => "加拿大", "latitude" => 43.6532, "longitude" => -79.3832, "timezone" => "America/Toronto" },
    { "name" => "溫哥華", "alt" => ["Vancouver"], "country" => "加拿大", "latitude" => 49.2827, "longitude" => -123.1207, "timezone" => "America/Vancouver" },
    { "name" => "蒙特婁", "alt" => ["Montreal"], "country" => "加拿大", "latitude" => 45.5017, "longitude" => -73.5673, "timezone" => "America/Toronto" },
    { "name" => "卡加利", "alt" => ["Calgary"], "country" => "加拿大", "latitude" => 51.0447, "longitude" => -114.0719, "timezone" => "America/Edmonton" },
    { "name" => "墨西哥城", "alt" => ["Mexico City"], "country" => "墨西哥", "latitude" => 19.4326, "longitude" => -99.1332, "timezone" => "America/Mexico_City" },
    { "name" => "哈瓦那", "alt" => ["Havana"], "country" => "古巴", "latitude" => 23.1136, "longitude" => -82.3666, "timezone" => "America/Havana" },
    { "name" => "巴拿馬城", "alt" => ["Panama City"], "country" => "巴拿馬", "latitude" => 8.9824, "longitude" => -79.5199, "timezone" => "America/Panama" },
    { "name" => "瓜地馬拉市", "alt" => ["Guatemala City"], "country" => "瓜地馬拉", "latitude" => 14.6349, "longitude" => -90.5069, "timezone" => "America/Guatemala" },
    { "name" => "聖荷西", "alt" => ["San Jose"], "country" => "哥斯大黎加", "latitude" => 9.9281, "longitude" => -84.0907, "timezone" => "America/Costa_Rica" },

    # --- 南美洲 ---
    { "name" => "聖保羅", "alt" => ["Sao Paulo"], "country" => "巴西", "latitude" => -23.5505, "longitude" => -46.6333, "timezone" => "America/Sao_Paulo" },
    { "name" => "里約熱內盧", "alt" => ["Rio de Janeiro", "Rio"], "country" => "巴西", "latitude" => -22.9068, "longitude" => -43.1729, "timezone" => "America/Sao_Paulo" },
    { "name" => "布宜諾斯艾利斯", "alt" => ["Buenos Aires"], "country" => "阿根廷", "latitude" => -34.6037, "longitude" => -58.3816, "timezone" => "America/Argentina/Buenos_Aires" },
    { "name" => "聖地牙哥", "alt" => ["Santiago"], "country" => "智利", "latitude" => -33.4489, "longitude" => -70.6693, "timezone" => "America/Santiago" },
    { "name" => "利馬", "alt" => ["Lima"], "country" => "秘魯", "latitude" => -12.0464, "longitude" => -77.0428, "timezone" => "America/Lima" },
    { "name" => "波哥大", "alt" => ["Bogota"], "country" => "哥倫比亞", "latitude" => 4.7110, "longitude" => -74.0721, "timezone" => "America/Bogota" },
    { "name" => "基多", "alt" => ["Quito"], "country" => "厄瓜多", "latitude" => -0.1807, "longitude" => -78.4678, "timezone" => "America/Guayaquil" },
    { "name" => "加拉卡斯", "alt" => ["Caracas"], "country" => "委內瑞拉", "latitude" => 10.4806, "longitude" => -66.9036, "timezone" => "America/Caracas" },
    { "name" => "蒙特維多", "alt" => ["Montevideo"], "country" => "烏拉圭", "latitude" => -34.9011, "longitude" => -56.1645, "timezone" => "America/Montevideo" },
    { "name" => "拉巴斯", "alt" => ["La Paz"], "country" => "玻利維亞", "latitude" => -16.4897, "longitude" => -68.1193, "timezone" => "America/La_Paz" },

    # --- 非洲 ---
    { "name" => "開羅", "alt" => ["Cairo"], "country" => "埃及", "latitude" => 30.0444, "longitude" => 31.2357, "timezone" => "Africa/Cairo" },
    { "name" => "拉哥斯", "alt" => ["Lagos"], "country" => "奈及利亞", "latitude" => 6.5244, "longitude" => 3.3792, "timezone" => "Africa/Lagos" },
    { "name" => "奈洛比", "alt" => ["Nairobi"], "country" => "肯亞", "latitude" => -1.2921, "longitude" => 36.8219, "timezone" => "Africa/Nairobi" },
    { "name" => "約翰尼斯堡", "alt" => ["Johannesburg"], "country" => "南非", "latitude" => -26.2041, "longitude" => 28.0473, "timezone" => "Africa/Johannesburg" },
    { "name" => "開普敦", "alt" => ["Cape Town"], "country" => "南非", "latitude" => -33.9249, "longitude" => 18.4241, "timezone" => "Africa/Johannesburg" },
    { "name" => "卡薩布蘭卡", "alt" => ["Casablanca"], "country" => "摩洛哥", "latitude" => 33.5731, "longitude" => -7.5898, "timezone" => "Africa/Casablanca" },
    { "name" => "阿爾及爾", "alt" => ["Algiers"], "country" => "阿爾及利亞", "latitude" => 36.7538, "longitude" => 3.0588, "timezone" => "Africa/Algiers" },
    { "name" => "突尼斯", "alt" => ["Tunis"], "country" => "突尼西亞", "latitude" => 36.8065, "longitude" => 10.1815, "timezone" => "Africa/Tunis" },
    { "name" => "阿克拉", "alt" => ["Accra"], "country" => "迦納", "latitude" => 5.6037, "longitude" => -0.1870, "timezone" => "Africa/Accra" },
    { "name" => "阿迪斯阿貝巴", "alt" => ["Addis Ababa"], "country" => "衣索比亞", "latitude" => 9.0320, "longitude" => 38.7469, "timezone" => "Africa/Addis_Ababa" },
    { "name" => "三蘭港", "alt" => ["Dar es Salaam"], "country" => "坦尚尼亞", "latitude" => -6.7924, "longitude" => 39.2083, "timezone" => "Africa/Dar_es_Salaam" },
    { "name" => "金夏沙", "alt" => ["Kinshasa"], "country" => "剛果民主共和國", "latitude" => -4.4419, "longitude" => 15.2663, "timezone" => "Africa/Kinshasa" },

    # --- 大洋洲 ---
    { "name" => "雪梨", "alt" => ["Sydney"], "country" => "澳洲", "latitude" => -33.8688, "longitude" => 151.2093, "timezone" => "Australia/Sydney" },
    { "name" => "墨爾本", "alt" => ["Melbourne"], "country" => "澳洲", "latitude" => -37.8136, "longitude" => 144.9631, "timezone" => "Australia/Melbourne" },
    { "name" => "布里斯本", "alt" => ["Brisbane"], "country" => "澳洲", "latitude" => -27.4698, "longitude" => 153.0251, "timezone" => "Australia/Brisbane" },
    { "name" => "伯斯", "alt" => ["Perth"], "country" => "澳洲", "latitude" => -31.9505, "longitude" => 115.8605, "timezone" => "Australia/Perth" },
    { "name" => "阿得雷德", "alt" => ["Adelaide"], "country" => "澳洲", "latitude" => -34.9285, "longitude" => 138.6007, "timezone" => "Australia/Adelaide" },
    { "name" => "奧克蘭", "alt" => ["Auckland"], "country" => "紐西蘭", "latitude" => -36.8485, "longitude" => 174.7633, "timezone" => "Pacific/Auckland" },
    { "name" => "威靈頓", "alt" => ["Wellington"], "country" => "紐西蘭", "latitude" => -41.2865, "longitude" => 174.7762, "timezone" => "Pacific/Auckland" },
    { "name" => "蘇瓦", "alt" => ["Suva"], "country" => "斐濟", "latitude" => -18.1416, "longitude" => 178.4419, "timezone" => "Pacific/Fiji" },
  ].freeze

  RESULT_LIMIT = 10
  RESULT_KEYS = %w[name country latitude longitude timezone].freeze

  # Prefix matches first, then substring matches; case-insensitive on
  # name and alt aliases; at most RESULT_LIMIT results. The internal
  # "alt" key is stripped from results.
  def self.search(query)
    q = query.to_s.downcase
    return [] if q.empty?

    prefix_hits = []
    substring_hits = []

    CITIES.each do |city|
      names = [city["name"], *city["alt"]].map(&:downcase)
      if names.any? { |n| n.start_with?(q) }
        prefix_hits << city
      elsif names.any? { |n| n.include?(q) }
        substring_hits << city
      end
    end

    (prefix_hits + substring_hits).first(RESULT_LIMIT).map do |city|
      city.select { |key, _| RESULT_KEYS.include?(key) }
    end
  end
end
