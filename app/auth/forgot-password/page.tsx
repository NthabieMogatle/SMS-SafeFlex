import type { Metadata } from "next";
import ForgotPasswordForm from "./ForgotPasswordForm";

export const metadata: Metadata = {
  title: "Forgot password",
  description:
    "Reset your AI Mock Interview Coach password and get back into practice.",
};

export default function ForgotPasswordPage() {
  return <ForgotPasswordForm />;
}
