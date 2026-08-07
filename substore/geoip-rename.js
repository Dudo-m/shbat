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
    `https://dns.google/resolve?name=${host}`,
    `https://223.5.5.5/resolve?name=${host}&type=A`,   // 阿里 DNS
    `https://doh.pub/dns-query?name=${host}&type=A`,   // DNSPod
    `https://1.1.1.1/dns-query?name=${host}&type=A&ct=application/dns-json` // Cloudflare
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

  const sources = [

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

  for(let s of sources){

    try{

      let d = await (await fetch(s.url)).json();

      let r = s.parse(d);

      // 只要拿到国家信息就算成功
      if(r.country || r.cc)
        return r;

    }catch(e){}

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



      let key =
        cc + city;



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
