import { useState, useRef, useEffect } from "react";

const ELEVEN_KEY = "sk_1a6f6cfd565c4231eac37c52981afd058eb1c8ca1e042856";
const ELEVEN_VOICE_ID = "21m00Tcm4TlvDq8ikWAM";

const G = {
  bg:"#0d1117",panel:"#111820",card:"#161e28",border:"#1e2d3d",
  teal:"#00c2a8",tealDim:"#00c2a818",tealMid:"#00c2a840",
  rose:"#e05a6a",amber:"#f0a340",
  text:"#e8edf3",textMid:"#7a8fa8",textDim:"#3a4f63",green:"#2ecc8a",
};

const STEPS = [
  {id:"welcome",phase:"Powitanie",nurseText:"Dzień dobry! Jestem Anna, Pana wirtualna pielęgniarka pierwszego kontaktu. Zanim trafi Pan do lekarza, przeprowadzę krótki wywiad medyczny. Wszystko jest poufne. Gotowy?",type:"confirm",field:null},
  {id:"imie",phase:"Dane osobowe",nurseText:"Jak mam się do Pana zwracać? Proszę podać imię i nazwisko.",type:"text",field:"imieNazwisko",placeholder:"np. Jan Kowalski",validate:(v:string)=>v.trim().split(" ").length>=2||"Proszę podać imię i nazwisko"},
  {id:"pesel",phase:"Dane osobowe",nurseText:"Dziękuję. Proszę teraz podać numer PESEL.",type:"text",field:"pesel",placeholder:"11 cyfr",mask:true,validate:(v:string)=>/^\d{11}$/.test(v.replace(/\s/g,""))||"PESEL musi mieć 11 cyfr"},
  {id:"dataUrodzenia",phase:"Dane osobowe",nurseText:"Proszę potwierdzić datę urodzenia.",type:"date",field:"dataUrodzenia"},
  {id:"telefon",phase:"Dane osobowe",nurseText:"Na jaki numer telefonu mamy się z Panem kontaktować?",type:"text",field:"telefon",placeholder:"np. 600 123 456",validate:(v:string)=>/^[\d\s+\-]{9,}$/.test(v)||"Podaj poprawny numer"},
  {id:"dolegliwosci",phase:"Dolegliwości",nurseText:"Co Pana do nas sprowadza? Proszę opisać główną dolegliwość swoimi słowami.",type:"textarea",field:"dolegliwoscGlowna",placeholder:"Opisz objawy..."},
  {id:"lokalizacja",phase:"Dolegliwości",nurseText:"Gdzie dokładnie odczuwa Pan te dolegliwości?",type:"text",field:"lokalizacja",placeholder:"np. klatka piersiowa, głowa, brzuch..."},
  {id:"charakter",phase:"Dolegliwości",nurseText:"Jak opisałby Pan charakter tego bólu lub dyskomfortu?",type:"chips",field:"charakter",options:["Tępy","Ostry","Piekący","Pulsujący","Uciskający","Kłujący","Promieniujący","Inny"]},
  {id:"natezenie",phase:"Dolegliwości",nurseText:"W skali od 1 do 10, jak ocenia Pan nasilenie dolegliwości?",type:"scale",field:"natezenie"},
  {id:"czas",phase:"Dolegliwości",nurseText:"Od kiedy trwają te objawy?",type:"chips",field:"czasTrwania",options:["Kilka godzin","1–2 dni","Kilka dni","Ponad tydzień","Ponad miesiąc","Przewlekle"]},
  {id:"czynniki",phase:"Dolegliwości",nurseText:"Czy coś nasila lub łagodzi te dolegliwości?",type:"textarea",field:"czynniki",placeholder:"np. nasila się przy ruchu, łagodnieje po odpoczynku..."},
  {id:"choroby",phase:"Historia medyczna",nurseText:"Czy ma Pan stwierdzone choroby przewlekłe?",type:"chips",field:"chorobyPrzewlekle",multi:true,options:["Nadciśnienie","Cukrzyca t.1","Cukrzyca t.2","Choroba wieńcowa","Astma / POChP","Niedoczynność tarczycy","Niewydolność nerek","Depresja / lęki","Żadna z powyższych"]},
  {id:"operacje",phase:"Historia medyczna",nurseText:"Czy był Pan kiedyś operowany?",type:"textarea",field:"operacje",placeholder:"np. wyrostek 2015, brak operacji..."},
  {id:"leki",phase:"Leki i alergie",nurseText:"Proszę wymienić leki przyjmowane regularnie wraz z dawkami.",type:"textarea",field:"leki",placeholder:"np. Metformina 500mg 2x dziennie..."},
  {id:"alergie",phase:"Leki i alergie",nurseText:"Czy ma Pan znane alergie na leki, pokarmy lub inne substancje?",type:"chips",field:"alergie",multi:true,options:["Penicylina","Aspiryna / NLPZ","Jod / kontrast","Lateks","Pokarmy","Brak alergii","Inne"]},
  {id:"triage",phase:"Triage",nurseText:"Ostatnie pytanie. Jak czuje się Pan w tej chwili?",type:"triage",field:"stanAktualny"},
];

const PHASES=[...new Set(STEPS.map((s:any)=>s.phase))];
const PHASE_ICONS:any={"Powitanie":"👋","Dane osobowe":"📋","Dolegliwości":"🩺","Historia medyczna":"📁","Leki i alergie":"💊","Triage":"🚦"};
const SPECIALIST_MAP:any={"Nadciśnienie":"Kardiolog","Cukrzyca t.1":"Diabetolog","Cukrzyca t.2":"Diabetolog","Choroba wieńcowa":"Kardiolog","Astma / POChP":"Pulmonolog","Niedoczynność tarczycy":"Endokrynolog","Niewydolność nerek":"Nefrolog","Depresja / lęki":"Psychiatra"};
const TRIAGE=[{label:"Dobrze",icon:"😊",color:G.green,priority:3},{label:"Średnio",icon:"😐",color:G.amber,priority:2},{label:"Źle",icon:"😟",color:G.rose,priority:1},{label:"Bardzo źle",icon:"😰",color:"#cc2244",priority:0}];

function NurseAvatarSVG({speaking}:{speaking:boolean}) {
  return (
    <div style={{width:"100%",height:"100%",display:"flex",alignItems:"center",justifyContent:"center",background:"linear-gradient(180deg,#0d2030 0%,#0a1520 100%)",position:"relative",overflow:"hidden",borderRadius:16}}>
      <svg width="210" height="290" viewBox="0 0 220 300" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="110" cy="292" rx="92" ry="62" fill="#0a4040"/>
        <path d="M73 178 Q110 200 147 178 L160 260 Q110 275 60 260 Z" fill="#0d5555"/>
        <rect x="96" y="155" width="28" height="30" rx="14" fill="#d4a882"/>
        <ellipse cx="110" cy="115" rx="50" ry="54" fill="#d4a882"/>
        <path d="M60 108 Q63 54 110 49 Q157 54 160 108 Q157 80 110 77 Q63 80 60 108Z" fill="#2a1a0a"/>
        <ellipse cx="62" cy="115" rx="12" ry="22" fill="#2a1a0a"/>
        <ellipse cx="158" cy="115" rx="12" ry="22" fill="#2a1a0a"/>
        <rect x="82" y="72" width="56" height="13" rx="6.5" fill="white" opacity="0.96"/>
        <rect x="107" y="71" width="6" height="13" rx="1.5" fill={G.rose}/>
        <rect x="100" y="76" width="20" height="4" rx="1.5" fill={G.rose}/>
        <ellipse cx="93" cy="115" rx="10" ry="11" fill="white"/>
        <ellipse cx="127" cy="115" rx="10" ry="11" fill="white"/>
        <circle cx="94" cy="116" r="7" fill="#1a0a05"/>
        <circle cx="128" cy="116" r="7" fill="#1a0a05"/>
        <circle cx="96" cy="114" r="2.5" fill="white"/>
        <circle cx="130" cy="114" r="2.5" fill="white"/>
        {speaking&&<circle cx="93" cy="115" r="10" fill="none" stroke={G.teal} strokeWidth="1.5" opacity="0.5"><animate attributeName="r" values="10;17;10" dur="1.4s" repeatCount="indefinite"/></circle>}
        <path d="M82 103 Q93 99 104 102" stroke="#2a1a0a" strokeWidth="2.5" fill="none" strokeLinecap="round"/>
        <path d="M116 102 Q127 99 138 103" stroke="#2a1a0a" strokeWidth="2.5" fill="none" strokeLinecap="round"/>
        {speaking?<ellipse cx="110" cy="143" rx="14" ry="7" fill="#c06050"><animate attributeName="ry" values="7;3;7" dur="0.32s" repeatCount="indefinite"/></ellipse>
          :<path d="M97 141 Q110 152 123 141" stroke="#c06050" strokeWidth="2.5" fill="none" strokeLinecap="round"/>}
        <path d="M87 178 Q72 192 70 210 Q70 225 83 225 Q96 225 96 210 Q96 195 108 191" stroke={G.teal} strokeWidth="3.5" fill="none" strokeLinecap="round"/>
        <circle cx="83" cy="227" r="11" fill="none" stroke={G.teal} strokeWidth="3.5"/>
        <circle cx="83" cy="227" r="4.5" fill={G.teal}/>
      </svg>
      <div style={{position:"absolute",bottom:16,left:"50%",transform:"translateX(-50%)",display:"flex",gap:4,alignItems:"flex-end",height:30}}>
        {[1,2,3,4,5].map(i=>(
          <div key={i} style={{width:4,borderRadius:2,background:G.teal,height:speaking?undefined:5,opacity:speaking?1:0.2,
            animation:speaking?`sbar${i} ${0.28+i*0.07}s ease-in-out infinite alternate`:"none"}}/>
        ))}
      </div>
      <div style={{position:"absolute",top:12,left:12,background:"#00000088",borderRadius:8,padding:"5px 11px",fontSize:11,color:G.teal,fontWeight:700}}>
        {speaking?"🔊 Mówię...":"👩‍⚕️ ANNA"}
      </div>
    </div>
  );
}

export default function App() {
  const [heygenKey,setHeygenKey]=useState("");
  const [heygenAvatarId]=useState("d086ff37eb784ac9b8b7aa2371ac9f1b");
  const [useHeyGen,setUseHeyGen]=useState(false);
  const [step,setStep]=useState(0);
  const [answers,setAnswers]=useState<any>({});
  const [current,setCurrent]=useState("");
  const [error,setError]=useState("");
  const [appPhase,setAppPhase]=useState("config");
  const [chatLog,setChatLog]=useState<any[]>([]);
  const [speaking,setSpeaking]=useState(false);
  const [ttsStatus,setTtsStatus]=useState("");
  const audioRef=useRef<HTMLAudioElement>(null);
  const bottomRef=useRef<HTMLDivElement>(null);
  const s=(STEPS as any)[step];
  const progress=(step/(STEPS.length-1))*100;
  const currentPhaseIdx=PHASES.indexOf(s?.phase);

  useEffect(()=>{bottomRef.current?.scrollIntoView({behavior:"smooth"})},[chatLog]);
  useEffect(()=>{
    if(appPhase!=="interview") return;
    const st=(STEPS as any)[step];
    if(!st) return;
    setChatLog((prev:any)=>[...prev,{role:"nurse",text:st.nurseText}]);
    speakText(st.nurseText);
  },[step,appPhase]);

  async function speakText(text:string){
    setSpeaking(true);setTtsStatus("🔊 Mówię...");
    try{
      const res=await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${ELEVEN_VOICE_ID}`,{
        method:"POST",headers:{"Content-Type":"application/json","xi-api-key":ELEVEN_KEY},
        body:JSON.stringify({text,model_id:"eleven_multilingual_v2",voice_settings:{stability:0.55,similarity_boost:0.82,style:0.25}}),
      });
      if(!res.ok) throw new Error(`HTTP ${res.status}`);
      const blob=await res.blob();const url=URL.createObjectURL(blob);
      if(audioRef.current){
        audioRef.current.src=url;
        audioRef.current.onended=()=>{setSpeaking(false);setTtsStatus("");URL.revokeObjectURL(url);};
        audioRef.current.play();
      }
    }catch(e:any){setSpeaking(false);setTtsStatus(`⚠️ ${e.message}`);}
  }

  function addUserMsg(text:string){setChatLog((prev:any)=>[...prev,{role:"user",text}]);}
  function advance(field:string|null,val?:any){
    if(field) setAnswers((prev:any)=>({...prev,[field]:val!==undefined?val:current}));
    setCurrent("");setError("");
    if(step+1>=STEPS.length) setAppPhase("summary"); else setStep(p=>p+1);
  }
  function tryNext(){
    if(s.validate){const r=s.validate(current);if(r!==true){setError(r);return;}}
    addUserMsg(current);advance(s.field,current);
  }
  function handleChip(opt:string,multi:boolean){
    if(multi){
      const arr=Array.isArray(answers[s.field])?answers[s.field]:[];
      setAnswers((prev:any)=>({...prev,[s.field]:arr.includes(opt)?arr.filter((x:string)=>x!==opt):[...arr,opt]}));
    } else {addUserMsg(opt);advance(s.field,opt);}
  }
  function getRouting(){
    const priority=answers.stanAktualny;
    const chronic=answers.chorobyPrzewlekle||[];
    const specs=[...new Set(chronic.flatMap((c:string)=>SPECIALIST_MAP[c]?[SPECIALIST_MAP[c]]:[]))];
    const sev=parseInt(answers.natezenie)||5;
    if(priority===0||sev>=9) return{color:"#cc2244",label:"PILNY — SOR",wait:"Natychmiast",specs:["SOR"]};
    if(priority===1||sev>=7) return{color:G.rose,label:"PILNY — Lekarz dyżurny",wait:"Do 30 minut",specs:specs.length?specs:["Lekarz pierwszego kontaktu"]};
    if(priority===2||sev>=4) return{color:G.amber,label:"NORMALNY — Umów wizytę",wait:"Do 48h",specs:specs.length?specs:["Lekarz pierwszego kontaktu"]};
    return{color:G.green,label:"PLANOWY — Wizyta kontrolna",wait:"Do 2 tygodni",specs:specs.length?specs:["Lekarz pierwszego kontaktu"]};
  }

  if(appPhase==="config") return(
    <div style={{minHeight:"100vh",background:G.bg,display:"flex",alignItems:"center",justifyContent:"center",fontFamily:"system-ui",padding:24}}>
      <style>{`*{box-sizing:border-box}button:hover{opacity:.85}button{transition:opacity .15s}@keyframes sbar1{from{height:4px}to{height:9px}}@keyframes sbar2{from{height:4px}to{height:18px}}@keyframes sbar3{from{height:4px}to{height:24px}}@keyframes sbar4{from{height:4px}to{height:15px}}@keyframes sbar5{from{height:4px}to{height:7px}}`}</style>
      <div style={{width:"100%",maxWidth:480}}>
        <div style={{textAlign:"center",marginBottom:32}}>
          <div style={{fontSize:52}}>👩‍⚕️</div>
          <div style={{fontSize:11,letterSpacing:4,color:G.teal,fontWeight:700,textTransform:"uppercase",marginBottom:8}}>System Wywiadu Medycznego</div>
          <div style={{fontSize:34,fontWeight:800,color:G.text}}>Anna</div>
          <div style={{color:G.textMid,fontSize:14,marginTop:6}}>Wirtualna pielęgniarka pierwszego kontaktu</div>
        </div>
        <div style={{background:G.panel,border:`1px solid ${G.border}`,borderRadius:20,padding:28,display:"flex",flexDirection:"column",gap:18}}>
          <div style={{background:G.tealDim,border:`1px solid ${G.tealMid}`,borderRadius:14,padding:16}}>
            <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:useHeyGen?14:0}}>
              <div>
                <div style={{fontSize:13,fontWeight:700,color:G.teal}}>🎬 HeyGen — Wideo 3D</div>
                <div style={{fontSize:11,color:G.textMid,marginTop:2}}>Realistyczna pielęgniarka wideo</div>
              </div>
              <div onClick={()=>setUseHeyGen(v=>!v)} style={{width:44,height:24,borderRadius:12,background:useHeyGen?G.teal:G.border,position:"relative",cursor:"pointer",transition:"background .2s",flexShrink:0}}>
                <div style={{position:"absolute",top:3,left:useHeyGen?23:3,width:18,height:18,borderRadius:"50%",background:"white",transition:"left .2s"}}/>
              </div>
            </div>
            {useHeyGen&&<div style={{marginTop:12}}>
              <div style={{fontSize:11,letterSpacing:2,textTransform:"uppercase",color:G.textMid,fontWeight:600,marginBottom:7}}>Klucz API HeyGen</div>
              <input type="password" value={heygenKey} onChange={e=>setHeygenKey(e.target.value)} placeholder="Wklej nowy klucz HeyGen..."
                style={{width:"100%",background:G.card,border:`1.5px solid ${G.border}`,borderRadius:11,padding:"11px 15px",fontSize:13,color:G.text,outline:"none",fontFamily:"inherit"}}/>
              <div style={{fontSize:11,color:G.textDim,marginTop:8}}>Avatar ID: d086ff37eb784ac9b8b7aa2371ac9f1b (już wpisany)</div>
            </div>}
          </div>
          <div style={{background:"#2ecc8a18",border:"1px solid #2ecc8a40",borderRadius:14,padding:"12px 16px",fontSize:12,color:G.green}}>
            ✅ <b>ElevenLabs</b> aktywny — Anna mówi polskim głosem
          </div>
          <button onClick={()=>setAppPhase("interview")} style={{background:G.teal,color:"#000",border:"none",borderRadius:14,padding:16,fontSize:16,fontWeight:800,cursor:"pointer"}}>
            Rozpocznij wywiad →
          </button>
        </div>
      </div>
    </div>
  );

  if(appPhase==="summary"){
    const r=getRouting();
    return(
      <div style={{minHeight:"100vh",background:G.bg,fontFamily:"system-ui",padding:24,display:"flex",justifyContent:"center"}}>
        <div style={{width:"100%",maxWidth:680,paddingBottom:60}}>
          <div style={{textAlign:"center",padding:"36px 0 24px"}}><div style={{fontSize:52}}>✅</div>
            <div style={{fontSize:28,fontWeight:800,color:G.text}}>Wywiad zakończony</div>
            <div style={{color:G.textMid,marginTop:8}}>Dziękuję, <b style={{color:G.text}}>{answers.imieNazwisko}</b>.</div>
          </div>
          <div style={{background:r.color+"22",border:`2px solid ${r.color}`,borderRadius:16,padding:"20px 24px",marginBottom:14,display:"flex",alignItems:"center",gap:16}}>
            <div style={{fontSize:40}}>🚦</div>
            <div><div style={{fontSize:11,letterSpacing:3,color:r.color,fontWeight:800,textTransform:"uppercase"}}>Priorytet triażu</div>
              <div style={{fontSize:20,fontWeight:800,color:G.text,marginTop:4}}>{r.label}</div>
              <div style={{color:G.textMid,fontSize:13}}>Czas: <b style={{color:r.color}}>{r.wait}</b></div>
            </div>
          </div>
          {[["📋 Dane pacjenta",[["Imię i nazwisko",answers.imieNazwisko],["PESEL",answers.pesel?.replace(/\d(?=\d{4})/g,"•")],["Data urodzenia",answers.dataUrodzenia],["Telefon",answers.telefon]]],
            ["🩺 Dolegliwości",[["Główna",answers.dolegliwoscGlowna],["Lokalizacja",answers.lokalizacja],["Charakter",answers.charakter],["Nasilenie",answers.natezenie?`${answers.natezenie}/10`:null],["Czas",answers.czasTrwania]]],
            ["📁 Historia",[["Choroby",[].concat(answers.chorobyPrzewlekle||[]).join(", ")],["Operacje",answers.operacje]]],
            ["💊 Leki",[["Leki stałe",answers.leki],["Alergie",[].concat(answers.alergie||[]).join(", ")]]]
          ].map(([title,rows]:any)=>(
            <div key={title} style={{background:G.panel,border:`1px solid ${G.border}`,borderRadius:14,padding:"16px 20px",marginBottom:10}}>
              <div style={{fontSize:13,fontWeight:700,color:G.textMid,marginBottom:10}}>{title}</div>
              {rows.map(([l,v]:any)=>(
                <div key={l} style={{display:"flex",gap:12,fontSize:13,marginBottom:6}}>
                  <span style={{color:G.textDim,minWidth:150,flexShrink:0}}>{l}</span>
                  <span style={{color:G.text,fontWeight:600}}>{v||<span style={{color:G.textDim,fontStyle:"italic"}}>nie podano</span>}</span>
                </div>
              ))}
            </div>
          ))}
          <button onClick={()=>{setStep(0);setAnswers({});setCurrent("");setChatLog([]);setAppPhase("interview");}}
            style={{width:"100%",marginTop:8,background:"transparent",border:`1px solid ${G.border}`,color:G.textMid,borderRadius:14,padding:14,fontSize:14,cursor:"pointer"}}>
            🔄 Nowy wywiad
          </button>
        </div>
      </div>
    );
  }

  return(
    <div style={{minHeight:"100vh",background:G.bg,fontFamily:"system-ui",display:"flex",flexDirection:"column"}}>
      <audio ref={audioRef} style={{display:"none"}}/>
      <style>{`*{box-sizing:border-box}::-webkit-scrollbar{width:4px}::-webkit-scrollbar-thumb{background:#1e2d3d;border-radius:2px}input,textarea{color-scheme:dark}input[type=date]::-webkit-calendar-picker-indicator{filter:invert(.5)}button:hover{opacity:.85!important}button{transition:opacity .15s}@keyframes sbar1{from{height:4px}to{height:9px}}@keyframes sbar2{from{height:4px}to{height:18px}}@keyframes sbar3{from{height:4px}to{height:24px}}@keyframes sbar4{from{height:4px}to{height:15px}}@keyframes sbar5{from{height:4px}to{height:7px}}`}</style>
      <div style={{background:G.panel,borderBottom:`1px solid ${G.border}`,padding:"0 20px",height:52,display:"flex",alignItems:"center",gap:12,position:"sticky",top:0,zIndex:10}}>
        <span style={{fontSize:14,fontWeight:800,color:G.teal}}>👩‍⚕️ ANNA</span>
        <span style={{fontSize:11,color:G.textMid}}>Pielęgniarka Pierwszego Kontaktu</span>
        <div style={{flex:1}}/>{ttsStatus&&<span style={{fontSize:11,color:G.teal}}>{ttsStatus}</span>}
        <span style={{fontSize:11,color:G.textDim}}>Krok {step+1}/{STEPS.length}</span>
      </div>
      <div style={{height:3,background:G.border}}><div style={{height:"100%",width:`${progress}%`,background:G.teal,transition:"width .4s ease"}}/></div>
      <div style={{flex:1,display:"flex",gap:20,padding:20,maxWidth:1100,margin:"0 auto",width:"100%"}}>
        <div style={{width:260,flexShrink:0,display:"flex",flexDirection:"column",gap:14}}>
          <div style={{borderRadius:18,overflow:"hidden",height:320,border:`1px solid ${G.border}`}}>
            {useHeyGen&&heygenKey
              ?<iframe src={`https://app.heygen.com/embeds/typed_avatar?avatar_id=${heygenAvatarId}&api_key=${heygenKey}`} allow="camera;microphone;autoplay" style={{width:"100%",height:"100%",border:"none"}} title="HeyGen"/>
              :<NurseAvatarSVG speaking={speaking}/>}
          </div>
          <div style={{background:G.panel,border:`1px solid ${G.border}`,borderRadius:16,padding:16}}>
            {PHASES.map((p:any,i:number)=>(
              <div key={p} style={{display:"flex",alignItems:"center",gap:10,padding:"6px 0",borderBottom:i<PHASES.length-1?`1px solid ${G.border}`:"none"}}>
                <div style={{width:24,height:24,borderRadius:"50%",flexShrink:0,display:"flex",alignItems:"center",justifyContent:"center",fontSize:11,fontWeight:700,
                  background:i<currentPhaseIdx?G.teal:i===currentPhaseIdx?G.tealMid:G.border,border:i===currentPhaseIdx?`2px solid ${G.teal}`:"none",
                  color:i<currentPhaseIdx?"#000":i===currentPhaseIdx?G.teal:G.textDim}}>
                  {i<currentPhaseIdx?"✓":PHASE_ICONS[p]}
                </div>
                <span style={{fontSize:12,color:i<=currentPhaseIdx?G.text:G.textDim,fontWeight:i===currentPhaseIdx?700:400}}>{p}</span>
              </div>
            ))}
          </div>
          <button onClick={()=>speakText(s?.nurseText)} style={{background:G.tealDim,border:`1px solid ${G.tealMid}`,color:G.teal,borderRadius:12,padding:"9px 16px",fontSize:13,fontWeight:600,cursor:"pointer"}}>🔊 Powtórz pytanie</button>
        </div>
        <div style={{flex:1,display:"flex",flexDirection:"column",gap:14,minWidth:0}}>
          <div style={{flex:1,background:G.panel,border:`1px solid ${G.border}`,borderRadius:18,padding:18,overflowY:"auto",maxHeight:400,display:"flex",flexDirection:"column",gap:12}}>
            {chatLog.map((m:any,i:number)=>(
              <div key={i} style={{display:"flex",gap:10,flexDirection:m.role==="user"?"row-reverse":"row",alignItems:"flex-start"}}>
                <div style={{width:30,height:30,borderRadius:"50%",background:m.role==="nurse"?G.tealDim:"#ffffff10",display:"flex",alignItems:"center",justifyContent:"center",fontSize:15,flexShrink:0}}>{m.role==="nurse"?"👩‍⚕️":"🧑"}</div>
                <div style={{maxWidth:"78%",background:m.role==="nurse"?G.tealDim:"#ffffff08",border:`1px solid ${m.role==="nurse"?G.tealMid:G.border}`,borderRadius:14,padding:"10px 14px",fontSize:14,color:G.text,lineHeight:1.6,borderBottomLeftRadius:m.role==="nurse"?4:14,borderBottomRightRadius:m.role==="user"?4:14}}>{m.text}</div>
              </div>
            ))}
            <div ref={bottomRef}/>
          </div>
          <div style={{background:G.panel,border:`1px solid ${G.border}`,borderRadius:18,padding:18,display:"flex",flexDirection:"column",gap:14}}>
            {s?.type==="confirm"&&<button onClick={()=>advance(null)} style={{background:G.teal,color:"#000",border:"none",borderRadius:12,padding:14,fontSize:15,fontWeight:800,cursor:"pointer"}}>Tak, jestem gotowy →</button>}
            {s?.type==="text"&&<div style={{display:"flex",gap:10}}><input type={s.mask?"password":"text"} value={current} placeholder={s.placeholder} onChange={e=>{setCurrent(e.target.value);setError("");}} onKeyDown={e=>e.key==="Enter"&&tryNext()} style={{flex:1,background:G.card,border:`1.5px solid ${error?G.rose:G.border}`,borderRadius:12,padding:"12px 16px",fontSize:14,color:G.text,outline:"none",fontFamily:"inherit"}}/><Btn onClick={tryNext}/></div>}
            {s?.type==="date"&&<div style={{display:"flex",gap:10}}><input type="date" value={current} onChange={e=>setCurrent(e.target.value)} style={{flex:1,background:G.card,border:`1.5px solid ${G.border}`,borderRadius:12,padding:"12px 16px",fontSize:14,color:G.text,outline:"none",fontFamily:"inherit"}}/><Btn onClick={()=>{addUserMsg(current);advance(s.field,current);}}/></div>}
            {s?.type==="textarea"&&<div style={{display:"flex",gap:10,alignItems:"flex-end"}}><textarea value={current} placeholder={s.placeholder} rows={3} onChange={e=>setCurrent(e.target.value)} onKeyDown={e=>e.key==="Enter"&&!e.shiftKey&&(e.preventDefault(),addUserMsg(current),advance(s.field,current))} style={{flex:1,background:G.card,border:`1.5px solid ${G.border}`,borderRadius:12,padding:"12px 16px",fontSize:14,color:G.text,outline:"none",resize:"none",fontFamily:"inherit"}}/><Btn onClick={()=>{addUserMsg(current);advance(s.field,current);}}/></div>}
            {s?.type==="chips"&&<div style={{display:"flex",flexDirection:"column",gap:10}}>
              <div style={{display:"flex",flexWrap:"wrap",gap:8}}>{s.options.map((opt:string)=>{const sel=s.multi?(Array.isArray(answers[s.field])&&answers[s.field].includes(opt)):answers[s.field]===opt;return<button key={opt} onClick={()=>handleChip(opt,s.multi)} style={{background:sel?G.teal:G.card,color:sel?"#000":G.textMid,border:`1.5px solid ${sel?G.teal:G.border}`,borderRadius:20,padding:"8px 16px",fontSize:13,fontWeight:sel?700:400,cursor:"pointer"}}>{opt}</button>;})}</div>
              {s.multi&&<Btn label="Dalej →" onClick={()=>{addUserMsg([].concat(answers[s.field]||[]).join(", "));advance(s.field,answers[s.field]);}}/>}
            </div>}
            {s?.type==="scale"&&<div style={{display:"flex",flexDirection:"column",gap:10}}>
              <div style={{display:"flex",gap:5}}>{[1,2,3,4,5,6,7,8,9,10].map(n=>{const sel=parseInt(answers[s.field])===n;const col=n<=3?G.green:n<=6?G.amber:G.rose;return<button key={n} onClick={()=>setAnswers((p:any)=>({...p,[s.field]:n}))} style={{flex:1,aspectRatio:"1",background:sel?col:G.card,color:sel?"#000":G.textMid,border:`1.5px solid ${sel?col:G.border}`,borderRadius:10,fontSize:13,fontWeight:800,cursor:"pointer"}}>{n}</button>;})}</div>
              <Btn onClick={()=>{addUserMsg(`${answers[s.field]}/10`);advance(s.field,answers[s.field]);}}/>
            </div>}
            {s?.type==="triage"&&<div style={{display:"flex",flexDirection:"column",gap:10}}>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:10}}>{TRIAGE.map(t=>{const sel=answers[s.field]===t.priority;return<button key={t.label} onClick={()=>setAnswers((p:any)=>({...p,[s.field]:t.priority}))} style={{background:sel?t.color+"30":G.card,border:`2px solid ${sel?t.color:G.border}`,borderRadius:14,padding:16,cursor:"pointer",display:"flex",flexDirection:"column",alignItems:"center",gap:6}}><span style={{fontSize:28}}>{t.icon}</span><span style={{fontSize:13,fontWeight:700,color:sel?t.color:G.textMid}}>{t.label}</span></button>;})}</div>
              <button onClick={()=>{addUserMsg(TRIAGE.find(t=>t.priority===answers[s.field])?.label||"");advance(s.field,answers[s.field]);}} style={{background:G.teal,color:"#000",border:"none",borderRadius:12,padding:14,fontSize:15,fontWeight:800,cursor:"pointer"}}>Zakończ wywiad →</button>
            </div>}
            {error&&<div style={{fontSize:12,color:G.rose,fontWeight:600}}>⚠️ {error}</div>}
          </div>
        </div>
      </div>
    </div>
  );
}

function Btn({onClick,label="Dalej →"}:{onClick:()=>void,label?:string}){
  return <button onClick={onClick} style={{background:G.teal,color:"#000",border:"none",borderRadius:12,padding:"12px 20px",fontSize:14,fontWeight:800,cursor:"pointer",whiteSpace:"nowrap",alignSelf:"flex-end"}}>{label}</button>;
}
