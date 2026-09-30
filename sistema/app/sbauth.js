/* AGO — cadeado de login compartilhado (Supabase Auth, senha única por público)
   Uso: antes de qualquer script da página, defina opcionalmente:
     window.AGO_AUTH = { audience:'team'|'praca', title:'...', sub:'...' };
   e inclua <script src="sbauth.js"></script> como PRIMEIRO script.
   Ele: mostra um overlay pedindo a senha (o e-mail é fixo por público),
   loga no Supabase, guarda a sessão no localStorage e injeta o token nas
   chamadas REST (troca o Authorization). Chamadas REST feitas antes do login
   esperam o login terminar (authReady). */
(function(){
  var SB="https://pwbcehrfhspgipjhaedc.supabase.co";
  var KEY="sb_publishable_mTx5xlUaUcLBM_YijXuCjg_vwCJ5v3x";
  var cfg=window.AGO_AUTH||{audience:"team"};
  var EMAILS={team:"equipe@ageodonto.com.br",praca:"praca@ageodonto.com.br"};
  var email=cfg.email||EMAILS[cfg.audience]||EMAILS.team;
  var LSK="ago_sess_"+(cfg.audience||"team");
  var sess=null; try{sess=JSON.parse(localStorage.getItem(LSK)||"null");}catch(e){}
  var resolveReady, authReady=new Promise(function(r){resolveReady=r;});
  var _fetch=window.fetch.bind(window);

  function valid(s){return s&&s.access_token&&s.expires_at&&(s.expires_at*1000)>(Date.now()+5000);}
  function store(s){s.expires_at=Math.floor(Date.now()/1000)+((s.expires_in||3600));sess=s;try{localStorage.setItem(LSK,JSON.stringify(s));}catch(e){}}
  function clear(){try{localStorage.removeItem(LSK);}catch(e){}sess=null;}
  window.agoLogout=function(){clear();location.reload();};

  function refresh(){
    if(!sess||!sess.refresh_token)return Promise.resolve(false);
    return _fetch(SB+"/auth/v1/token?grant_type=refresh_token",{method:"POST",headers:{apikey:KEY,"Content-Type":"application/json"},body:JSON.stringify({refresh_token:sess.refresh_token})})
      .then(function(r){return r.ok?r.json():null;})
      .then(function(j){if(j&&j.access_token){store(j);return true;}clear();return false;})
      .catch(function(){return false;});
  }

  // injeta o token nas chamadas REST do Supabase
  window.fetch=function(input,init){
    var url=(typeof input==="string")?input:((input&&input.url)||"");
    if(url.indexOf(SB+"/rest")===0){
      return authReady.then(function(){
        init=init||{}; var h=Object.assign({},init.headers||{}); h.apikey=KEY; h.Authorization="Bearer "+sess.access_token; init.headers=h;
        return _fetch(input,init).then(function(r){
          if(r.status===401){return refresh().then(function(ok){if(!ok)return r;var h2=Object.assign({},init.headers||{});h2.Authorization="Bearer "+sess.access_token;init.headers=h2;return _fetch(input,init);});}
          return r;
        });
      });
    }
    return _fetch(input,init);
  };

  function login(pw){
    return _fetch(SB+"/auth/v1/token?grant_type=password",{method:"POST",headers:{apikey:KEY,"Content-Type":"application/json"},body:JSON.stringify({email:email,password:pw})})
      .then(function(r){return r.json().then(function(j){return {ok:r.ok,j:j};});});
  }

  function overlay(){
    var title=cfg.title||(cfg.audience==="praca"?"Torre da sua praça":"Gestão Comercial AGO");
    var sub=cfg.sub||(cfg.audience==="praca"?"Digite a Senha AGO que a Direção Comercial te enviou.":"Acesso restrito aos sócios. Digite a Senha Sócio.");
    var pwl=cfg.audience==="praca"?"Senha AGO":"Senha Sócio";
    var css="position:fixed;inset:0;z-index:99999;display:flex;align-items:center;justify-content:center;background:radial-gradient(120% 80% at 85% -10%,rgba(233,194,90,.10),transparent 60%),#0B0906;font-family:'Inter',-apple-system,BlinkMacSystemFont,sans-serif;padding:20px";
    var d=document.createElement("div"); d.id="ago-login"; d.setAttribute("style",css);
    d.innerHTML=''+
      '<div style="width:100%;max-width:380px;background:linear-gradient(180deg,#141009,#0B0906);border:1px solid #2A2213;border-radius:16px;padding:30px 26px;box-shadow:0 20px 60px rgba(0,0,0,.5)">'+
        '<div style="font-size:10px;font-weight:800;letter-spacing:.2em;text-transform:uppercase;color:#B8862B">Ageodonto</div>'+
        '<div style="font-family:Spectral,Georgia,serif;font-size:24px;font-weight:800;color:#F3ECDA;margin:6px 0 6px">'+title+'</div>'+
        '<div style="font-size:13px;color:#B6A883;margin-bottom:18px;line-height:1.5">'+sub+'</div>'+
        '<label style="display:block;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:#7C7256;margin-bottom:6px">'+pwl+'</label>'+
        '<input id="ago-pw" type="password" autocomplete="current-password" style="width:100%;background:#1A150C;color:#F3ECDA;border:1px solid #2A2213;border-radius:9px;padding:11px 12px;font-size:15px;font-family:inherit">'+
        '<button id="ago-go" style="width:100%;margin-top:14px;background:linear-gradient(100deg,#FBEDB4,#F1CE68 40%,#CFA23B 70%,#F7DE8C);color:#241a06;border:none;border-radius:10px;padding:12px;font-size:15px;font-weight:800;cursor:pointer;font-family:inherit">Entrar</button>'+
        '<div id="ago-err" style="font-size:12.5px;color:#E0796B;margin-top:10px;min-height:16px"></div>'+
      '</div>';
    document.body.appendChild(d);
    var pw=d.querySelector("#ago-pw"),go=d.querySelector("#ago-go"),err=d.querySelector("#ago-err");
    function attempt(){
      var v=pw.value; if(!v){err.textContent="Digite a senha.";return;}
      go.disabled=true; go.textContent="Entrando…"; err.textContent="";
      login(v).then(function(res){
        if(res.ok&&res.j&&res.j.access_token){store(res.j);d.remove();resolveReady();}
        else{err.textContent=(res.j&&(res.j.error_description||res.j.msg||res.j.error))||("Erro "+((res.j&&res.j.code)||"?"));go.disabled=false;go.textContent="Entrar";pw.select();}
      }).catch(function(){err.textContent="Erro de conexão. Tente de novo.";go.disabled=false;go.textContent="Entrar";});
    }
    go.onclick=attempt; pw.addEventListener("keydown",function(e){if(e.key==="Enter")attempt();});
    setTimeout(function(){pw.focus();},60);
  }

  function boot(){
    if(valid(sess)){resolveReady();return;}
    if(sess&&sess.refresh_token){refresh().then(function(ok){ok?resolveReady():overlay();});return;}
    overlay();
  }
  if(document.body)boot(); else document.addEventListener("DOMContentLoaded",boot);
})();
