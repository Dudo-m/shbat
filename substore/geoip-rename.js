/**
 * Sub-Store GeoIP 自动改名
 *
 * 格式:
 * 国家|城市|协议|编号|原名称
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



function isIP(ip){

  return /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/.test(ip);

}




// DNS只负责解析IP
async function resolveIP(host){


  if(!host)
    return "";


  if(isIP(host))
    return host;



  try{


    let r =
        await fetch(
            "https://dns.google/resolve?name="
            +host
            +"&type=A"
        );


    let j =
        await r.json();



    if(j.Answer){


      for(let a of j.Answer){


        if(
            a.data &&
            isIP(a.data)
        )
          return a.data;


      }


    }



  }catch(e){}



  return "";

}




// 多GeoIP查询
async function geo(ip){



  let apis=[


    "https://ipwho.is/"+ip,


    "https://ipapi.co/"+ip+"/json/",


    "https://freeipapi.com/api/json/"+ip


  ];



  for(let api of apis){


    try{


      let r =
          await fetch(api);


      let d =
          await r.json();



// ipwho

      if(d.success && d.country_code){

        return {

          country:d.country_code,

          city:d.city || ""

        };

      }



// ipapi

      if(d.country_code){

        return {

          country:d.country_code,

          city:d.city || ""

        };

      }



// freeipapi

      if(d.countryCode){

        return {

          country:d.countryCode,

          city:d.cityName || ""

        };

      }



    }catch(e){}



  }



  return null;

}





async function operator(proxies){



  let count={};



  for(let node of proxies){



    try{


      let host =
          node.server;



      if(!host)
        continue;



      let ip =
          await resolveIP(host);



      if(!ip)
        continue;



      let info =
          await geo(ip);



      if(!info)
        continue;




      let country =
          countryCN[info.country]
          ||
          info.country;



      let city =
          info.city
          ||
          "";



      let proto =
          node.type
          ||
          "";



      let old =
          node.name
          ||
          "";



      let key =
          country+"|"+city;



      count[key]=
          (count[key]||0)+1;



      let num =
          String(count[key])
              .padStart(2,"0");



      node.name =
          country
          +"|"
          +city
          +"|"
          +proto
          +"|"
          +num
          +"|"
          +old;



    }catch(e){}



  }



  return proxies;

}