export const config = { runtime: 'edge' };

export default async function handler(req: Request) {
  const LIVEAVATAR_KEY = process.env.LIVEAVATAR_KEY || "";
  const AVATAR_ID = process.env.AVATAR_ID || "";

  try {
    const res = await fetch("https://api.liveavatar.com/v1/sessions/token", {
      method: "POST",
      headers: {
        "X-API-KEY": LIVEAVATAR_KEY,
        "Content-Type": "application/json",
        "accept": "application/json",
      },
      body: JSON.stringify({
        mode: "LITE",
        avatar_id: AVATAR_ID,
        avatar_persona: { language: "pl" }
      }),
    });

    const text = await res.text();
    return new Response(text, {
      status: res.status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  } catch(e: any) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
}
