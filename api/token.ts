export const config = { runtime: 'edge' };

export default async function handler(req: Request) {
  const LIVEAVATAR_KEY = process.env.LIVEAVATAR_KEY || "";
  const AVATAR_ID = process.env.AVATAR_ID || "";

  const res = await fetch("https://api.liveavatar.com/v1/sessions/token", {
    method: "POST",
    headers: {
      "X-API-KEY": LIVEAVATAR_KEY,
      "Content-Type": "application/json",
      "accept": "application/json",
    },
    body: JSON.stringify({
      mode: "FULL",
      avatar_id: AVATAR_ID,
      avatar_persona: { language: "pl" }
    }),
  });

  const data = await res.json();
  return new Response(JSON.stringify(data), {
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*"
    }
  });
}
