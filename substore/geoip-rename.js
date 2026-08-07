/**
 * Sub-Store 节点 GeoIP 自动改名
 *
 * 功能:
 * 国家|地区|协议|编号|原始名称
 *
 * 示例:
 * 日本|东京|tuic|01|Oracel-tuic-instance-20260719-2025
 * 美国|Los Angeles|vmess|01|server-us-01
 *
 */

const countryCN = {
  US:"美国",
  JP:"日本",
  SG:"新加坡",
  HK:"香港",
  TW:"台湾",
  KR:"韩国",
  GB:"英国",
  DE:"德国",
  FR:"法国",
  CA:"加拿大",
  AU:"澳大利亚",
  NL:"荷兰",
  RU:"俄罗斯",
  IN:"印度",
  BR:"巴西",
  TR:"土耳其"
};

const IPV4_RE = /^\d+\.\d+\.\d+\.\d+$/;


// DNS解析：多 DoH 兜底（兼容国内网络）
async function resolveIP(host){

  // host 本身已是 IP，直接返回，避免白走一遍 DoH
  if(IPV4_RE.test(host))
    return host;

  const dohList = [
    `https://223.5.5.5/resolve?name=${host}&type=A`,   // 阿里 DNS（实测可用）
    `https://doh.pub/dns-query?name=${host}&type=A`,   // DNSPod（实测可用）
    `https://dns.google/resolve?name=${host}`,         // 兜底
    `https://1.1.1.1/dns-query?name=${host}&type=A&ct=application/dns-json` // 兜底
  ];

  for(let url of dohList){

    try{

      let res = await fetch(url);

      let json = await res.json();

      if(json.Answer){

        for(let a of json.Answer){

          if(
            a.data &&
            IPV4_RE.test(a.data)
          ){
            return a.data;
          }

        }

      }

    }catch(e){}

  }

  return host;
}



// Geo查询：多源兜底，优先返回中文
async function geo(ip){

  // ip-api.com 免费版实测可用，15次/分钟限流，作为主源
  // 失败(限流/超时)时退到备用源
  const sources = [

    { // 主源：免费，支持 lang=zh-CN（注意：免费版仅 HTTP，勿改 https）
      url: `http://ip-api.com/json/${ip}?lang=zh-CN&fields=status,countryCode,country,city`,
      parse: (d)=>{
        if(d.status !== "success")
          throw new Error("fail");
        return {
          cc:d.countryCode || "",
          country:d.country || "",
          city:d.city || ""
        };
      }
    },

    { // 国内可用，直接返回中文
      url: `https://ip.useragentinfo.com/json?ip=${ip}`,
      parse: (d)=>({
        cc:"",
        country:d.country || "",
        city:d.city || ""
      })
    },

    { // 免费，英文
      url: `https://api.ip.sb/geoip/${ip}`,
      parse: (d)=>({
        cc:d.country_code || "",
        country:d.country || "",
        city:d.city || ""
      })
    },

    { // 最后兜底
      url: `https://ipapi.co/${ip}/json/`,
      parse: (d)=>({
        cc:d.country_code || "",
        country:d.country_name || "",
        city:d.city || ""
      })
    }

  ];

  // 主源失败时最多重试 2 次（限流返回后稍等再试）
  for(let attempt = 0; attempt < 3; attempt++){

    for(let s of sources){

      try{

        let d = await (await fetch(s.url)).json();

        let r = s.parse(d);

        // 只要拿到国家信息就算成功
        if(r.country || r.cc)
          return r;

      }catch(e){}

    }

    // 全部失败：等 3.5 秒再试一轮（规避 ip-api 每分钟 15 次限流）
    await new Promise(r=>setTimeout(r, 3500));

  }

  return {
    cc:"",
    country:"",
    city:""
  };

}



let count={};


async function operator(proxies){


  for(let node of proxies){


    try{


      let host =
        node.server ||
        node.host ||
        node.address;


      if(!host)
        continue;


      let ip =
        await resolveIP(host);


      // 解析不出 IP 就跳过，避免把域名传给 Geo 接口导致 UN
      if(!IPV4_RE.test(ip))
        continue;


      // 每节点随机延迟 3~6 秒，规避 ip-api 每分钟 15 次限流
      await new Promise(r=>setTimeout(r, 3000 + Math.floor(Math.random()*3000)));


      let info =
        await geo(ip);



      let cc =
        info.cc || (info.country ? "" : "UN");


      let country =
        info.country ||
        countryCN[cc] ||
        cc ||
        "UN";



      // 原始名称：在覆盖 node.name 前先保存
      let original =
        node.name || "";


      // 协议：Sub-Store 节点对象的 type 字段，如 vless / hysteria2 / tuic
      let proto =
        node.type || "";



      let city =
        info.city || "";



      // 用最终显示的国家 + 城市分组编号（统一用中文国家名，避免不同源 cc 不一致）
      let key =
        country + city;



      count[key] =
        (count[key] || 0)+1;



      let num =
        String(count[key])
        .padStart(2,"0");



      node.name =
        `${country}|${city}|${proto}|${num}|${original}`;


    }catch(e){

      continue;

    }


  }


  return proxies;

}
