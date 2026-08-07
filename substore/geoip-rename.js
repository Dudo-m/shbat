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


// DNS解析
async function resolveIP(host){

  try{

    let res = await fetch(
      `https://dns.google/resolve?name=${host}`
    );

    let json = await res.json();

    if(json.Answer){

      for(let a of json.Answer){

        if(
          a.data &&
          /^\d+\.\d+\.\d+\.\d+$/.test(a.data)
        ){
          return a.data;
        }

      }

    }

  }catch(e){}

  return host;
}



// Geo查询
async function geo(ip){

  try{

    let res = await fetch(
      `https://ipapi.co/${ip}/json/`
    );

    let data = await res.json();


    return {

      country:data.country_code || "UN",
      city:data.city || ""

    };


  }catch(e){

    return {
      country:"UN",
      city:""
    };

  }

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


      let info =
        await geo(ip);



      let cc =
        info.country;


      let country =
        countryCN[cc] || cc;


      // 原始名称：在覆盖 node.name 前先保存
      let original =
        node.name || "";


      // 协议：Sub-Store 节点对象的 type 字段，如 tuic / vmess / trojan
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
