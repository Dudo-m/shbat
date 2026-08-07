/**
 * Sub-Store GeoIP 自动改名 (稳定无错版)
 *
 * 格式: 国家 | 城市 | 原名称 (若无城市则自动为: 国家 | 原名称)
 */

const countryCN = {
  US: "美国", JP: "日本", SG: "新加坡", HK: "香港", TW: "台湾",
  KR: "韩国", GB: "英国", DE: "德国", FR: "法国", CA: "加拿大",
  AU: "澳大利亚", NL: "荷兰", RU: "俄罗斯", IN: "印度", BR: "巴西",
  TR: "土耳其"
};

function isIP(ip) {
  if (!ip) return false;
  const isV4 = /^(\d{1,3}\.){3}\d{1,3}$/.test(ip);
  const isV6 = /^([0-9a-fA-F]*:[0-9a-fA-F]*)+$/.test(ip) && ip.includes(':');
  return isV4 || isV6;
}

// 支持双 DNS 厂商解析 (Google / Cloudflare)
async function resolveIP(host) {
  if (!host) return "";
  if (isIP(host)) return host;

  const dnsProviders = [
    "https://dns.google/resolve",
    "https://cloudflare-dns.com/dns-query"
  ];

  for (let dns of dnsProviders) {
    try {
      for (let type of ["A", "AAAA"]) {
        let r = await fetch(`${dns}?name=${host}&type=${type}`, {
          headers: { "Accept": "application/dns-json" }
        });
        let j = await r.json();

        if (j.Answer) {
          for (let a of j.Answer) {
            if (a.data && isIP(a.data)) {
              return a.data;
            }
          }
        }
      }
    } catch (e) {}
  }

  return "";
}

// 移除容易报 403 的 ip.sb，换用高兼容性 GeoIP API
async function geo(ip) {
  let apis = [
    // 1. ipwho.is：支持 HTTPS / 中文，无 CF 防护拦截
    `https://ipwho.is/${ip}?lang=zh-CN`,
    // 2. freeipapi.com：API 专属，极速无拦截
    `https://freeipapi.com/api/json/${ip}`,
    // 3. ipapi.co：高精度兜底
    `https://ipapi.co/${ip}/json/`
  ];

  for (let api of apis) {
    try {
      let r = await fetch(api, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
        }
      });
      let d = await r.json();

      // 1. ipwho.is 响应格式
      if (d.success && d.country_code) {
        return {
          country: d.country_code,
          city: d.city || ""
        };
      }

      // 2. freeipapi.com 响应格式
      if (d.countryCode) {
        return {
          country: d.countryCode,
          city: d.cityName || ""
        };
      }

      // 3. ipapi.co 响应格式
      if (d.country_code) {
        return {
          country: d.country_code,
          city: d.city || ""
        };
      }
    } catch (e) {}
  }

  return null;
}

async function operator(proxies) {
  for (let node of proxies) {
    try {
      let host = node.server;
      if (!host) continue;

      let ip = await resolveIP(host);
      if (!ip) continue;

      let info = await geo(ip);
      if (!info) continue;

      let country = countryCN[info.country] || info.country;
      let city = info.city || "";
      let old = node.name || "";

      // 自动剔除空字段并用 " | " 分隔
      node.name = [country, city, old].filter(Boolean).join(" | ");

    } catch (e) {}
  }

  return proxies;
}