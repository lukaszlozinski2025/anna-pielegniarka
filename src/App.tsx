import { useState, useRef, useEffect } from "react";
import StreamingAvatar, { AvatarQuality, StreamingEvents, TaskType } from "@heygen/streaming-avatar";

const ELEVEN_KEY = "sk_60b64add4fda15189176b7b96de00030bb9c448b083b2680";
const ELEVEN_VOICE_ID = "21m00Tcm4TlvDq8ikWAM";
const LIVEAVATAR_KEY = "caecb27a-2628-11f1-8d28-066a7fa2e369";
const AVATAR_ID = "fc9c1f9f-bc99-4fd9-a6b2-8b4b5669a046";

const G = {
  bg:"#0d1117",panel:"#111820",card:"#161e28",border:"#1e2d3d",
  teal:"#00c2a8",tealDim:"#00c2a818",tealMid:"#00c2a840",
  rose:"#e05a6a",amber:"#f0a340",
  text:"#e8edf3",textMid:"#7a8fa8",textDim:"#3a4f63",green:"#2ecc8a",
};

const STEPS:any[]=[
  {id:"welcome",phase:"Powitanie",nurseText:"Dzień dobry! Jestem Anna, Pana wirtualna pielęgniarka pierwszego kontaktu. Zanim trafi Pan do lekarza, przeprowadzę krótki wywiad medyczny. Wszystko jest poufne. Gotowy?",type:"confirm",field:null},
  {id:"imie",phase:"Dane osobowe",nurseText:"Jak mam się do Pana zwracać? Proszę podać imię i nazwisko.",type:"text",field:"imieNazwisko",placeholder:"np. Jan Kowalski",validate:(v:string)=>v.trim().split(" ").length>=2||"Proszę podać imię i nazwisko"},
  {id:"pesel",phase:"Dane osobowe",nurseText:"Dziękuję. Proszę podać numer PESEL.",type:"text",field:"pesel",placeholder:"11 cyfr",mask:true,validate:(v:string)=>/^\d{11}$/.test(v.replace(/\s/g,""))||"PESEL musi mieć 11 cyfr"},
  {id:"dataUrodzenia",phase:"Dane osobowe",nurseText:"Proszę potwierdzić datę urodzenia.",type:"date",field:"dataUrodzenia"},
  {id:"telefon",phase:"Dane osobowe",nurseText:"Na jaki numer telefonu mamy się kontaktować?",type:"text",field:"telefon",placeholder:"np. 600 123 456",validate:(v:string)=>/^[\d\s+\-]{9,}$/.test(v)||"Podaj poprawny numer"},
  {id:"dolegliwosci",phase:"Dolegliwości",nurseText:"Co Pana do nas sprowadza? Proszę opisać główną dolegliwość.",type:"textarea",field:"dolegliwoscGlowna",placeholder:"Opisz objawy..."},
  {id:"lokalizacja",phase:"Dolegliwości",nurseText:"Gdzie dokładnie odczuwa Pan te dolegliwości?",type:"text",field:"lokalizacja",placeholder:"np. klatka piersiowa, głowa..."},
  {id:"charakter",phase:"Dolegliwości",nurseText:"Jak opisałby Pan charakter tego bólu?",type:"chips",field:"charakter",options:["Tępy","Ostry","Piekący","Pulsujący","Uciskający","Kłujący","Promieniujący","Inny"]},
  {id:"natezenie",phase:"Dolegliwości",nurseText:"W skali od 1 do 10, jak silne są dolegliwości?",type:"scale",field:"natezenie"},
  {id:"czas",phase:"Dolegliwości",nurseText:"Od kiedy trwają te objawy?",type:"chips",field:"czasTrwania",options:["Kilka godzin","1–2 dni","Kilka dni","Ponad tydzień","Ponad miesiąc","Przewlekle"]},
  {id:"czynniki",phase:"Dolegliwości",nurseText:"Czy coś nasila lub łagodzi dolegliwości?",type:"textarea",field:"czynniki",placeholder:"np. nasila się przy ruchu..."},
  {id:"choroby",phase:"Historia medyczna",nurseText:"Czy ma Pan stwierdzone choroby przewlekłe?",type:"chips",field:"chorobyPrzewlekle",multi:true,options:["Nadciśnienie","Cukrzyca t.1","Cukrzyca t.2","Choroba wieńcowa","Astma / POChP","Niedoczynność tarczycy","Niewydolność nerek","Depresja / lęki","Żadna z powyższych"]},
  {id:"operacje",phase:"Historia medyczna",nurseText:"Czy był Pan kiedyś operowany?",type:"textarea",field:"operacje",placeholder:"np. wyrostek 2015..."},
  {id:"leki",phase:"Leki i alergie",nurseText:"Proszę wymienić leki przyjmowane regularnie.",type:"textarea",field:"leki",placeholder:"np. Metformina 500mg..."},
  {id:"alergie",phase:"Leki i alergie",nurseText:"Czy ma Pan znane alergie?",type:"chips",field:"alergie",multi:true,options:["Penicylina","Aspiryna / NLPZ","Jod / kontrast","Lateks","Pokarmy","Brak alergii","Inne"]},
  {id:"triage",phase:"Triage",nurseText:"Ostatnie pytanie. Jak czuje się Pan w tej chwili?",type:"triage",field:"stanAktualny"},
];

const PHASES=[...new Set(STEPS.map((s:any)=>s.phase))];
const PHASE_ICONS:any={"Powitanie":"👋","Dane osobowe":"📋","Dolegliwości":"🩺","Historia medyczna":"📁","Leki i alergie":"💊","Triage":"🚦"};
const SPECIALIST_MAP:any={"Nadciśnienie":"Kardiolog","Cukrzyca t.1":"Diabetolog","Cukrzyca t.2":"Diabetolog","Choroba wieńcowa":"Kardiolog","Astma / POChP":"Pulmonolog","Niedoczynność tarczycy":"Endokrynolog","Niewydolność nerek":"Nefrolog","Depresja / lęki":"Psychiatra"};
const TRIAGE=[{label:"Dobrze",icon:"😊",color:"#2ecc8a",priority:3},{label:"Średnio",icon:"😐",color:"#f0a340",priority:2},{label:"Źle",icon:"😟",color:"#e05a6a",priority:1},{label:"Bardzo źle",icon:"😰",color:"#cc2244",priority:0}];

function MicButton({onResult,disabled}:{onResult:(t:string)=>void,disabled:boolean}){
  const [listening,setListening]=useState(false);
  const recRef=useRef<any>(null);
  function toggle(){
    const SR=(window as any).SpeechRecognition||(window as any).webkitSpeechRecognition;
    if(!SR){alert("Użyj Chrome.");return;}
    if(listening){recRef.current?.stop();setListening(false);return;}
    const rec=new SR();rec.lang="pl-PL";rec.continuous=false;rec.interimResults=false;
    rec.onresult=(e:any)=>{onResult(e.results[0][0].transcript);setListening(false);};
    rec.onerror=()=>setListening(false);rec.onend=()=>setListening(false);
    rec.start();recRef.current=rec;setListening(true);
  }
  return(
    <button onClick={toggle} disabled={disabled} title={listening?"Zatrzymaj":"Mów"}
      style={{width:48,height:48,borderRadius:14,border:`1.5px solid ${listening?"#e05a6a":"#00c2a840"}`,
        background:listening?"#e05a6a18":"#00c2a818",cursor:disabled?"not-allowed":"pointer",
        display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0,
        animation:listening?"micPulse 1s ease infinite alternate":"none"}}>
      {listening
        ?<svg width="18" height="18" viewBox="0 0 24 24" fill="#e05a6a"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>
        :<svg width="18" height="18" viewBox="0 0 24 24"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" fill="#00c2a8"/><path d="M19 10v2a7 7 0 0 1-14 0v-2" stroke="#00c2a8" strokeWidth="2" fill="none" strokeLinecap="round"/><line x1="12" y1="19" x2="12" y2="23" stroke="#00c2a8" strokeWidth="2" strokeLinecap="round"/><line x1="8" y1="23" x2="16" y2="23" stroke="#00c2a8" strokeWidth="2" strokeLinecap="round"/></svg>}
    </button>
  );
}

export default function App(){
  const [step,setStep]=useState(0);
  const [answers,setAnswers]=useState<any>({});
  const [current,setCurrent]=useState("");
  const [error,setError]=useState("");
  const [appPhase,setAppPhase]=useState("interview");
  const [chatLog,setChatLog]=useState<any[]>([]);
  const [avatarStatus,setAvatarStatus]=useState<"idle"|"loading"|"ready"|"error">("idle");
  const [avatarError,setAvatarError]=useState("");
  const videoRef=useRef<HTMLVideoElement>(null);
  const avatarRef=useRef<StreamingAvatar|null>(null);
  const bottomRef=useRef<HTMLDivElement>(null);
  const s=STEPS[step];
  const progress=(step/(STEPS.length-1))*100;
  const currentPhaseIdx=PHASES.indexOf(s?.phase);

  useEffect(()=>{bottomRef.current?.scrollIntoView({behavior:"smooth"})},[chatLog]);

  // Init LiveAvatar on mount
  useEffect(()=>{
    initAvatar();
    return()=>{avatarRef.current?.stopAvatar();};
  },[]);

  useEffect(()=>{
    const st=STEPS[step];if(!st||appPhase!=="interview") return;
    setChatLog((p:any)=>[...p,{role:"nurse",text:st.nurseText}]);
    speakAvatar(st.nurseText);
  },[step,appPhase]);

  async function initAvatar(){
    setAvatarStatus("loading");
    try{
      // Get session token
      const tokenRes=await fetch("https://api.heygen.com/v1/streaming.create_token",{
        method:"POST",
        headers:{"Content-Type":"application/json","x-api-key":LIVEAVATAR_KEY},
      });
      const tokenData=await tokenRes.json();
      const token=tokenData.data?.token;
      if(!token) throw new Error("Brak tokenu");

      const avatar=new StreamingAvatar({token});
      avatarRef.current=avatar;

      avatar.on(StreamingEvents.STREAM_READY,(e:any)=>{
        if(videoRef.current&&e.detail){
          videoRef.current.srcObject=e.detail;
          videoRef.current.play();
        }
        setAvatarStatus("ready");
      });
      avatar.on(StreamingEvents.STREAM_DISCONNECTED,()=>setAvatarStatus("idle"));

      await avatar.createStartAvatar({
        quality:AvatarQuality.High,
        avatarName:AVATAR_ID,
        disableIdleTimeout:false,
      });
    }catch(e:any){
      setAvatarStatus("error");
      setAvatarError(e.message);
    }
  }

  async function speakAvatar(text:string){
    if(avatarRef.current&&avatarStatus==="ready"){
      try{
        await avatarRef.current.speak({text,taskType:TaskType.REPEAT});
        return;
      }catch{}
    }
    // Fallback: ElevenLabs
    speakElevenLabs(text);
  }

  async function speakElevenLabs(text:string){
    try{
      const res=await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${ELEVEN_VOICE_ID}`,{
        method:"POST",headers:{"Content-Type":"application/json","xi-api-key":ELEVEN_KEY},
        body:JSON.stringify({text,model_id:"eleven_multilingual_v2",voice_settings:{stability:0.55,similarity_boost:0.82}}),
      });
      if(!res.ok) return;
      const blob=await res.blob();const url=URL.createObjectURL(blob);
      const audio=new Audio(url);
      audio.onended=()=>URL.revokeObjectURL(url);
      audio.play();
    }catch{}
  }

  function addUserMsg(text:string){setChatLog((p:any)=>[...p,{role:"user",text}]);}
  function advance(field:string|null,val?:any){
    if(field) setAnswers((p:any)=>({...p,[field]:val!==undefined?val:current}));
    setCurrent("");setError("");
    if(step+1>=STEPS.length) setAppPhase("summary"); else setStep(p=>p+1);
  }
  function tryNext(){
    if(s.validate){const r=s.validate(current);if(r!==true){setError(r);return;}}
    addUserMsg(current);advance(s.field,current);
  }
  function handleVoice(text:string){
    setCurrent(text);
    if(s?.type==="text"){
      if(s.validate){const r=s.validate(text);if(r!==true){setError(r);return;}}
      setTimeout(()=>{addUserMsg(text);advance(s.field,text);},600);
    } else if(s?.type==="textarea"){
      setTimeout(()=>{addUserMsg(text);advance(s.field,text);},600);
    }
  }
  function handleChip(opt:string,multi:boolean){
    if(multi){const arr=Array.isArray(answers[s.field])?answers[s.field]:[];setAnswers((p:any)=>({...p,[s.field]:arr.includes(opt)?arr.filter((x:string)=>x!==opt):[...arr,opt]}));}
    else{addUserMsg(opt);advance(s.field,opt);}
  }
  function getRouting(){
    const priority=answers.stanAktualny;const chronic=answers.chorobyPrzewlekle||[];
    const specs=[...new Set(chronic.flatMap((c:string)=>SPECIALIST_MAP[c]?[SPECIALIST_MAP[c]]:[]))];
    const sev=parseInt(answers.natezenie)||5;
    if(priority===0||sev>=9) return{color:"#cc2244",label:"PILNY — SOR",wait:"Natychmiast",specs:["SOR"]};
    if(priority===1||sev>=7) return{color:"#e05a6a",label:"PILNY — Lekarz dyżurny",wait:"Do 30 minut",specs:specs.length?specs:["Lekarz pierwszego kontaktu"]};
    if(priority===2||sev>=4) return{color:"#f0a340",label:"NORMALNY — Umów wizytę",wait:"Do 48h",specs:specs.length?specs:["Lekarz pierwszego kontaktu"]};
    return{color:"#2ecc8a",label:"PLANOWY — Wizyta kontrolna",wait:"Do 2 tygodni",specs:specs.length?specs:["Lekarz pierwszego kontaktu"]};
  }

  if(appPhase==="summary"){
    const r=getRouting();
    return(
      <div style={{minHeight:"100vh",background:"#0d1117",fontFamily:"system-ui",padding:24,display:"flex",justifyContent:"center"}}>
        <div style={{width:"100%",maxWidth:680,paddingBottom:60}}>
          <div style={{textAlign:"center",padding:"36px 0 24px"}}><div style={{fontSize:52}}>✅</div>
            <div style={{fontSize:28,fontWeight:800,color:"#e8edf3"}}>Wywiad zakończony</div>
            <div style={{color:"#7a8fa8",marginTop:8}}>Dziękuję, <b style={{color:"#e8edf3"}}>{answers.imieNazwisko}</b>.</div>
          </div>
          <div style={{background:r.color+"22",border:`2px solid ${r.color}`,borderRadius:16,padding:"20px 24px",marginBottom:14,display:"flex",alignItems:"center",gap:16}}>
            <div style={{fontSize:40}}>🚦</div>
            <div><div style={{fontSize:11,letterSpacing:3,color:r.color,fontWeight:800,textTransform:"uppercase"}}>Priorytet triażu</div>
              <div style={{fontSize:20,fontWeight:800,color:"#e8edf3",marginTop:4}}>{r.label}</div>
              <div style={{color:"#7a8fa8",fontSize:13}}>Czas: <b style={{color:r.color}}>{r.wait}</b></div>
            </div>
          </div>
          {[["📋 Dane",[["Imię",answers.imieNazwisko],["PESEL",answers.pesel?.replace(/\d(?=\d{4})/g,"•")],["Data ur.",answers.dataUrodzenia],["Tel.",answers.telefon]]],
            ["🩺 Dolegliwości",[["Główna",answers.dolegliwoscGlowna],["Lokalizacja",answers.lokalizacja],["Charakter",answers.charakter],["Nasilenie",answers.natezenie?`${answers.natezenie}/10`:null],["Czas",answers.czasTrwania]]],
            ["📁 Historia",[["Choroby",[].concat(answers.chorobyPrzewlekle||[]).join(", ")],["Operacje",answers.operacje]]],
            ["💊 Leki",[["Leki",answers.leki],["Alergie",[].concat(answers.alergie||[]).join(", ")]]]
          ].map(([title,rows]:any)=>(
            <div key={title} style={{background:"#111820",border:"1px solid #1e2d3d",borderRadius:14,padding:"14px 18px",marginBottom:10}}>
              <div style={{fontSize:13,fontWeight:700,color:"#7a8fa8",marginBottom:8}}>{title}</div>
              {rows.map(([l,v]:any)=>(
                <div key={l} style={{display:"flex",gap:12,fontSize:13,marginBottom:4}}>
                  <span style={{color:"#3a4f63",minWidth:120,flexShrink:0}}>{l}</span>
                  <span style={{color:"#e8edf3",fontWeight:600}}>{v||<span style={{color:"#3a4f63",fontStyle:"italic"}}>—</span>}</span>
                </div>
              ))}
            </div>
          ))}
          <button onClick={()=>{setStep(0);setAnswers({});setCurrent("");setChatLog([]);setAppPhase("interview");initAvatar();}}
            style={{width:"100%",marginTop:8,background:"transparent",border:"1px solid #1e2d3d",color:"#7a8fa8",borderRadius:14,padding:14,fontSize:14,cursor:"pointer"}}>
            🔄 Nowy wywiad
          </button>
        </div>
      </div>
    );
  }

  return(
    <div style={{minHeight:"100vh",background:"#0d1117",fontFamily:"system-ui",display:"flex",flexDirection:"column"}}>
      <style>{`
        @keyframes micPulse{from{box-shadow:0 0 0 0 #e05a6a40}to{box-shadow:0 0 0 10px #e05a6a00}}
        @keyframes spin{to{transform:rotate(360deg)}}
        *{box-sizing:border-box}::-webkit-scrollbar{width:4px}::-webkit-scrollbar-thumb{background:#1e2d3d;border-radius:2px}
        input,textarea{color-scheme:dark}input[type=date]::-webkit-calendar-picker-indicator{filter:invert(.5)}
        button:hover{opacity:.85!important}button{transition:opacity .15s}
      `}</style>

      <div style={{background:"#111820",borderBottom:"1px solid #1e2d3d",padding:"0 20px",height:52,display:"flex",alignItems:"center",gap:12,position:"sticky",top:0,zIndex:10}}>
        <span style={{fontSize:14,fontWeight:800,color:"#00c2a8"}}>👩‍⚕️ ANNA</span>
        <span style={{fontSize:11,color:"#7a8fa8"}}>Pielęgniarka Pierwszego Kontaktu</span>
        <div style={{flex:1}}/>
        <span style={{fontSize:11,color: avatarStatus==="ready"?"#2ecc8a":avatarStatus==="loading"?"#f0a340":"#3a4f63"}}>
          {avatarStatus==="ready"?"🟢 Avatar aktywny":avatarStatus==="loading"?"⏳ Łączę...":avatarStatus==="error"?"🔴 Błąd avatara":"⚪ Offline"}
        </span>
        <span style={{fontSize:11,color:"#3a4f63"}}>Krok {step+1}/{STEPS.length}</span>
      </div>
      <div style={{height:3,background:"#1e2d3d"}}><div style={{height:"100%",width:`${progress}%`,background:"#00c2a8",transition:"width .4s ease"}}/></div>

      <div style={{flex:1,display:"flex",gap:20,padding:20,maxWidth:1100,margin:"0 auto",width:"100%"}}>

        {/* AVATAR VIDEO */}
        <div style={{width:280,flexShrink:0,display:"flex",flexDirection:"column",gap:14}}>
          <div style={{borderRadius:18,overflow:"hidden",height:340,border:"1px solid #1e2d3d",background:"#111820",position:"relative",display:"flex",alignItems:"center",justifyContent:"center"}}>
            <video ref={videoRef} autoPlay playsInline
              style={{width:"100%",height:"100%",objectFit:"cover",display:avatarStatus==="ready"?"block":"none",borderRadius:18}}/>
            {avatarStatus!=="ready"&&(
              <div style={{display:"flex",flexDirection:"column",alignItems:"center",gap:12,color:"#7a8fa8"}}>
                {avatarStatus==="loading"&&<div style={{width:40,height:40,border:"3px solid #00c2a840",borderTop:"3px solid #00c2a8",borderRadius:"50%",animation:"spin 1s linear infinite"}}/>}
                {avatarStatus==="error"&&<div style={{fontSize:32}}>⚠️</div>}
                <div style={{fontSize:13,textAlign:"center",padding:"0 16px"}}>
                  {avatarStatus==="loading"?"Łączę z avatarem Ann...":avatarStatus==="error"?avatarError:"Inicjalizacja..."}
                </div>
                {avatarStatus==="error"&&<button onClick={initAvatar} style={{background:"#00c2a818",border:"1px solid #00c2a840",color:"#00c2a8",borderRadius:10,padding:"8px 16px",fontSize:12,cursor:"pointer"}}>Spróbuj ponownie</button>}
              </div>
            )}
          </div>

          <div style={{background:"#111820",border:"1px solid #1e2d3d",borderRadius:16,padding:16}}>
            {PHASES.map((p:any,i:number)=>(
              <div key={p} style={{display:"flex",alignItems:"center",gap:10,padding:"6px 0",borderBottom:i<PHASES.length-1?"1px solid #1e2d3d":"none"}}>
                <div style={{width:24,height:24,borderRadius:"50%",flexShrink:0,display:"flex",alignItems:"center",justifyContent:"center",fontSize:11,fontWeight:700,
                  background:i<currentPhaseIdx?"#00c2a8":i===currentPhaseIdx?"#00c2a840":"#1e2d3d",
                  border:i===currentPhaseIdx?"2px solid #00c2a8":"none",
                  color:i<currentPhaseIdx?"#000":i===currentPhaseIdx?"#00c2a8":"#3a4f63"}}>
                  {i<currentPhaseIdx?"✓":PHASE_ICONS[p]}
                </div>
                <span style={{fontSize:12,color:i<=currentPhaseIdx?"#e8edf3":"#3a4f63",fontWeight:i===currentPhaseIdx?700:400}}>{p}</span>
              </div>
            ))}
          </div>
          <button onClick={()=>speakAvatar(s?.nurseText)} style={{background:"#00c2a818",border:"1px solid #00c2a840",color:"#00c2a8",borderRadius:12,padding:"9px 16px",fontSize:13,fontWeight:600,cursor:"pointer"}}>
            🔊 Powtórz pytanie
          </button>
        </div>

        {/* CHAT */}
        <div style={{flex:1,display:"flex",flexDirection:"column",gap:14,minWidth:0}}>
          <div style={{flex:1,background:"#111820",border:"1px solid #1e2d3d",borderRadius:18,padding:18,overflowY:"auto",maxHeight:400,display:"flex",flexDirection:"column",gap:12}}>
            {chatLog.map((m:any,i:number)=>(
              <div key={i} style={{display:"flex",gap:10,flexDirection:m.role==="user"?"row-reverse":"row",alignItems:"flex-start"}}>
                <div style={{width:30,height:30,borderRadius:"50%",background:m.role==="nurse"?"#00c2a818":"#ffffff10",display:"flex",alignItems:"center",justifyContent:"center",fontSize:15,flexShrink:0}}>{m.role==="nurse"?"👩‍⚕️":"🧑"}</div>
                <div style={{maxWidth:"78%",background:m.role==="nurse"?"#00c2a818":"#ffffff08",border:`1px solid ${m.role==="nurse"?"#00c2a840":"#1e2d3d"}`,borderRadius:14,padding:"10px 14px",fontSize:14,color:"#e8edf3",lineHeight:1.6,
                  borderBottomLeftRadius:m.role==="nurse"?4:14,borderBottomRightRadius:m.role==="user"?4:14}}>
                  {m.text}
                </div>
              </div>
            ))}
            <div ref={bottomRef}/>
          </div>

          <div style={{background:"#111820",border:"1px solid #1e2d3d",borderRadius:18,padding:18,display:"flex",flexDirection:"column",gap:12}}>
            {(s?.type==="text"||s?.type==="textarea")&&<div style={{fontSize:11,color:"#3a4f63"}}>🎤 Możesz mówić lub pisać</div>}

            {s?.type==="confirm"&&<button onClick={()=>advance(null)} style={{background:"#00c2a8",color:"#000",border:"none",borderRadius:12,padding:14,fontSize:15,fontWeight:800,cursor:"pointer"}}>Tak, jestem gotowy →</button>}
            {s?.type==="text"&&<div style={{display:"flex",gap:10}}>
              <input type={s.mask?"password":"text"} value={current} placeholder={s.placeholder} onChange={(e:any)=>{setCurrent(e.target.value);setError("");}} onKeyDown={(e:any)=>e.key==="Enter"&&tryNext()}
                style={{flex:1,background:"#161e28",border:`1.5px solid ${error?"#e05a6a":"#1e2d3d"}`,borderRadius:12,padding:"12px 16px",fontSize:14,color:"#e8edf3",outline:"none",fontFamily:"inherit"}}/>
              {!s.mask&&<MicButton onResult={handleVoice} disabled={false}/>}
              <Btn onClick={tryNext}/>
            </div>}
            {s?.type==="date"&&<div style={{display:"flex",gap:10}}>
              <input type="date" value={current} onChange={(e:any)=>setCurrent(e.target.value)} style={{flex:1,background:"#161e28",border:"1.5px solid #1e2d3d",borderRadius:12,padding:"12px 16px",fontSize:14,color:"#e8edf3",outline:"none",fontFamily:"inherit"}}/>
              <Btn onClick={()=>{addUserMsg(current);advance(s.field,current);}}/>
            </div>}
            {s?.type==="textarea"&&<div style={{display:"flex",gap:10,alignItems:"flex-end"}}>
              <textarea value={current} placeholder={s.placeholder} rows={3} onChange={(e:any)=>setCurrent(e.target.value)} onKeyDown={(e:any)=>e.key==="Enter"&&!e.shiftKey&&(e.preventDefault(),addUserMsg(current),advance(s.field,current))}
                style={{flex:1,background:"#161e28",border:"1.5px solid #1e2d3d",borderRadius:12,padding:"12px 16px",fontSize:14,color:"#e8edf3",outline:"none",resize:"none",fontFamily:"inherit"}}/>
              <MicButton onResult={handleVoice} disabled={false}/>
              <Btn onClick={()=>{addUserMsg(current);advance(s.field,current);}}/>
            </div>}
            {s?.type==="chips"&&<div style={{display:"flex",flexDirection:"column",gap:10}}>
              <div style={{display:"flex",flexWrap:"wrap",gap:8}}>
                {s.options.map((opt:string)=>{const sel=s.multi?(Array.isArray(answers[s.field])&&answers[s.field].includes(opt)):answers[s.field]===opt;
                  return<button key={opt} onClick={()=>handleChip(opt,s.multi)} style={{background:sel?"#00c2a8":"#161e28",color:sel?"#000":"#7a8fa8",border:`1.5px solid ${sel?"#00c2a8":"#1e2d3d"}`,borderRadius:20,padding:"8px 16px",fontSize:13,fontWeight:sel?700:400,cursor:"pointer"}}>{opt}</button>;})}
              </div>
              {s.multi&&<Btn label="Dalej →" onClick={()=>{addUserMsg([].concat(answers[s.field]||[]).join(", "));advance(s.field,answers[s.field]);}}/>}
            </div>}
            {s?.type==="scale"&&<div style={{display:"flex",flexDirection:"column",gap:10}}>
              <div style={{display:"flex",gap:5}}>
                {[1,2,3,4,5,6,7,8,9,10].map((n:number)=>{const sel=parseInt(answers[s.field])===n;const col=n<=3?"#2ecc8a":n<=6?"#f0a340":"#e05a6a";
                  return<button key={n} onClick={()=>setAnswers((p:any)=>({...p,[s.field]:n}))} style={{flex:1,aspectRatio:"1",background:sel?col:"#161e28",color:sel?"#000":"#7a8fa8",border:`1.5px solid ${sel?col:"#1e2d3d"}`,borderRadius:10,fontSize:13,fontWeight:800,cursor:"pointer"}}>{n}</button>;})}
              </div>
              <div style={{display:"flex",justifyContent:"space-between",fontSize:11,color:"#3a4f63"}}><span>😊 Brak bólu</span><span>😰 Najgorszy możliwy</span></div>
              <Btn onClick={()=>{addUserMsg(`${answers[s.field]}/10`);advance(s.field,answers[s.field]);}}/>
            </div>}
            {s?.type==="triage"&&<div style={{display:"flex",flexDirection:"column",gap:10}}>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:10}}>
                {TRIAGE.map((t:any)=>{const sel=answers[s.field]===t.priority;
                  return<button key={t.label} onClick={()=>setAnswers((p:any)=>({...p,[s.field]:t.priority}))} style={{background:sel?t.color+"30":"#161e28",border:`2px solid ${sel?t.color:"#1e2d3d"}`,borderRadius:14,padding:16,cursor:"pointer",display:"flex",flexDirection:"column",alignItems:"center",gap:6}}>
                    <span style={{fontSize:28}}>{t.icon}</span><span style={{fontSize:13,fontWeight:700,color:sel?t.color:"#7a8fa8"}}>{t.label}</span></button>;})}
              </div>
              <button onClick={()=>{addUserMsg(TRIAGE.find((t:any)=>t.priority===answers[s.field])?.label||"");advance(s.field,answers[s.field]);}}
                style={{background:"#00c2a8",color:"#000",border:"none",borderRadius:12,padding:14,fontSize:15,fontWeight:800,cursor:"pointer"}}>Zakończ wywiad →</button>
            </div>}
            {error&&<div style={{fontSize:12,color:"#e05a6a",fontWeight:600}}>⚠️ {error}</div>}
          </div>
        </div>
      </div>
    </div>
  );
}

function Btn({onClick,label="Dalej →"}:{onClick:()=>void,label?:string}){
  return<button onClick={onClick} style={{background:"#00c2a8",color:"#000",border:"none",borderRadius:12,padding:"12px 20px",fontSize:14,fontWeight:800,cursor:"pointer",whiteSpace:"nowrap",alignSelf:"flex-end"}}>{label}</button>;
}
