import type { Metadata } from "next";
import LoginForm from "./LoginForm";

export const metadata: Metadata = {
  title: "Log in",
  description:
    "Log in to AI Mock Interview Coach to continue practicing mock interviews.",
};

export default function LoginPage({
  searchParams,
}: {
  searchParams: { reset?: string };
}) {
  return <LoginForm resetSuccess={searchParams.reset === "success"} />;
}
