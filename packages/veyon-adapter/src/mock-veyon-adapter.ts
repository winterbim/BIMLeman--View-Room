import { computers, ControlError, isManagedHostname, type Computer, type ComputerState, type FeatureAction } from "@bimleman/domain";
import type { ClassroomControlAdapter } from "./types";

export interface MockVeyonOptions {
  recoverPowerMs?: number | null;
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function svgThumbnail(computer: Computer, state: ComputerState): string {
  const label = state === "locked" ? "FIGÉ" : state === "controlled" ? "ASSISTANCE" : "SIMULATION";
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180">
    <rect width="320" height="180" fill="#071526"/>
    <rect x="16" y="16" width="288" height="148" rx="12" fill="#12324d" stroke="#38c9f0"/>
    <text x="160" y="78" text-anchor="middle" fill="#9be7ff" font-family="sans-serif" font-size="18">${computer.hostname}</text>
    <text x="160" y="108" text-anchor="middle" fill="#ffd27b" font-family="sans-serif" font-size="14">${label}</text>
  </svg>`;
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}

export class MockVeyonAdapter implements ClassroomControlAdapter {
  readonly mode = "mock" as const;
  private readonly down = new Set<string>();
  private readonly fault = new Set<string>();
  private readonly locked = new Set<string>();
  private readonly assisted = new Set<string>();
  private readonly recoverPowerMs: number | null;

  constructor(options: MockVeyonOptions = {}) {
    this.recoverPowerMs = options.recoverPowerMs === undefined ? null : options.recoverPowerMs;
    for (const computer of computers) {
      if (computer.seat === 8) this.down.add(computer.id);
      if (computer.hostname === "SALLE-B-PC07") this.fault.add(computer.id);
    }
  }

  stateOf(computer: Computer): ComputerState {
    if (this.down.has(computer.id)) return "offline";
    if (this.fault.has(computer.id)) return "error";
    if (this.locked.has(computer.id)) return "locked";
    if (this.assisted.has(computer.id)) return "controlled";
    return "online";
  }

  async probe(computer: Computer): Promise<ComputerState> {
    this.assertManaged(computer);
    await delay(5);
    return this.stateOf(computer);
  }

  async view(computer: Computer): Promise<void> {
    await this.assertReachable(computer);
  }

  async control(computer: Computer): Promise<void> {
    await this.assertReachable(computer);
    this.assisted.add(computer.id);
  }

  async feature(computer: Computer, action: FeatureAction, payload?: string): Promise<void> {
    await this.assertReachable(computer);
    if (action === "lock") {
      this.locked.add(computer.id);
      this.assisted.delete(computer.id);
      return;
    }
    if (action === "unlock") {
      this.locked.delete(computer.id);
      return;
    }
    if (action === "message") {
      if (!payload?.trim()) throw new ControlError("Le message est vide.", "invalid");
      return;
    }
    if (action === "openWebsite") {
      if (!payload?.startsWith("http://") && !payload?.startsWith("https://")) {
        throw new ControlError("Adresse web invalide.", "invalid");
      }
      return;
    }
    if (action === "reboot" || action === "shutdown") {
      this.powerDown(computer.id);
    }
  }

  async thumbnail(computer: Computer): Promise<string | null> {
    const state = this.stateOf(computer);
    if (state === "offline" || state === "error") return null;
    return svgThumbnail(computer, state);
  }

  private async assertReachable(computer: Computer): Promise<void> {
    this.assertManaged(computer);
    await delay(5);
    const state = this.stateOf(computer);
    if (state === "offline") {
      throw new ControlError(`${computer.hostname} est hors ligne.`, "unreachable");
    }
    if (state === "error") {
      throw new ControlError(`${computer.hostname} ne répond pas (erreur réseau).`, "unreachable");
    }
  }

  private assertManaged(computer: Computer): void {
    if (!isManagedHostname(computer.hostname)) {
      throw new ControlError(`${computer.hostname} n'appartient pas au parc.`, "denied");
    }
  }

  private powerDown(id: string): void {
    this.down.add(id);
    this.locked.delete(id);
    this.assisted.delete(id);
    if (this.recoverPowerMs && this.recoverPowerMs > 0) {
      const delayMs = this.recoverPowerMs;
      setTimeout(() => this.down.delete(id), delayMs);
    }
  }
}
