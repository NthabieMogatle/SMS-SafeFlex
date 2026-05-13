"use client";

import { useCallback, useEffect, useRef, useState } from "react";

export type VoiceInput = {
  isRecording: boolean;
  isTranscribing: boolean;
  error: string | null;
  supported: boolean | null;
  start: () => Promise<void>;
  stop: () => void;
};

function pickMimeType(): string | undefined {
  if (typeof MediaRecorder === "undefined") return undefined;
  const candidates = [
    "audio/webm;codecs=opus",
    "audio/webm",
    "audio/mp4",
    "audio/mp4;codecs=mp4a.40.2",
    "audio/aac",
  ];
  for (const t of candidates) {
    if (MediaRecorder.isTypeSupported(t)) return t;
  }
  return undefined;
}

function extensionFor(mime: string | undefined): string {
  if (!mime) return "webm";
  if (mime.includes("webm")) return "webm";
  if (mime.includes("mp4")) return "mp4";
  if (mime.includes("aac")) return "aac";
  if (mime.includes("ogg")) return "ogg";
  return "webm";
}

export function useVoiceInput(
  onTranscript: (text: string) => void,
): VoiceInput {
  const [isRecording, setIsRecording] = useState(false);
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [supported, setSupported] = useState<boolean | null>(null);

  const recorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const mimeRef = useRef<string | undefined>(undefined);
  const onTranscriptRef = useRef(onTranscript);

  useEffect(() => {
    onTranscriptRef.current = onTranscript;
  }, [onTranscript]);

  const releaseStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => {
      try {
        t.stop();
      } catch {
        /* ignore */
      }
    });
    streamRef.current = null;
  }, []);

  useEffect(() => {
    const ok =
      typeof window !== "undefined" &&
      typeof navigator !== "undefined" &&
      !!navigator.mediaDevices?.getUserMedia &&
      typeof window.MediaRecorder !== "undefined";
    setSupported(ok);
    return () => {
      // On unmount, discard any in-flight recording instead of uploading it:
      // detach the handlers so recorder.stop() doesn't fire the upload path
      // or call setState on an unmounted component.
      const rec = recorderRef.current;
      if (rec) {
        rec.ondataavailable = null;
        rec.onstop = null;
        rec.onerror = null;
        if (rec.state !== "inactive") {
          try {
            rec.stop();
          } catch {
            /* ignore */
          }
        }
      }
      recorderRef.current = null;
      chunksRef.current = [];
      releaseStream();
    };
  }, [releaseStream]);

  const start = useCallback(async () => {
    setError(null);
    if (
      typeof window === "undefined" ||
      !navigator.mediaDevices?.getUserMedia ||
      typeof window.MediaRecorder === "undefined"
    ) {
      setError(
        "Voice input isn't supported in this browser. Try Chrome or Safari.",
      );
      return;
    }

    let stream: MediaStream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (err) {
      const name =
        err && typeof err === "object" && "name" in err
          ? String((err as { name: unknown }).name)
          : "";
      if (name === "NotAllowedError" || name === "SecurityError") {
        setError(
          "Microphone access was denied. Allow it in your browser settings and try again.",
        );
      } else if (name === "NotFoundError" || name === "OverconstrainedError") {
        setError("No microphone was found on this device.");
      } else {
        setError("Couldn't access the microphone. Try again.");
      }
      setIsRecording(false);
      return;
    }

    streamRef.current = stream;
    const mime = pickMimeType();
    mimeRef.current = mime;
    chunksRef.current = [];

    let recorder: MediaRecorder;
    try {
      recorder = mime
        ? new MediaRecorder(stream, { mimeType: mime })
        : new MediaRecorder(stream);
    } catch (err) {
      console.error("MediaRecorder construction failed", err);
      releaseStream();
      setError("Couldn't start voice input. Try again.");
      setIsRecording(false);
      return;
    }

    recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) chunksRef.current.push(e.data);
    };

    recorder.onerror = () => {
      setError("Recording failed. Try again.");
      setIsRecording(false);
      setIsTranscribing(false);
      releaseStream();
    };

    recorder.onstop = async () => {
      const chunks = chunksRef.current;
      chunksRef.current = [];
      releaseStream();
      setIsRecording(false);

      if (chunks.length === 0) {
        setIsTranscribing(false);
        return;
      }

      const type = mimeRef.current || chunks[0].type || "audio/webm";
      const blob = new Blob(chunks, { type });
      if (blob.size === 0) {
        setIsTranscribing(false);
        return;
      }

      setIsTranscribing(true);
      try {
        const form = new FormData();
        const file = new File([blob], `audio.${extensionFor(type)}`, { type });
        form.append("audio", file);

        const res = await fetch("/api/transcribe", {
          method: "POST",
          body: form,
        });
        if (!res.ok) {
          if (res.status === 413) {
            setError("That recording is too long. Try a shorter clip.");
          } else {
            setError("Transcription failed. Try again.");
          }
          return;
        }
        const data = (await res.json()) as { text?: string };
        const text = (data.text ?? "").trim();
        if (text) onTranscriptRef.current(text);
      } catch {
        setError("Couldn't reach the transcription service. Try again.");
      } finally {
        setIsTranscribing(false);
      }
    };

    recorderRef.current = recorder;
    try {
      recorder.start();
      setIsRecording(true);
    } catch (err) {
      console.error("MediaRecorder.start failed", err);
      releaseStream();
      setError("Couldn't start voice input. Try again.");
      setIsRecording(false);
    }
  }, [releaseStream]);

  const stop = useCallback(() => {
    const rec = recorderRef.current;
    if (rec && rec.state !== "inactive") {
      try {
        rec.stop();
      } catch {
        /* ignore */
      }
    } else {
      // Nothing to stop — make sure we don't leave UI stuck.
      setIsRecording(false);
      releaseStream();
    }
  }, [releaseStream]);

  return { isRecording, isTranscribing, error, supported, start, stop };
}
