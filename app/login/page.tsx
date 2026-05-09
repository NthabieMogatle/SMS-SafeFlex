import type { Metadata } from "next";
import LoginForm from "./LoginForm";

export const metadata: Metadata = {
  title: "Log in",
  description: "Log in to Elevra to continue practicing mock interviews.",
};

export default function LoginPage() {
  return <LoginForm />;
}
