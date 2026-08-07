/**
 * Sub-Store GeoIP 自动改名 (精简清爽版)
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

async function resolveIP(host) {
  if (!host) return "";
  if (isIP(host)) return host;

  try {
    const types = ["A", "AAAA"];
    for (let type of types) {
      let r = await fetch(`https://dns.google/resolve?name=${host}&type=${type}`);
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

  return "";
}

async function geo(ip) {
  let apis = [
    `http://ip-api.com/json/${ip}?lang=zh-CN`,
    `https://api.ip.sb/geoip/${ip}`,
    `https://ipwho.is/${ip}`,
    `https://ipapi.co/${ip}/json/`
  ];

  for (let api of apis) {
    try {
      let r = await fetch(api);
      let d = await r.json();

      if (d.status === "success" && d.countryCode) {
        return {
          country: d.countryCode,
          city: d.city || ""
        };
      }

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

      // 优雅拼接：自动剔除空字段并用 " | " 分隔
      node.name = [country, city, old].filter(Boolean).join(" | ");

    } catch (e) {}
  }

  return proxies;
}