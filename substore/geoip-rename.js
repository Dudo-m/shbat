/**
 * Sub-Store 节点 GeoIP 自动改名
 *
 * 格式:
 * 国家|城市|协议|编号|原名称
 *
 * 示例:
 * 日本|东京|tuic|01|Oracle-tuic
 * 美国|Los Angeles|vmess|01|server-us
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


// IPv4
const IPV4_RE =
    /^(?:\d{1,3}\.){3}\d{1,3}$/;



// DNS解析
async function resolveIP(host){

  if(!host)
    return "";


  // 已经是IP
  if(IPV4_RE.test(host))
    return host;



  const urls = [

    `https://223.5.5.5/resolve?name=${host}&type=A`,

    `https://dns.google/resolve?name=${host}&type=A`

  ];



  for(const url of urls){

    try{

      let res =
          await fetch(url);


      let json =
          await res.json();



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



// GeoIP查询
async function geoLookup(ipList){


  let result = {};


  if(ipList.length===0)
    return result;



  try{


    let res =
        await fetch(
            "https://ip-api.com/batch?lang=zh-CN&fields=status,countryCode,country,city",
            {
              method:"POST",
              headers:{
                "Content-Type":"application/json"
              },
              body:
                  JSON.stringify(
                      ipList.map(ip=>({
                        query:ip
                      }))
                  )
            }
        );


    let arr =
        await res.json();



    ipList.forEach(
        (ip,i)=>{


          let d =
              arr[i];


          if(
              d &&
              d.status==="success"
          ){

            result[ip]={
              cc:
                  d.countryCode || "",

              country:
                  d.country || "",

              city:
                  d.city || ""
            };

          }


        }
    );



  }catch(e){}



  return result;

}





async function operator(proxies){


  let ipMap = {};

  let ips = [];



  // 解析节点IP
  for(let node of proxies){


    let host =
        node.server;


    let ip =
        await resolveIP(host);



    if(ip){

      ipMap[node.name]=ip;


      if(!ips.includes(ip))
        ips.push(ip);

    }


  }




  // 查询GeoIP

  let geo =
      await geoLookup(ips);





  let count={};



  // 修改名称

  for(let node of proxies){



    let ip =
        ipMap[node.name];



    if(!ip)
      continue;



    let info =
        geo[ip];



    if(!info)
      continue;




    let country =
        countryCN[info.cc]
        ||
        info.country
        ||
        info.cc
        ||
        "未知";



    let city =
        info.city
        ||
        "未知";



    let proto =
        node.type
        ||
        "unknown";



    let original =
        node.name;



    let key =
        country+"|"+city;



    count[key] =
        (count[key]||0)+1;



    let num =
        String(count[key])
            .padStart(2,"0");



    node.name =
        `${country}|${city}|${proto}|${num}|${original}`;


  }



  return proxies;

}