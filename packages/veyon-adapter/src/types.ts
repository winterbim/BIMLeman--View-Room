import type { Computer, ComputerState, FeatureAction } from "@bimleman/domain";

export interface ClassroomControlAdapter {
  readonly mode: "mock" | "veyon";
  stateOf(computer: Computer): ComputerState;
  probe(computer: Computer): Promise<ComputerState>;
  view(computer: Computer): Promise<void>;
  control(computer: Computer): Promise<void>;
  feature(computer: Computer, action: FeatureAction, payload?: string): Promise<void>;
  thumbnail(computer: Computer): Promise<string | null>;
}

export interface VeyonTransport {
  checkHost(host: string): Promise<boolean>;
  openView(host: string): Promise<void>;
  openControl(host: string): Promise<void>;
  thumbnail(host: string): Promise<string | null>;
  feature(host: string, action: FeatureAction, payload?: string): Promise<void>;
}

export const FEATURE_UID = {
  screenLock: "ccb535a2-1d24-4cc1-a709-8b47d2b2ac79",
  reboot: "4f7d98f0-395a-4fff-b968-e49b8d0f748c",
  powerDown: "6f5a27a0-0e2f-496e-afcc-7aae62eede10",
  openWebsite: "8a11a75d-b3db-48b6-b9cb-f8422ddd5b0c",
  textMessage: "e75ae9c8-ac17-4d00-8f0d-019348346208"
} as const;

export const AUTH_KEYS_METHOD = "0c69b301-81b4-42d6-8fae-128cdd113314";
