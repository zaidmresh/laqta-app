import { createClient, SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2.45.4";

/**
 * عميل بصلاحية service_role — بيتجاوز RLS بالكامل، تمامًا متل Admin SDK
 * بفايربيس. ما تستخدمه أبدًا بكود يشتغل على جهاز المستخدم — هون بس داخل
 * Edge Functions (سيرفر-سايد فقط). المفاتيح دي متوفرة تلقائيًا كـ env vars
 * بكل Edge Function بدون أي إعداد إضافي.
 */
export function createAdminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * يتحقق من هوية المستخدم صاحب الطلب من التوكن الموجود بهيدر Authorization
 * (بديل request.auth?.uid بـ onCall من فايربيس).
 */
export async function getAuthedUser(
  req: Request,
  admin: SupabaseClient,
): Promise<User | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return null;
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data.user) return null;
  return data.user;
}

/** يتحقق هل المستخدم أدمن (profiles.is_admin = true) — بديل token.admin */
export async function isAdmin(admin: SupabaseClient, uid: string): Promise<boolean> {
  const { data } = await admin.from("profiles").select("is_admin").eq("id", uid).maybeSingle();
  return data?.is_admin === true;
}
