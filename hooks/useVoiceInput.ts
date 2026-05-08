"use client";

import { useEffect, useRef, useState } from "react";

interface SREvent {
  resultIndex: number;
  results: ArrayLike<{
    isFinal: boolean;
    0: { transcript: string };
  }>;
}

interface SRError {
  error: string;
}

interface SRInstance {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((event: SREvent) => void) | null;
  onerror: ((event: SRError) => void) | null;
  onend: (() => void) | null;
}

interface SRConstructor {
  new (): SRInstance;
}

declare global {
  interface Window {
    SpeechRecognition?: SRConstructor;
    webkitSpeechRecognition?: SRConstructor;
  }
}

export type VoiceInput = {
  isRecording: boolean;
  error: string | null;
  supported: boolean | null;
  start: () => void;
  stop: () => void;
};

export function useVoiceInput(
  onResult: (text: string, isFinal: boolean) => void,
): VoiceInput {
  const [isRecording, setIsRecording] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [supported, setSupported] = useState<boolean | null>(null);
  const recognitionRef = useRef<SRInstance | null>(null);
  const onResultRef = useRef(onResult);

  // Keep latest callback without re-triggering effects.
  useEffect(() => {
    onResultRef.current = onResult;
  }, [onResult]);

  useEffect(() => {
    const SR = window.SpeechRecognition ?? window.webkitSpeechRecognition;
    setSupported(Boolean(SR));
    return () => {
      try {
        recognitionRef.current?.abort();
      } catch {
        /* ignore */
      }
    };
  }, []);

  function start() {
    setError(null);
    const SRClass = window.SpeechRecognition ?? window.webkitSpeechRecognition;
    if (!SRClass) {
      setError(
        "Voice input isn't supported in this browser. Try Chrome or Safari.",
      );
      return;
    }
    try {
      const rec = new SRClass();
      rec.continuous = true;
      rec.interimResults = true;
      rec.lang = "en-US";

      rec.onresult = (event) => {
        for (let i = event.resultIndex; i < event.results.length; i++) {
          const result = event.results[i];
          const transcript = result[0].transcript;
          onResultRef.current(transcript, result.isFinal);
        }
      };

      rec.onerror = (event) => {
        if (
          event.error === "not-allowed" ||
          event.error === "service-not-allowed"
        ) {
          setError(
            "Microphone access was denied. Allow it in your browser settings and try again.",
          );
        } else if (event.error === "no-speech" || event.error === "aborted") {
          // Silent timeout or user-initiated stop — no message needed.
        } else if (event.error === "network") {
          setError("Voice input needs a network connection. Try again.");
        } else {
          setError(`Voice input error: ${event.error}`);
        }
        setIsRecording(false);
      };

      rec.onend = () => setIsRecording(false);

      recognitionRef.current = rec;
      rec.start();
      setIsRecording(true);
    } catch {
      setError("Couldn't start voice input. Try again.");
      setIsRecording(false);
    }
  }

  function stop() {
    try {
      recognitionRef.current?.stop();
    } catch {
      /* ignore */
    }
    setIsRecording(false);
  }

  return { isRecording, error, supported, start, stop };
}
