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


// DNS解析：阿里 / DNSPod 优先，任一能解析出 IPv4 就用
async function resolveIP(host){

  // host 本身已是 IP，直接返回
  if(IPV4_RE.test(host))
    return host;

  const dohList = [
    `https://223.5.5.5/resolve?name=${host}&type=A`,   // 阿里 DNS
    `https://doh.pub/dns-query?name=${host}&type=A`,   // DNSPod
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

  return "";
}



async function operator(proxies){


  // 第一步：先解析所有节点的 IP
  for(let node of proxies){

    let host =
      node.server ||
      node.host ||
      node.address;

    if(!host)
      continue;

    node._ip = await resolveIP(host);
  }


  // 第二步：收集所有有效 IP（去重），一次批量查询
  let ipSet = new Set();

  for(let node of proxies){
    if(node._ip)
      ipSet.add(node._ip);
  }

  let ipList = [...ipSet];

  let geoMap = {};

  if(ipList.length > 0){

    try{

      // ip-api 批量接口：一次最多 100 个 IP
      let res = await fetch(
        "http://ip-api.com/batch?lang=zh-CN&fields=status,countryCode,country,city",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(ipList.map(ip => ({ query: ip })))
        }
      );

      let arr = await res.json();

      if(Array.isArray(arr)){

        ipList.forEach((ip, i) => {

          let d = arr[i] || {};

          geoMap[ip] = d.status === "success"
            ? {
                cc: d.countryCode || "",
                country: d.country || "",
                city: d.city || ""
              }
            : null;

        });

      }

    }catch(e){}

  }


  // 第三步：重命名
  let count = {};

  for(let node of proxies){

    let ip = node._ip;

    if(!ip)
      continue;

    let info = geoMap[ip];

    if(!info)
      continue;


    let cc = info.cc || "UN";

    let country =
      countryCN[cc] ||
      info.country ||
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


    // 用最终显示的国家 + 城市分组编号
    let key =
      country + city;


    count[key] =
      (count[key] || 0) + 1;


    let num =
      String(count[key])
      .padStart(2,"0");


    node.name =
      `${country}|${city}|${proto}|${num}|${original}`;

  }


  return proxies;

}
