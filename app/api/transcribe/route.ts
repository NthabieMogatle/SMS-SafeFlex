import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const maxDuration = 30;

const MAX_BYTES = 25 * 1024 * 1024; // Whisper's 25 MB limit
const OPENAI_URL = "https://api.openai.com/v1/audio/transcriptions";

export async function POST(req: Request) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!process.env.OPENAI_API_KEY) {
    console.error("transcribe: OPENAI_API_KEY is not set");
    return NextResponse.json(
      { error: "Transcription is not configured" },
      { status: 500 },
    );
  }

  let inbound: FormData;
  try {
    inbound = await req.formData();
  } catch (err) {
    console.error("transcribe: failed to parse multipart form", err);
    return NextResponse.json(
      { error: "Invalid request" },
      { status: 400 },
    );
  }

  const audio = inbound.get("audio");
  if (!(audio instanceof Blob)) {
    return NextResponse.json(
      { error: "Missing audio file" },
      { status: 400 },
    );
  }
  if (audio.size === 0) {
    return NextResponse.json(
      { error: "Empty audio file" },
      { status: 400 },
    );
  }
  if (audio.size > MAX_BYTES) {
    return NextResponse.json(
      { error: "Audio file is too large" },
      { status: 413 },
    );
  }

  const filename =
    audio instanceof File && audio.name ? audio.name : "audio.webm";

  const upstream = new FormData();
  upstream.append("file", audio, filename);
  upstream.append("model", "whisper-1");

  let res: Response;
  try {
    res = await fetch(OPENAI_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
      body: upstream,
    });
  } catch (err) {
    console.error("transcribe: fetch to OpenAI failed", err);
    return NextResponse.json(
      { error: "Transcription failed" },
      { status: 502 },
    );
  }

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    console.error(
      `transcribe: OpenAI returned ${res.status}: ${body.slice(0, 1000)}`,
    );
    const status = res.status >= 400 && res.status < 600 ? res.status : 502;
    return NextResponse.json(
      { error: "Transcription failed" },
      { status },
    );
  }

  let data: { text?: unknown };
  try {
    data = (await res.json()) as { text?: unknown };
  } catch (err) {
    console.error("transcribe: failed to parse OpenAI response", err);
    return NextResponse.json(
      { error: "Transcription failed" },
      { status: 502 },
    );
  }

  const text = typeof data.text === "string" ? data.text : "";
  return NextResponse.json({ text });
}
