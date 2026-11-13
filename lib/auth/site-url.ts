import "server-only";
import { z } from "zod";

/** Trusted deployment origin: never derive email links from request headers. */
export function getAuthSiteUrl() {
  const value = z.url().safeParse(process.env.AUTH_SITE_URL);
  if (!value.success) throw new Error("Configure AUTH_SITE_URL for authentication email links.");
  const url = new URL(value.data);
  const local = ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
  if (url.username || url.password || url.search || url.hash || url.pathname !== "/" ||
      (url.protocol !== "https:" && !(local && url.protocol === "http:"))) {
    throw new Error("AUTH_SITE_URL must be a trusted HTTPS origin (HTTP is allowed for loopback development).");
  }
  return url.origin;
}
