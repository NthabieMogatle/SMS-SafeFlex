import type { Metadata } from "next";
import SignupForm from "./SignupForm";

export const metadata: Metadata = {
  title: "Sign up",
  description:
    "Create your Career OS account and start practicing AI-coached mock interviews.",
};

export default function SignupPage() {
  return <SignupForm />;
}
