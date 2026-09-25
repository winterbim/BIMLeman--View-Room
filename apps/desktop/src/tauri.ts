import { invoke } from "@tauri-apps/api/core";
import type { FeatureAction } from "@bimleman/domain";
import type { VeyonTransport } from "@bimleman/veyon-adapter";

export interface PlatformInfo {
  os: string;
  veyonFound: boolean;
  mode: "mock" | "real";
}

export async function platformInfo(): Promise<PlatformInfo> {
  try {
    return await invoke<PlatformInfo>("platform_info");
  } catch {
    return { os: "browser", veyonFound: false, mode: "mock" };
  }
}

export const tauriTransport: VeyonTransport = {
  checkHost(host) {
    return invoke<boolean>("check_veyon_host", { host });
  },
  openView(host) {
    return invoke("open_remote_view", { host });
  },
  openControl(host) {
    return invoke("open_remote_control", { host });
  },
  thumbnail(host) {
    return invoke<string | null>("webapi_thumbnail", { host });
  },
  feature(host, action: FeatureAction, payload?: string) {
    return invoke("webapi_feature", { host, action, payload: payload ?? null });
  }
};

export async function appendAudit(event: {
  actor: string;
  action: string;
  result: "success" | "failure";
  computerId?: string;
  roomId?: string;
}): Promise<void> {
  try {
    await invoke("append_audit", { event });
  } catch {
    // Le journal écran reste affiché même si le fichier local n'est pas accessible.
  }
}
