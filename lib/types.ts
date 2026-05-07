export type ExperienceLevel = "entry" | "mid" | "senior";

export interface InterviewSetup {
  role: string;
  industry: string;
  experienceLevel: ExperienceLevel;
}

export interface QAItem {
  question: string;
  answer: string;
}

export interface FeedbackItem {
  question: string;
  score: number;
  strengths: string[];
  weaknesses: string[];
  rewrite: string;
}

export interface FeedbackReport {
  items: FeedbackItem[];
}
